console.log('Script started');
const { loadSecrets } = require('/home/ubuntu/electricity-grid/shared/database/secrets-manager');
console.log('loadSecrets imported');
loadSecrets().then(() => {
  console.log('Secrets loaded successfully');
  const { Consumer, MeterReading } = require('/home/ubuntu/electricity-grid/shared/database/models');
  console.log('Models imported');
  Consumer.findAll().then(consumers => {
    console.log('--- Consumers ---', consumers.length);
    consumers.forEach(c => console.log('ID:', c.id, 'Number:', c.consumer_number, 'Balance:', c.balance, 'Status:', c.connection_status));
    MeterReading.findAll({ limit: 10, order: [['id', 'DESC']] }).then(readings => {
      console.log('--- Readings ---', readings.length);
      readings.forEach(r => console.log('ID:', r.id, 'Meter:', r.meter_id, 'Units:', r.units_consumed, 'Date:', r.reading_date));
      process.exit(0);
    }).catch(e => { console.error('Readings error:', e); process.exit(1); });
  }).catch(e => { console.error('Consumers error:', e); process.exit(1); });
}).catch(e => { console.error('Secrets error:', e); process.exit(1); });
