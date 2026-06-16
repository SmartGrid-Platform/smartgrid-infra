const bedrockProvider = require('./bedrockProvider');
const {
  getConsumerProfileTool,
  getConsumerBillsTool,
  getConsumerRechargesTool,
  getConsumerMetersAndUsageTool,
  getActiveTariffTool
} = require('./tools');

const INTENTS = [
  'explain_bill',
  'check_balance',
  'recharge_recommendation',
  'usage_analysis',
  'energy_saving',
  'bill_history',
  'tariff_question',
  'irrelevant'
];

const detectIntent = async (message) => {
  const systemPrompt = `You are an intent classification engine for the SmartGrid AI Assistant.
The user message MUST be classified into one of the following exact string intents:
${INTENTS.join(', ')}

ONLY return the exact string of the intent. DO NOT return any other text or punctuation.

If the user asks about ANYTHING NOT RELATED to electricity usage, billing, balances, recharge, or energy insights (e.g. "Who is the Prime Minister?"), you MUST return "irrelevant".`;

  const intentResponse = await bedrockProvider.generateResponse(systemPrompt, message);
  const detectedIntent = intentResponse.trim().toLowerCase();
  return INTENTS.includes(detectedIntent) ? detectedIntent : 'irrelevant';
};

const gatherContext = async (intent, consumerId, authHeader) => {
  const config = { configurable: { consumerId, authHeader } };
  const gatheredContext = {};

  try {
    if (['check_balance', 'recharge_recommendation', 'explain_bill', 'usage_analysis'].includes(intent)) {
      gatheredContext.profile = JSON.parse(await getConsumerProfileTool.func('', null, config));
    }
    if (['bill_history', 'explain_bill', 'recharge_recommendation'].includes(intent)) {
      gatheredContext.bills = JSON.parse(await getConsumerBillsTool.func('', null, config));
    }
    if (['usage_analysis', 'energy_saving', 'explain_bill'].includes(intent)) {
      gatheredContext.usage = JSON.parse(await getConsumerMetersAndUsageTool.func('', null, config));
    }
    if (['tariff_question', 'recharge_recommendation'].includes(intent)) {
      gatheredContext.tariff = JSON.parse(await getActiveTariffTool.func('', null, config));
    }
    if (['recharge_recommendation'].includes(intent)) {
      gatheredContext.recharges = JSON.parse(await getConsumerRechargesTool.func('', null, config));
    }
  } catch (error) {
    console.error('[AGENT] Context gathering error:', error.message);
  }

  return gatheredContext;
};

const generateReply = async (intent, context, userMessage) => {
  if (intent === 'irrelevant') {
    return 'I am the SmartGrid AI Assistant and can only help with electricity usage, billing, balances, and energy insights.';
  }

  let systemPrompt = `You are the SmartGrid AI Assistant. Use the provided JSON Context to answer the user's question.
Keep your response concise, professional, and friendly. Do not hallucinate data that is not in the context.

Context:
${JSON.stringify(context, null, 2)}

`;

  if (intent === 'recharge_recommendation') {
    systemPrompt += `\nCalculate their average daily consumption cost from historical bills, and suggest how much they need for the next 15/30 days. Formula: (Last 30 Day Cost / 30). Estimated Remaining Days = Current Balance / Average Daily Cost.`;
  }
  if (intent === 'energy_saving') {
    systemPrompt += `\nIdentify highest consumption hours/days from the usage data. Suggest actionable recommendations (e.g., Reduce AC usage). Include Estimated Savings based on their tariff rate.`;
  }

  return await bedrockProvider.generateResponse(systemPrompt, userMessage);
};

const runAgent = async (message, consumerId, authHeader) => {
  console.log(`[AGENT] Detecting intent for: "${message}"`);
  const intent = await detectIntent(message);
  console.log(`[AGENT] Detected intent: ${intent}`);

  const context = await gatherContext(intent, consumerId, authHeader);
  console.log(`[AGENT] Context gathered for intent: ${intent}`);

  const reply = await generateReply(intent, context, message);
  console.log(`[AGENT] Reply generated`);

  return reply;
};

// Kept for backward compatibility
const createAgent = () => {
  return {
    invoke: async ({ messages, consumerId, authHeader }) => {
      const lastMessage = messages[messages.length - 1].content;
      const reply = await runAgent(lastMessage, consumerId, authHeader);
      return { messages: [...messages, { role: 'assistant', content: reply }] };
    }
  };
};

module.exports = { createAgent, runAgent };
