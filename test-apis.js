const jwt = require('jsonwebtoken');
const axios = require('axios');
const { loadSecrets } = require('./shared/database/secrets-manager');

const JWT_SECRET = 'smartgrid_secret'; // Default or from env

async function run() {
  await loadSecrets();
  
  const token = jwt.sign(
    {
      id: 4, // Lara
      name: 'lara',
      email: 'lara123@gmail.com',
      role: 'CONSUMER',
      consumerId: 2
    },
    process.env.JWT_SECRET || JWT_SECRET,
    { expiresIn: '1h' }
  );

  const headers = { Authorization: `Bearer ${token}` };
  
  console.log('--- Testing API Calls with generated token ---');
  console.log('Headers:', headers);

  try {
    const consumerRes = await axios.get('http://localhost:3002/api/consumers/me', { headers });
    console.log('GET /api/consumers/me Success:', consumerRes.data);
  } catch (err) {
    console.error('GET /api/consumers/me Error:', err.response?.status, err.response?.data || err.message);
  }

  try {
    const meterRes = await axios.get('http://localhost:3003/api/meters/consumer/2', { headers });
    console.log('GET /api/meters/consumer/2 Success:', meterRes.data);
  } catch (err) {
    console.error('GET /api/meters/consumer/2 Error:', err.response?.status, err.response?.data || err.message);
  }

  try {
    const readingsRes = await axios.get('http://localhost:3003/api/meters/1/readings', { headers });
    console.log('GET /api/meters/1/readings Success:', readingsRes.data);
  } catch (err) {
    console.error('GET /api/meters/1/readings Error:', err.response?.status, err.response?.data || err.message);
  }

  try {
    const billsRes = await axios.get('http://localhost:3004/api/bills/consumer/2', { headers });
    console.log('GET /api/bills/consumer/2 Success:', billsRes.data);
  } catch (err) {
    console.error('GET /api/bills/consumer/2 Error:', err.response?.status, err.response?.data || err.message);
  }
}

run().catch(console.error);
