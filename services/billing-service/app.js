const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');
const swaggerUi = require('swagger-ui-express');
const swaggerDocument = require('./swagger');
const { sequelize, Consumer, User, Meter, MeterReading, Tariff, Recharge, Bill, Notification } = require('../../shared/database/models');
const { authenticate, authorize } = require('./middleware/auth');
const { Op } = require('sequelize');

const app = express();

app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));

// S3 helper for invoice management (with local fallback)
const { uploadBill, downloadBill } = require('../../shared/database/s3-helper');
const { invokeLambda } = require('../../shared/database/aws-helpers');

// Custom Rate Limiter
const rateLimitMap = new Map();
app.use((req, res, next) => {
  const ip = req.ip;
  const now = Date.now();
  if (!rateLimitMap.has(ip)) rateLimitMap.set(ip, []);
  const requests = rateLimitMap.get(ip).filter(t => now - t < 15 * 60 * 1000);
  requests.push(now);
  rateLimitMap.set(ip, requests);
  if (requests.length > 200) return res.status(429).json({ error: 'Too many requests' });
  next();
});

// Swagger Docs
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'billing-service', timestamp: new Date() });
});

// GET all tariffs
app.get('/api/tariffs', authenticate, async (req, res) => {
  try {
    const tariffs = await Tariff.findAll({ order: [['effective_date', 'DESC'], ['id', 'DESC']] });
    return res.status(200).json(tariffs);
  } catch (error) {
    console.error('Fetch Tariffs Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST create tariff (Admin only)
app.post('/api/tariffs', authenticate, authorize(['ADMIN']), async (req, res) => {
  const { tariff_name, tariff_type, rate_per_unit, fixed_charge, status, description, effective_date } = req.body;

  if (!tariff_name || rate_per_unit === undefined || !effective_date) {
    return res.status(400).json({ error: 'Tariff name, rate, and effective date are required' });
  }

  try {
    const tariff = await Tariff.create({
      tariff_name,
      tariff_type: tariff_type || 'Residential',
      rate_per_unit,
      fixed_charge: fixed_charge !== undefined ? fixed_charge : 0.00,
      status: status || 'ACTIVE',
      description,
      effective_date
    });
    return res.status(201).json({ message: 'Tariff created successfully', tariff });
  } catch (error) {
    console.error('Create Tariff Error:', error);
    return res.status(500).json({ error: `Internal server error: ${error.message}` });
  }
});

// PUT update tariff (Admin only)
app.put('/api/tariffs/:id', authenticate, authorize(['ADMIN']), async (req, res) => {
  const { id } = req.params;
  const { tariff_name, tariff_type, rate_per_unit, fixed_charge, status, description, effective_date } = req.body;

  try {
    const tariff = await Tariff.findByPk(id);
    if (!tariff) {
      return res.status(404).json({ error: 'Tariff plan not found' });
    }

    if (tariff_name !== undefined) tariff.tariff_name = tariff_name;
    if (tariff_type !== undefined) tariff.tariff_type = tariff_type;
    if (rate_per_unit !== undefined) tariff.rate_per_unit = rate_per_unit;
    if (fixed_charge !== undefined) tariff.fixed_charge = fixed_charge;
    if (status !== undefined) tariff.status = status;
    if (description !== undefined) tariff.description = description;
    if (effective_date !== undefined) tariff.effective_date = effective_date;

    await tariff.save();
    return res.status(200).json({ message: 'Tariff updated successfully', tariff });
  } catch (error) {
    console.error('Update Tariff Error:', error);
    return res.status(500).json({ error: `Internal server error: ${error.message}` });
  }
});

// DELETE tariff (Admin only)
app.delete('/api/tariffs/:id', authenticate, authorize(['ADMIN']), async (req, res) => {
  const { id } = req.params;
  try {
    const tariff = await Tariff.findByPk(id);
    if (!tariff) {
      return res.status(404).json({ error: 'Tariff plan not found' });
    }

    // Set associated meters to null tariff to prevent DB constraint errors
    await Meter.update({ tariff_id: null }, { where: { tariff_id: id } });

    await tariff.destroy();
    return res.status(200).json({ message: 'Tariff plan deleted successfully' });
  } catch (error) {
    console.error('Delete Tariff Error:', error);
    return res.status(500).json({ error: `Internal server error: ${error.message}` });
  }
});

// GET all recharges (Staff/Supervisor/Admin only)
app.get('/api/recharges', authenticate, authorize(['STAFF', 'SUPERVISOR', 'ADMIN']), async (req, res) => {
  try {
    const recharges = await Recharge.findAll({
      include: [{ model: Consumer, as: 'consumer', include: [{ model: User, as: 'user', attributes: ['name', 'email'] }] }],
      order: [['created_at', 'DESC']]
    });
    return res.status(200).json(recharges);
  } catch (error) {
    console.error('Fetch Recharges Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// GET recharges for specific consumer (Staff/Supervisor/Admin or self)
app.get('/api/recharges/consumer/:consumerId', authenticate, async (req, res) => {
  const { consumerId } = req.params;
  try {
    const consumer = await Consumer.findByPk(consumerId);
    if (!consumer) return res.status(404).json({ error: 'Consumer not found' });

    if (req.user.role === 'CONSUMER' && consumer.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Unauthorized to access these records' });
    }

    const recharges = await Recharge.findAll({
      where: { consumer_id: consumerId },
      order: [['created_at', 'DESC']]
    });
    return res.status(200).json(recharges);
  } catch (error) {
    console.error('Fetch Consumer Recharges Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST process recharge (Consumer themselves or Staff/Admin)
app.post('/api/recharges', authenticate, async (req, res) => {
  const { consumer_id, amount } = req.body;

  if (amount === undefined || parseFloat(amount) <= 0) {
    return res.status(400).json({ error: 'Recharge amount must be a positive number' });
  }

  const transaction = await sequelize.transaction();
  try {
    const consumer = await Consumer.findByPk(consumer_id, { transaction });
    if (!consumer) {
      await transaction.rollback();
      return res.status(404).json({ error: 'Consumer not found' });
    }

    // Auth verification: Consumers can only recharge their own account
    if (req.user.role === 'CONSUMER' && consumer.user_id !== req.user.id) {
      await transaction.rollback();
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const currentBalance = parseFloat(consumer.balance);
    const newBalance = currentBalance + parseFloat(amount);
    
    // Save previous status to check if service reconnected
    const oldStatus = consumer.connection_status;

    consumer.balance = newBalance;
    
    // Automatic reconnection if balance restored above ₹0
    if (newBalance > 0 && oldStatus === 'DISCONNECTED') {
      consumer.connection_status = 'CONNECTED';
    }

    await consumer.save({ transaction });

    // Store Recharge history record
    const recharge = await Recharge.create({
      consumer_id,
      amount,
      balance_added: amount
    }, { transaction });

    // Create Notification alert
    await Notification.create({
      user_id: consumer.user_id,
      title: 'Recharge Successful',
      message: `Your account has been recharged with ₹${parseFloat(amount).toFixed(2)}. Current Balance: ₹${newBalance.toFixed(2)}. Status: ${consumer.connection_status}.`,
      type: 'RECHARGE'
    }, { transaction });

    await transaction.commit();
    return res.status(201).json({
      message: `Recharge of ₹${parseFloat(amount).toFixed(2)} completed successfully.`,
      recharge,
      newBalance,
      connectionStatus: consumer.connection_status
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Recharge Processing Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// GET all bills (Staff/Supervisor/Admin only)
app.get('/api/bills', authenticate, authorize(['STAFF', 'SUPERVISOR', 'ADMIN']), async (req, res) => {
  try {
    const bills = await Bill.findAll({
      include: [{ model: Consumer, as: 'consumer', include: [{ model: User, as: 'user', attributes: ['name', 'email'] }] }],
      order: [['created_at', 'DESC']]
    });
    return res.status(200).json(bills);
  } catch (error) {
    console.error('Fetch Bills Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// GET billing history for specific consumer
app.get('/api/bills/consumer/:consumerId', authenticate, async (req, res) => {
  const { consumerId } = req.params;
  try {
    const consumer = await Consumer.findByPk(consumerId);
    if (!consumer) return res.status(404).json({ error: 'Consumer not found' });

    if (req.user.role === 'CONSUMER' && consumer.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const bills = await Bill.findAll({
      where: { consumer_id: consumerId },
      order: [['created_at', 'DESC']]
    });
    return res.status(200).json(bills);
  } catch (error) {
    console.error('Fetch Consumer Bills Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST generate monthly bill for consumer (Staff/Admin only)
app.post('/api/bills/generate', authenticate, authorize(['STAFF', 'SUPERVISOR', 'ADMIN']), async (req, res) => {
  const { consumerId, billingMonth } = req.body; // billingMonth in YYYY-MM format

  if (!consumerId || !billingMonth || !/^\d{4}-\d{2}$/.test(billingMonth)) {
    return res.status(400).json({ error: 'Consumer ID and billing month (YYYY-MM) are required' });
  }

  const transaction = await sequelize.transaction();
  try {
    const consumer = await Consumer.findByPk(consumerId, {
      include: [{ model: User, as: 'user' }],
      transaction
    });

    if (!consumer) {
      await transaction.rollback();
      return res.status(404).json({ error: 'Consumer not found' });
    }

    // Check if bill already generated for this month
    const existing = await Bill.findOne({
      where: { consumer_id: consumerId, billing_month: billingMonth },
      transaction
    });
    if (existing) {
      await transaction.rollback();
      return res.status(400).json({ error: `Bill has already been generated for consumer in ${billingMonth}` });
    }

    // 1. Gather all consumer meters
    const meters = await Meter.findAll({
      where: { consumer_id: consumerId },
      transaction
    });

    if (meters.length === 0) {
      await transaction.rollback();
      return res.status(400).json({ error: 'Consumer does not have any meters assigned' });
    }

    // 2. Fetch all readings for these meters during that billingMonth
    const meterIds = meters.map(m => m.id);
    const year = parseInt(billingMonth.substring(0, 4), 10);
    const month = parseInt(billingMonth.substring(5, 7), 10);
    const startDate = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0, 0));
    const endDate = new Date(Date.UTC(year, month, 1, 0, 0, 0, 0));

    const readings = await MeterReading.findAll({
      where: {
        meter_id: { [Op.in]: meterIds },
        reading_date: {
          [Op.gte]: startDate,
          [Op.lt]: endDate
        }
      },
      transaction
    });

    const totalUnits = readings.reduce((sum, r) => sum + parseFloat(r.units_consumed), 0);

    // 3. Find active tariff for the consumer's meter
    let tariff = null;
    const meterWithTariff = meters.find(m => m.tariff_id);
    if (meterWithTariff) {
      tariff = await Tariff.findByPk(meterWithTariff.tariff_id, { transaction });
    }

    if (!tariff) {
      // Fallback to active global tariff
      tariff = await Tariff.findOne({
        where: { status: 'ACTIVE' },
        order: [['effective_date', 'DESC'], ['id', 'DESC']],
        transaction
      });
    }

    if (!tariff) {
      await transaction.rollback();
      return res.status(400).json({ error: 'No active tariff plan is assigned to this consumer or configured globally.' });
    }
    
    const tariffResult = await invokeLambda(
      process.env.LAMBDA_TARIFF_ENGINE,
      { tariff_name: tariff.tariff_name },
      (payload) => ({ rate_per_unit: parseFloat(tariff.rate_per_unit), fixed_charge: parseFloat(tariff.fixed_charge || 0) })
    );
    const rate = tariffResult.rate_per_unit !== undefined ? tariffResult.rate_per_unit : parseFloat(tariff.rate_per_unit);
    const fixedCharge = tariffResult.fixed_charge !== undefined ? tariffResult.fixed_charge : parseFloat(tariff.fixed_charge || 0);

    // 4. Calculate total bill amount & generate PDF via bill_generator Lambda
    const lambdaPayload = {
      units: totalUnits,
      rate,
      fixedCharge,
      consumerNumber: consumer.consumer_number,
      billingMonth,
      consumerName: consumer.user.name,
      consumerEmail: consumer.user.email,
      consumerPhone: consumer.phone,
      consumerAddress: consumer.address
    };

    const billResult = await invokeLambda(
      process.env.LAMBDA_BILL_GENERATOR,
      lambdaPayload,
      (payload) => ({ 
        amount: parseFloat(payload.units) * parseFloat(payload.rate) + parseFloat(payload.fixedCharge || 0), 
        s3_key: `fallback_bill_${Date.now()}.pdf` 
      })
    );
    
    const amount = billResult.amount;
    const fileName = billResult.s3_key || `bill_${consumer.consumer_number}_${billingMonth}.pdf`;

    // 5. Save Bill record in DB
    const bill = await Bill.create({
      consumer_id: consumerId,
      billing_month: billingMonth,
      units_used: totalUnits,
      amount,
      total_amount: amount,
      status: 'PAID', // It is prepaid, so it is registered as paid by default
      pdf_path: fileName,
      s3_key: fileName,
      generated_at: new Date()
    }, { transaction });

    // 6. Create notification alert for consumer user
    await Notification.create({
      user_id: consumer.user_id,
      title: 'New Monthly Bill Available',
      message: `Your monthly statement for ${billingMonth} is generated. Units used: ${totalUnits.toFixed(2)} kWh. Total statement cost: ₹${amount.toFixed(2)}. Receipt is ready for download.`,
      type: 'BILL'
    }, { transaction });

    await transaction.commit();
    return res.status(201).json({
      message: 'Monthly bill generated and receipt stored.',
      bill
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Bill Generation Error:', error);
    return res.status(500).json({ error: `Internal server error during bill generation: ${error.message}` });
  }
});

// GET download bill pre-signed URL
app.get('/api/bills/:id/download', authenticate, async (req, res) => {
  const { id } = req.params;
  try {
    const bill = await Bill.findByPk(id, { include: [{ model: Consumer, as: 'consumer' }] });
    if (!bill) {
      return res.status(404).json({ error: 'Bill statement not found' });
    }

    // Auth verification: consumers can only download their own bills
    if (req.user.role === 'CONSUMER' && bill.consumer.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Unauthorized to download this statement' });
    }

    try {
      const { getSignedDownloadUrl } = require('../../shared/database/s3-helper');
      const downloadUrl = await getSignedDownloadUrl(bill.pdf_path);
      return res.status(200).json({ downloadUrl });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Failed to generate download URL' });
    }
  } catch (error) {
    console.error('Download Bill Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// GET local download fallback
app.get('/api/bills/local-download/:fileName', async (req, res) => {
  try {
    const { fileName } = req.params;
    const { downloadBill } = require('../../shared/database/s3-helper');
    // For local fallback we can stream it directly. Since this is just for dev, we can bypass strict auth here, 
    // or ideally the URL should have a short-lived token. For this demo, we'll stream it.
    await downloadBill(fileName, res);
  } catch (err) {
    console.error('Local download error:', err);
    return res.status(404).json({ error: 'File not found' });
  }
});

// GET specific bill details
app.get('/api/bills/:id', authenticate, async (req, res) => {
  const { id } = req.params;
  try {
    const bill = await Bill.findByPk(id, { include: [{ model: Consumer, as: 'consumer' }] });
    if (!bill) {
      return res.status(404).json({ error: 'Bill not found' });
    }
    
    if (req.user.role === 'CONSUMER' && bill.consumer.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Unauthorized to view this bill' });
    }
    
    return res.status(200).json(bill);
  } catch (error) {
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// NEW ENDPOINTS AS REQUESTED:
// GET /api/consumer/bills (Returns bill history for logged in consumer)
app.get('/api/consumer/bills', authenticate, async (req, res) => {
  try {
    if (req.user.role !== 'CONSUMER') {
      return res.status(403).json({ error: 'Only consumers can access this endpoint' });
    }
    const consumer = await Consumer.findOne({ where: { user_id: req.user.id } });
    if (!consumer) return res.status(404).json({ error: 'Consumer profile not found' });

    const bills = await Bill.findAll({
      where: { consumer_id: consumer.id },
      order: [['billing_month', 'DESC']]
    });
    return res.status(200).json(bills);
  } catch (error) {
    console.error('Fetch Consumer Bills Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/consumer/bills/:id (Returns bill details for logged in consumer)
app.get('/api/consumer/bills/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    if (req.user.role !== 'CONSUMER') {
      return res.status(403).json({ error: 'Only consumers can access this endpoint' });
    }
    const consumer = await Consumer.findOne({ where: { user_id: req.user.id } });
    if (!consumer) return res.status(404).json({ error: 'Consumer profile not found' });

    const bill = await Bill.findOne({
      where: { id, consumer_id: consumer.id },
      include: [{ model: Consumer, as: 'consumer' }]
    });
    if (!bill) return res.status(404).json({ error: 'Bill not found' });

    return res.status(200).json(bill);
  } catch (error) {
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/consumer/bills/:id/download (Generates secure pre-signed S3 URL)
app.get('/api/consumer/bills/:id/download', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    if (req.user.role !== 'CONSUMER') {
      return res.status(403).json({ error: 'Only consumers can access this endpoint' });
    }
    const consumer = await Consumer.findOne({ where: { user_id: req.user.id } });
    if (!consumer) return res.status(404).json({ error: 'Consumer profile not found' });

    const bill = await Bill.findOne({
      where: { id, consumer_id: consumer.id }
    });
    if (!bill) return res.status(404).json({ error: 'Bill not found' });

    // Generate Pre-Signed URL using the S3 helper
    const { getSignedDownloadUrl } = require('../../shared/database/s3-helper');
    // Using s3_key if available, fallback to pdf_path
    const fileKey = bill.s3_key || bill.pdf_path;
    if (!fileKey) return res.status(404).json({ error: 'Bill PDF not found in records' });

    const downloadUrl = await getSignedDownloadUrl(fileKey);
    return res.status(200).json({ downloadUrl });
  } catch (error) {
    console.error('Download Bill Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE bill (Staff/Supervisor/Admin only)
app.delete('/api/bills/:id', authenticate, authorize(['STAFF', 'SUPERVISOR', 'ADMIN']), async (req, res) => {
  const { id } = req.params;
  try {
    const bill = await Bill.findByPk(id);
    if (!bill) {
      return res.status(404).json({ error: 'Bill not found' });
    }

    // Delete file from S3 / local fallback
    if (bill.pdf_path) {
      const { deleteBill } = require('../../shared/database/s3-helper');
      await deleteBill(bill.pdf_path);
    }

    await bill.destroy();
    return res.status(200).json({ message: 'Bill deleted successfully' });
  } catch (error) {
    console.error('Delete Bill Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Route Error:', err);
  res.status(500).json({ error: 'An unexpected error occurred' });
});

module.exports = app;
