const express = require('express');
const { authenticate } = require('../middleware/auth');
const { createAgent } = require('../services/agent');
const bedrockProvider = require('../services/bedrockProvider');

const router = express.Router();

// Track sessions in memory for simple demonstration (in production use Redis/DB)
const userSessions = new Map();

router.post('/chat', authenticate, async (req, res) => {
  console.log('[CHAT] Received chat request');
  const { message, sessionId } = req.body;
  const consumerId = req.user?.id; 
  const authHeader = req.headers.authorization;
  
  if (!message) {
    console.warn('[CHAT] Missing message payload');
    return res.status(400).json({ error: 'Message is required' });
  }

  if (!consumerId) {
    console.error('[CHAT] Unauthorized access: missing user ID');
    return res.status(401).json({ error: 'Unauthorized' });
  }

  console.log(`[CHAT] Authenticated user: ${consumerId}`);

  const sId = sessionId || `session_${consumerId}_${Date.now()}`;
  
  if (!userSessions.has(sId)) {
    userSessions.set(sId, {
      configurable: { thread_id: sId },
      consumerId,
      authHeader
    });
  }
  
  const config = userSessions.get(sId);
  config.consumerId = consumerId;
  config.authHeader = authHeader; // pass down for internal API calls
  
  try {
    console.log(`[CHAT] Initializing LangGraph agent for session ${sId}`);
    const agent = await createAgent();
    
    console.log(`[CHAT] Invoking agent for user ${consumerId} with message: "${message}"`);
    const result = await agent.invoke({
      messages: [{ role: 'user', content: message }],
      consumerId: config.consumerId,
      authHeader: config.authHeader
    }, {
      configurable: {
        thread_id: sId
      }
    });

    const aiMessage = result.messages[result.messages.length - 1];
    console.log(`[CHAT] Agent response generated successfully`);
    
    return res.status(200).json({
      reply: aiMessage.content,
      sessionId: sId
    });
  } catch (error) {
    console.error('[CHAT] AI Chat Error:', error.stack || error);
    return res.status(500).json({ error: 'Failed to process chat message' });
  }
});

router.post('/explain-bill', authenticate, async (req, res) => {
  console.log('[EXPLAIN] Received explain-bill request');
  const { billId } = req.body;
  const consumerId = req.user?.id; 
  const authHeader = req.headers.authorization;

  if (!billId) {
    console.warn('[EXPLAIN] Missing billId');
    return res.status(400).json({ error: 'Bill ID is required' });
  }

  if (!consumerId) {
    console.error('[EXPLAIN] Unauthorized access');
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    console.log(`[EXPLAIN] Initializing agent to explain bill ${billId} for user ${consumerId}`);
    const agent = await createAgent();
    
    const message = `Please explain my bill with ID ${billId}. Give a breakdown, compare it to past usage, and provide energy-saving recommendations based on my historical usage patterns.`;
    
    const result = await agent.invoke({
      messages: [{ role: 'user', content: message }],
      consumerId,
      authHeader
    }, {
      configurable: {
        thread_id: `explain_${billId}_${Date.now()}`
      }
    });

    const aiMessage = result.messages[result.messages.length - 1];
    console.log('[EXPLAIN] Bill explanation generated successfully');
    
    return res.status(200).json({
      explanation: aiMessage.content
    });
  } catch (error) {
    console.error('[EXPLAIN] Explain Bill Error:', error.stack || error);
    return res.status(500).json({ error: 'Failed to generate bill explanation' });
  }
});

router.get('/health', async (req, res) => {
  let bedrockStatus = 'unknown';
  try {
    // A lightweight ping or check
    if (bedrockProvider.primaryModel) {
       bedrockStatus = 'healthy';
    }
  } catch (err) {
    bedrockStatus = 'unhealthy';
  }

  res.status(200).json({
    service: "healthy",
    bedrock: bedrockStatus,
    billingService: process.env.BILLING_SERVICE_URL ? "configured" : "missing",
    meterService: process.env.METER_SERVICE_URL ? "configured" : "missing",
    consumerService: process.env.CONSUMER_SERVICE_URL ? "configured" : "missing"
  });
});

router.get('/debug', authenticate, async (req, res) => {
  try {
    const agent = await createAgent();
    
    res.status(200).json({
      jwtValid: true,
      consumerFound: !!req.user,
      billingConnected: !!process.env.BILLING_SERVICE_URL,
      meterConnected: !!process.env.METER_SERVICE_URL,
      bedrockConnected: !!bedrockProvider.primaryModel,
      graphInitialized: !!agent,
      modelPrimary: bedrockProvider.primaryModel,
      modelFallback: bedrockProvider.fallbackModel
    });
  } catch (err) {
    res.status(500).json({
      error: err.message,
      stack: err.stack
    });
  }
});

module.exports = router;
