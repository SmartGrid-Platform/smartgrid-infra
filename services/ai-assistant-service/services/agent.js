const bedrockProvider = require('./bedrockProvider');
const { toolsList, executeTool } = require('./tools');
const { ConverseCommand } = require('@aws-sdk/client-bedrock-runtime');

const SYSTEM_PROMPT = `You are SmartGrid AI Assistant, an enterprise-grade utility intelligence assistant.

You help consumers, staff, and administrators understand electricity usage, billing, tariffs, smart meters, utility operations, energy efficiency, renewable energy, and power systems.

When answering, strictly adhere to the following rules:
1. Use SmartGrid database information first (by calling the appropriate tools).
2. Use real-time SmartGrid data whenever available.
3. Never hallucinate bills, readings, payments, tariffs, or customer information. If a tool returns no data or fails, explain that clearly.
4. Clearly distinguish between SmartGrid data and web-sourced information.
5. Use web search (via the "web_search" tool) for general electricity, utility, tariff, energy, and regulatory questions when platform-specific data is insufficient or absent.
6. Support detailed analytical conversations and follow-up questions using the conversation context history.
7. CRITICAL CURRENCY RULES:
   - All monetary values, costs, charges, and balances MUST be displayed in Indian Rupees (₹).
   - NEVER use US Dollars ($) or the USD symbol.
   - The currency code is INR.
   - Format numbers appropriately (e.g. ₹15,000 instead of $15,000).
8. Explain technical concepts in simple language.
9. Provide actionable energy recommendations and billing insights whenever useful.
10. Always be transparent about data availability and confidence.
11. Support detailed analytical conversations, not just predefined prompts.
12. Answer both platform-specific questions and general electricity-domain questions.
13. Be capable of discussing smart grids, meters, tariffs, billing, solar energy, EV charging, energy efficiency, power systems, regulations, and utility best practices.
14. Never fabricate information. If data is unavailable: "I do not currently have access to that SmartGrid data." must be returned.
15. If uncertain, state uncertainty and explain why.

You behave like a combination of:
* Utility Billing Expert
* Energy Consultant
* Smart Meter Analyst
* Customer Support Agent
* Electricity Domain Expert
* Utility Operations Assistant

while remaining grounded in actual SmartGrid data whenever available.`;

const runConverseAgent = async (messages, consumerId, authHeader) => {
  const client = bedrockProvider.client;
  const modelId = bedrockProvider.primaryModel;
  const config = { consumerId, authHeader };

  // 1. Format messages array for Bedrock Converse command
  const formattedMessages = messages.map(msg => {
    // If msg.content is an array (representing tool results or complex structure), pass it as is
    const content = typeof msg.content === 'string' 
      ? [{ text: msg.content }] 
      : msg.content;
    
    return {
      role: msg.role === 'assistant' ? 'assistant' : 'user',
      content
    };
  });

  console.log(`[AGENT] Starting Bedrock Converse loop for user ${consumerId}. Message count: ${formattedMessages.length}`);

  // 2. Loop to handle model execution and tool calls (limit to 5 rounds)
  for (let round = 0; round < 5; round++) {
    const command = new ConverseCommand({
      modelId,
      messages: formattedMessages,
      system: [{ text: SYSTEM_PROMPT }],
      toolConfig: { tools: toolsList },
      inferenceConfig: {
        maxTokens: 2000,
        temperature: 0.1
      }
    });

    console.log(`[AGENT] Invoking model ${modelId} (Round ${round + 1})...`);
    const response = await client.send(command);
    const outputMessage = response.output.message;
    
    // Save model output to the conversation history of this Converse session
    formattedMessages.push({
      role: outputMessage.role,
      content: outputMessage.content
    });

    // Check if the model wants to call tools
    const toolRequests = outputMessage.content.filter(part => part.toolUse);
    if (toolRequests.length === 0) {
      // No tool calls requested, we can return the text output
      const textPart = outputMessage.content.find(part => part.text);
      console.log('[AGENT] Converse loop complete. Text response generated.');
      return textPart ? textPart.text : 'I processed your request.';
    }

    // Process all requested tool calls
    console.log(`[AGENT] Model requested ${toolRequests.length} tool calls.`);
    const toolResults = [];

    for (const toolReq of toolRequests) {
      const { name, toolUseId, input } = toolReq.toolUse;
      try {
        const resultString = await executeTool(name, input, config);
        toolResults.push({
          toolResult: {
            toolUseId,
            content: [{ text: resultString }],
            status: "success"
          }
        });
      } catch (error) {
        console.error(`[AGENT] Tool execution error for "${name}":`, error.message);
        toolResults.push({
          toolResult: {
            toolUseId,
            content: [{ text: `Error: ${error.message}` }],
            status: "error"
          }
        });
      }
    }

    // Add tool results as the next user message to the Converse session
    formattedMessages.push({
      role: "user",
      content: toolResults
    });
  }

  throw new Error('Tool execution loop limit exceeded (max 5 rounds).');
};

const createAgent = () => {
  return {
    invoke: async ({ messages, consumerId, authHeader }) => {
      try {
        const reply = await runConverseAgent(messages, consumerId, authHeader);
        return {
          messages: [...messages, { role: 'assistant', content: reply }]
        };
      } catch (error) {
        console.error('[AGENT] Fatal agent invocation error:', error);
        throw error;
      }
    }
  };
};

module.exports = { createAgent };
