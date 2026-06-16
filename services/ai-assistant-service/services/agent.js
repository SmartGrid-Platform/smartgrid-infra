const { ChatOpenAI } = require('@langchain/openai');
const { ChatBedrockConverse } = require('@langchain/aws');
const { createReactAgent } = require('@langchain/langgraph/prebuilt');
const { getAllTools } = require('./tools');
const { SystemMessage } = require('@langchain/core/messages');

const createAgent = async () => {
  const tools = getAllTools();
  
  let llm;
  const provider = process.env.LLM_PROVIDER || 'openai';

  if (provider === 'bedrock') {
    llm = new ChatBedrockConverse({
      model: 'anthropic.claude-3-haiku-20240307-v1:0', // or your preferred bedrock model
      region: process.env.AWS_REGION || 'us-east-1',
      // credentials will be picked up from AWS SDK standard environment variables
    });
  } else {
    // Default to OpenAI
    llm = new ChatOpenAI({
      modelName: 'gpt-4o-mini',
      temperature: 0,
      openAIApiKey: process.env.OPENAI_API_KEY
    });
  }

  const systemMessage = new SystemMessage(`
You are the SmartGrid AI Assistant, a helpful electricity bill and prepaid metering guide for consumers.
You can answer questions about their account, explain bills, suggest energy saving tips, and recommend recharge amounts.

Guidelines:
1. ALWAYS use the provided tools to fetch actual consumer data before answering.
2. NEVER guess or hallucinate account balances, usage numbers, or recharge histories.
3. If the user asks for a recharge recommendation, fetch their current balance, calculate their average daily consumption cost from historical bills, and suggest how much they need for the next 15/30 days.
4. Keep your responses concise, friendly, and formatted nicely.
5. If the user asks about a specific bill, fetch their bills, find the matching month, compare it to the previous month, and note any differences in consumption.
6. Provide specific, actionable energy-saving recommendations based on any unusual usage spikes found in their readings.
  `);

  const agent = createReactAgent({
    llm,
    tools,
    stateModifier: systemMessage
  });

  return agent;
};

module.exports = { createAgent };
