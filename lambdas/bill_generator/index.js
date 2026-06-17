const PDFDocument = require('pdfkit');
const AWS = require('aws-sdk');
const { PassThrough } = require('stream');

const s3 = new AWS.S3({
  region: process.env.AWS_REGION || 'ap-south-1'
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME || process.env.BILLS_BUCKET_NAME || 'smartgrid-bills-storage';

exports.handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  
  const units = parseFloat(event.units || 0);
  const rate = parseFloat(event.rate || 0);
  const fixedCharge = parseFloat(event.fixedCharge || event.fixed_charge || 0);
  const amount = parseFloat((units * rate + fixedCharge).toFixed(2));
  
  const { 
    consumerNumber = 'Unknown', 
    billingMonth = 'Unknown',
    consumerName = 'Unknown',
    consumerEmail = 'Unknown',
    consumerPhone = 'Unknown',
    consumerAddress = 'Unknown',
    meterNumber = 'Unknown',
    tariffPlan = 'Unknown',
    previousReading = 0,
    currentReading = 0,
    tax = 0.00,
    paymentStatus = 'PAID'
  } = event;

  const fileName = `bill_${consumerNumber}_${billingMonth}.pdf`;
  
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 50, size: 'A4' });
      const pass = new PassThrough();
      
      const uploadParams = {
        Bucket: BUCKET_NAME,
        Key: fileName,
        Body: pass,
        ContentType: 'application/pdf'
      };
      
      const uploadPromise = s3.upload(uploadParams).promise();
      doc.pipe(pass);
      
      // Header Banner
      doc.rect(0, 0, 595, 100).fill('#0D253F');
      doc.fillColor('#FFFFFF');
      doc.fontSize(22).font('Helvetica-Bold').text('SMARTGRID', 50, 30);
      doc.fontSize(10).font('Helvetica').text('Utility Management Platform', 50, 60);
      doc.fontSize(10).text('Date Generated: ' + new Date().toLocaleDateString(), 400, 45, { align: 'right', width: 145 });
      
      // Invoice Details Separator
      doc.fillColor('#0D253F').fontSize(14).font('Helvetica-Bold').text('BILLING STATEMENT', 50, 125);
      doc.strokeColor('#26C6DA').lineWidth(1.5).moveTo(50, 143).lineTo(545, 143).stroke();
      
      // Consumer Details & Billing Summary (2 columns)
      doc.fillColor('#333333').fontSize(9).font('Helvetica');
      // Left Col: Consumer Details
      doc.font('Helvetica-Bold').text('Consumer Details:', 50, 160);
      doc.font('Helvetica').text(`Name: ${consumerName}`, 50, 180)
         .text(`Email: ${consumerEmail}`, 50, 195)
         .text(`Phone: ${consumerPhone}`, 50, 210)
         .text(`Address: ${consumerAddress}`, 50, 225, { width: 220 });

      // Right Col: Billing info
      doc.font('Helvetica-Bold').text('Billing Summary:', 320, 160);
      doc.font('Helvetica').text(`Consumer Number: ${consumerNumber}`, 320, 180)
         .text(`Meter Number: ${meterNumber}`, 320, 195)
         .text(`Tariff Plan: ${tariffPlan}`, 320, 210)
         .text(`Billing Month: ${billingMonth}`, 320, 225);

      // Usage Table Section
      doc.fillColor('#0D253F').fontSize(11).font('Helvetica-Bold').text('Usage Details', 50, 275);
      doc.strokeColor('#E0E0E0').lineWidth(1).moveTo(50, 290).lineTo(545, 290).stroke();
      
      // Table Header Row
      doc.fillColor('#555555').fontSize(8.5).font('Helvetica-Bold');
      doc.text('Previous Reading', 50, 298)
         .text('Current Reading', 150, 298)
         .text('Units Consumed', 250, 298)
         .text('Rate Per Unit', 350, 298)
         .text('Fixed Charge', 450, 298);
         
      doc.strokeColor('#E0E0E0').moveTo(50, 312).lineTo(545, 312).stroke();

      // Table Values Row
      doc.fillColor('#333333').fontSize(9.5).font('Helvetica');
      doc.text(`${parseFloat(previousReading).toFixed(2)} kWh`, 50, 322)
         .text(`${parseFloat(currentReading).toFixed(2)} kWh`, 150, 322)
         .text(`${units.toFixed(2)} kWh`, 250, 322)
         .text(`₹${rate.toFixed(2)}`, 350, 322)
         .text(`₹${fixedCharge.toFixed(2)}`, 450, 322);

      doc.strokeColor('#0D253F').lineWidth(1.5).moveTo(50, 345).lineTo(545, 345).stroke();
      
      // Totals Box
      doc.rect(320, 360, 225, 110).fill('#F5F5F5');
      doc.fillColor('#333333').fontSize(9.5).font('Helvetica');
      doc.text('Energy Charge:', 340, 375);
      doc.text(`₹${(units * rate).toFixed(2)}`, 450, 375, { align: 'right', width: 80 });
      
      doc.text('Fixed Charge:', 340, 395);
      doc.text(`₹${fixedCharge.toFixed(2)}`, 450, 395, { align: 'right', width: 80 });

      doc.text('Tax / GST:', 340, 415);
      doc.text(`₹${parseFloat(tax).toFixed(2)}`, 450, 415, { align: 'right', width: 80 });

      doc.strokeColor('#D7D7D7').lineWidth(1).moveTo(330, 435).lineTo(535, 435).stroke();
      
      doc.fillColor('#0D253F').fontSize(11).font('Helvetica-Bold');
      doc.text('Total Amount:', 340, 445);
      doc.text(`₹${amount.toFixed(2)}`, 450, 445, { align: 'right', width: 80 });

      // Payment Status Banner
      doc.rect(50, 375, 120, 32).fill('#E8F5E9');
      doc.fillColor('#2E7D32').fontSize(12).font('Helvetica-Bold').text('PAID', 93, 385);

      // Footer
      doc.strokeColor('#E0E0E0').lineWidth(1).moveTo(50, 750).lineTo(545, 750).stroke();
      doc.fillColor('#777777').fontSize(8).font('Helvetica');
      doc.text('Generated by SmartGrid Utility Management Platform', 50, 762, { align: 'center', width: 495 });
      
      doc.end();
      
      uploadPromise.then(data => {
        console.log(`Successfully uploaded to S3: ${data.Location}`);
        resolve({
          amount,
          s3_key: fileName
        });
      }).catch(err => {
        console.error('S3 Upload Error:', err);
        reject(err);
      });
      
    } catch (err) {
      console.error('PDF Generation Error:', err);
      reject(err);
    }
  });
};
