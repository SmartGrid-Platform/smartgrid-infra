const { StateGraph, END } = require('@langchain/langgraph');
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

// Helper to define graph state
const agentState = {
  messages: {
    value: (x, y) => x.concat(y),
    default: () => [],
  },
  intent: {
    value: (x, y) => y,
    default: () => null,
  },
  context: {
    value: (x, y) => ({ ...x, ...y }),
    default: () => ({}),
  },
  consumerId: {
    value: (x, y) => y,
    default: () => null,
  },
  authHeader: {
    value: (x, y) => y,
    default: () => null,
  }
};

const detectIntent = async (state) => {
  const lastMessage = state.messages[state.messages.length - 1].content;
  
  const systemPrompt = `You are an intent classification engine for the SmartGrid AI Assistant.
The user message MUST be classified into one of the following exact string intents:
${INTENTS.join(', ')}

ONLY return the exact string of the intent. DO NOT return any other text or punctuation.

If the user asks about ANYTHING NOT RELATED to electricity usage, billing, balances, recharge, or energy insights (e.g. "Who is the Prime Minister?"), you MUST return "irrelevant".`;

  const intentResponse = await bedrockProvider.generateResponse(systemPrompt, lastMessage);
  const detectedIntent = intentResponse.trim().toLowerCase();
  
  // Validate intent
  const finalIntent = INTENTS.includes(detectedIntent) ? detectedIntent : 'irrelevant';
  
  return { intent: finalIntent };
};

const gatherContext = async (state) => {
  const { intent, consumerId, authHeader } = state;
  let gatheredContext = {};
  
  const config = { configurable: { consumerId, authHeader } };

  try {
    if (['check_balance', 'recharge_recommendation', 'explain_bill', 'usage_analysis'].includes(intent)) {
      gatheredContext.profile = JSON.parse(await getConsumerProfileTool.func("", null, config));
    }
    if (['bill_history', 'explain_bill', 'recharge_recommendation'].includes(intent)) {
      gatheredContext.bills = JSON.parse(await getConsumerBillsTool.func("", null, config));
    }
    if (['usage_analysis', 'energy_saving', 'explain_bill'].includes(intent)) {
      gatheredContext.usage = JSON.parse(await getConsumerMetersAndUsageTool.func("", null, config));
    }
    if (['tariff_question', 'recharge_recommendation'].includes(intent)) {
      gatheredContext.tariff = JSON.parse(await getActiveTariffTool.func("", null, config));
    }
    if (['recharge_recommendation'].includes(intent)) {
      gatheredContext.recharges = JSON.parse(await getConsumerRechargesTool.func("", null, config));
    }
  } catch (error) {
    console.error("Context gathering error:", error);
  }

  return { context: gatheredContext };
};

const assemblePromptAndRespond = async (state) => {
  const { intent, context, messages } = state;
  const lastMessage = messages[messages.length - 1].content;

  if (intent === 'irrelevant') {
    return {
      messages: [{ role: 'assistant', content: "I am the SmartGrid AI Assistant and can only help with electricity usage, billing, balances, and energy insights." }]
    };
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

  const responseText = await bedrockProvider.generateResponse(systemPrompt, lastMessage);

  return {
    messages: [{ role: 'assistant', content: responseText }]
  };
};

const buildWorkflow = () => {
  const workflow = new StateGraph({ channels: agentState });

  workflow.addNode('detectIntent', detectIntent);
  workflow.addNode('gatherContext', gatherContext);
  workflow.addNode('respond', assemblePromptAndRespond);

  workflow.addEdge('detectIntent', 'gatherContext');
  workflow.addEdge('gatherContext', 'respond');
  workflow.addEdge('respond', END);

  workflow.setEntryPoint('detectIntent');

  return workflow.compile();
};

const createAgent = () => {
  return buildWorkflow();
};

module.exports = { createAgent };
