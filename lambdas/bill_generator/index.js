const PDFDocument = require('pdfkit');
const AWS = require('aws-sdk');
const { PassThrough } = require('stream');

const s3 = new AWS.S3({
  // Use standard environment variables for aws-sdk
  region: process.env.AWS_REGION || 'us-east-1'
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME || process.env.BILLS_BUCKET_NAME || 'smartgrid-bills-storage';

exports.handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  
  const units = parseFloat(event.units || 0);
  const rate = parseFloat(event.rate || 0);
  const amount = parseFloat((units * rate).toFixed(2));
  
  const { 
    consumerNumber = 'Unknown', 
    billingMonth = 'Unknown',
    consumerName = 'Unknown',
    consumerEmail = 'Unknown',
    consumerPhone = 'Unknown',
    consumerAddress = 'Unknown'
  } = event;

  const fileName = `bill_${consumerNumber}_${billingMonth}.pdf`;
  
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 50 });
      
      const pass = new PassThrough();
      
      const uploadParams = {
        Bucket: BUCKET_NAME,
        Key: fileName,
        Body: pass,
        ContentType: 'application/pdf'
      };
      
      // Setup S3 Upload
      const uploadPromise = s3.upload(uploadParams).promise();
      
      doc.pipe(pass);
      
      // Generate PDF content
      doc.fontSize(20).text('SmartGrid Utility Bill', { align: 'center' });
      doc.moveDown();
      
      doc.fontSize(12)
        .text(`Consumer Number: ${consumerNumber}`)
        .text(`Billing Month: ${billingMonth}`)
        .text(`Name: ${consumerName}`)
        .text(`Email: ${consumerEmail}`)
        .text(`Phone: ${consumerPhone}`)
        .text(`Address: ${consumerAddress}`);
      
      doc.moveDown(2);
      
      doc.fontSize(16).text('Consumption Summary', { underline: true });
      doc.moveDown();
      
      doc.fontSize(12)
        .text(`Units Used: ${units.toFixed(2)} kWh`)
        .text(`Rate: ₹${rate.toFixed(2)} / kWh`)
        .moveDown()
        .fontSize(14)
        .text(`Grand Total: ₹${amount.toFixed(2)}`, { stroke: true });
        
      doc.moveDown(3);
      doc.fontSize(10).fillColor('gray').text(`Generated on: ${new Date().toLocaleString()}`, { align: 'center' });
      
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
