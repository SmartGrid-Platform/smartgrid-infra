console.log('Script started');
const { loadSecrets } = require('/home/ubuntu/electricity-grid/shared/database/secrets-manager');
console.log('loadSecrets imported');
loadSecrets().then(() => {
  console.log('Secrets loaded successfully');
  const { User, Consumer, Meter, MeterReading } = require('/home/ubuntu/electricity-grid/shared/database/models');
  console.log('Models imported');
  User.findAll({ include: [{ model: Consumer, as: 'consumer' }] }).then(users => {
    console.log('--- Users ---', users.length);
    users.forEach(u => console.log('User ID:', u.id, 'Name:', u.name, 'Email:', u.email, 'Role:', u.role, 'Consumer ID:', u.consumer ? u.consumer.id : 'None', 'Consumer Number:', u.consumer ? u.consumer.consumer_number : 'None'));
    Consumer.findAll().then(consumers => {
      console.log('--- Consumers ---', consumers.length);
      consumers.forEach(c => console.log('Consumer ID:', c.id, 'User ID:', c.user_id, 'Number:', c.consumer_number, 'Balance:', c.balance, 'Status:', c.connection_status));
      Meter.findAll().then(meters => {
        console.log('--- Meters ---', meters.length);
        meters.forEach(m => console.log('Meter ID:', m.id, 'Number:', m.meter_number, 'Consumer ID:', m.consumer_id, 'Tariff ID:', m.tariff_id));
        process.exit(0);
      }).catch(e => { console.error('Meters error:', e); process.exit(1); });
    }).catch(e => { console.error('Consumers error:', e); process.exit(1); });
  }).catch(e => { console.error('Users error:', e); process.exit(1); });
}).catch(e => { console.error('Secrets error:', e); process.exit(1); });
