const jwt = require('./services/ai-assistant-service/node_modules/jsonwebtoken');
const axios = require('./services/ai-assistant-service/node_modules/axios');
const { loadSecrets } = require('./shared/database/secrets-manager');

const JWT_SECRET = 'smartgrid_secret';

const queries = [
  "What user am I logged in as?",
  "What is my electricity consumption?",
  "What is my current bill?",
  "What tariff am I using?",
  "What is my latest meter reading?",
  "Show my billing history.",
  "What is the electricity tariff in Andhra Pradesh?",
  "What is net metering?",
  "How can I reduce my electricity bill?"
];

async function run() {
  await loadSecrets();
  
  const token = jwt.sign(
    {
      id: 4, // Lara
      name: 'lara',
      email: 'lara123@gmail.com',
      role: 'CONSUMER',
      consumerId: 2,
      consumerNumber: 'CON-94594987'
    },
    process.env.JWT_SECRET || JWT_SECRET,
    { expiresIn: '1h' }
  );

  const headers = { 
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json'
  };
  
  console.log('--- STARTING E2E CONVERSATIONAL CHATBOT VERIFICATION ---');
  
  for (const query of queries) {
    console.log(`\n========================================\nUser Query: "${query}"\n========================================`);
    try {
      const res = await axios.post('http://localhost:4004/api/assistant/chat', {
        message: query,
        sessionId: 'test_session_e2e'
      }, { headers, timeout: 20000 });
      console.log(`Assistant Response:\n${res.data.reply}`);
    } catch (err) {
      console.error(`Error processing query "${query}":`, err.response?.status, err.response?.data || err.message);
    }
  }
}

run().catch(console.error);
