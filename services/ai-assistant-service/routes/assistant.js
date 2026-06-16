const express = require('express');
const { authenticate } = require('../middleware/auth');
const { createAgent } = require('../services/agent');

const router = express.Router();

// Track sessions in memory for simple demonstration (in production use Redis/DB)
const userSessions = new Map();

router.post('/chat', authenticate, async (req, res) => {
  const { message, sessionId } = req.body;
  const consumerId = req.user.id; // Or fetch Consumer ID using User ID
  const authHeader = req.headers.authorization;
  
  if (!message) {
    return res.status(400).json({ error: 'Message is required' });
  }

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
    const agent = await createAgent();
    
    // We pass consumerId and authHeader via state/config if needed, but easier through configurable
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
    
    return res.status(200).json({
      reply: aiMessage.content,
      sessionId: sId
    });
  } catch (error) {
    console.error('AI Chat Error:', error);
    return res.status(500).json({ error: 'Failed to process chat message' });
  }
});

router.post('/explain-bill', authenticate, async (req, res) => {
  const { billId } = req.body;
  const consumerId = req.user.id; 
  const authHeader = req.headers.authorization;

  if (!billId) {
    return res.status(400).json({ error: 'Bill ID is required' });
  }

  try {
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
    
    return res.status(200).json({
      explanation: aiMessage.content
    });
  } catch (error) {
    console.error('Explain Bill Error:', error);
    return res.status(500).json({ error: 'Failed to generate bill explanation' });
  }
});

module.exports = router;
