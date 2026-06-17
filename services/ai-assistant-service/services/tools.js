const axios = require('axios');

const CONSUMER_URL = process.env.CONSUMER_SERVICE_URL || 'http://localhost:3002';
const METER_URL = process.env.METER_SERVICE_URL || 'http://localhost:3003';
const BILLING_URL = process.env.BILLING_SERVICE_URL || 'http://localhost:3004';

const getHeaders = (config) => {
  if (config && config.authHeader) {
    return { Authorization: config.authHeader };
  }
  return {};
};

const searchWikipedia = async (query) => {
  try {
    const url = `https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(query)}&format=json&utf8=1`;
    console.log('[SEARCH] Querying Wikipedia:', url);
    const response = await axios.get(url, {
      headers: {
        'User-Agent': 'SmartGridUtilityAssistant/1.0 (admin@smartgrid.com)'
      },
      timeout: 5000
    });
    const searchResults = response?.data?.query?.search;
    if (!searchResults || searchResults.length === 0) {
      return "No search results found.";
    }
    
    const snippetList = [];
    for (let i = 0; i < Math.min(3, searchResults.length); i++) {
      const item = searchResults[i];
      const cleanSnippet = item.snippet.replace(/<[^>]*>/g, '').replace(/&quot;/g, '"').replace(/&amp;/g, '&');
      snippetList.push(`Title: ${item.title}\nSnippet: ${cleanSnippet}`);
    }
    return snippetList.join('\n\n');
  } catch (error) {
    console.error('[SEARCH] Wikipedia failed:', error.message);
    return 'Web search failed: ' + error.message;
  }
};

const scrapeDuckDuckGo = async (query) => {
  try {
    const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
    console.log('[SEARCH] Querying DuckDuckGo:', url);
    const response = await axios.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5'
      },
      timeout: 5000
    });
    const html = response.data;
    if (html.includes('anomaly-modal') || html.includes('captcha') || html.includes('bots use DuckDuckGo too')) {
      throw new Error('Bot challenge block detected');
    }
    
    const results = [];
    const regex = /class="[^"]*snippet[^"]*"[^>]*>([\s\S]*?)<\/a>/g;
    let match;
    while ((match = regex.exec(html)) !== null && results.length < 5) {
      const text = match[1].replace(/<[^>]*>/g, '').trim();
      results.push(text);
    }
    
    if (results.length === 0) {
      const cellRegex = /<td class="result-snippet"[^>]*>([\s\S]*?)<\/td>/g;
      while ((match = cellRegex.exec(html)) !== null && results.length < 5) {
        const text = match[1].replace(/<[^>]*>/g, '').trim();
        results.push(text);
      }
    }
    
    if (results.length === 0) {
      throw new Error('No matches found in HTML');
    }
    
    return results.join('\n\n');
  } catch (error) {
    console.warn(`[SEARCH] DuckDuckGo failed (${error.message}). Falling back to Wikipedia...`);
    return await searchWikipedia(query);
  }
};

const toolsList = [
  {
    toolSpec: {
      name: "get_consumer_profile",
      description: "Fetches the consumer's profile information, including balance, address, phone, and connection status. Does not require arguments.",
      inputSchema: {
        json: {
          type: "object",
          properties: {}
        }
      }
    }
  },
  {
    toolSpec: {
      name: "get_consumer_bills",
      description: "Fetches the historical billing records for the consumer, listing details like units used, billing month, amounts, and statuses.",
      inputSchema: {
        json: {
          type: "object",
          properties: {}
        }
      }
    }
  },
  {
    toolSpec: {
      name: "get_consumer_recharges",
      description: "Fetches the consumer's recharge/payment history, including amount and transaction dates.",
      inputSchema: {
        json: {
          type: "object",
          properties: {}
        }
      }
    }
  },
  {
    toolSpec: {
      name: "get_consumer_meters_and_usage",
      description: "Fetches the consumer's smart meters and recent consumption readings.",
      inputSchema: {
        json: {
          type: "object",
          properties: {}
        }
      }
    }
  },
  {
    toolSpec: {
      name: "get_active_tariff",
      description: "Fetches the current active global electricity tariff rates.",
      inputSchema: {
        json: {
          type: "object",
          properties: {}
        }
      }
    }
  },
  {
    toolSpec: {
      name: "web_search",
      description: "Performs a web search to answer general electricity, utility, regulatory, or energy efficiency questions when platform data is insufficient.",
      inputSchema: {
        json: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "The search query (e.g. 'domestic tariff in Tamil Nadu' or 'solar net metering explanation')"
            }
          },
          required: ["query"]
        }
      }
    }
  }
];

const LOCAL_KNOWLEDGE_BASE = {
  andhra_pradesh: `Andhra Pradesh Electricity Tariff Slabs (APSPDCL/APEPDCL):
- Domestic Slabs (Prepaid/Postpaid):
  * 0 - 50 units: ₹1.45 per unit
  * 51 - 100 units: ₹2.60 per unit
  * 101 - 200 units: ₹3.60 per unit
  * 201 - 300 units: ₹7.20 per unit
  * 301 - 400 units: ₹8.50 per unit
  * Above 400 units: ₹9.50 per unit
- Fixed Charge / Customer Charges: ₹25 to ₹75 depending on consumption range.
Source: Andhra Pradesh Electricity Regulatory Commission (APERC) standard domestic tariff schedule.`,

  telangana: `Telangana Electricity Tariff Slabs (TSSPDCL/TSNPDCL):
- Domestic Slabs:
  * 0 - 50 units: ₹1.45 per unit
  * 51 - 100 units: ₹2.60 per unit
  * 101 - 200 units: ₹4.30 per unit
  * 201 - 300 units: ₹7.20 per unit
  * 301 - 400 units: ₹8.50 per unit
  * 401 - 800 units: ₹9.00 per unit
  * Above 800 units: ₹10.00 per unit
- Customer Charges: ₹25 to ₹80 per month.
Source: Telangana State Electricity Regulatory Commission (TSERC) tariff order.`,

  tamil_nadu: `Tamil Nadu Electricity Tariff Slabs (TANGEDCO):
- Domestic Slabs (Bimonthly billing cycles):
  * 0 - 100 units: Free (100% Subsidy)
  * 101 - 200 units: ₹4.50 per unit
  * 201 - 500 units: ₹6.00 per unit (for 201-400 range) and ₹8.00 per unit (for 401-500 range)
  * Above 500 units: ₹9.00 to ₹11.00 per unit depending on consumption slabs.
- Fixed Charges: Fixed charges are merged into energy rates for domestic category.
Source: Tamil Nadu Electricity Regulatory Commission (TNERC) tariff revision schedule.`,

  karnataka: `Karnataka Electricity Tariff Slabs (BESCOM/HESCOM/GESCOM):
- Domestic Slabs (Prepaid/Postpaid):
  * Lifeline / Low Income (0 - 40 units): ₹4.15 per unit
  * General Domestic (0 - 100 units): ₹5.90 per unit
  * General Domestic (Above 100 units): ₹7.30 to ₹8.05 per unit
- Fixed Charges / Fixed Monthly Fees: ₹100 to ₹250 depending on sanctioned load (kW).
Source: Karnataka Electricity Regulatory Commission (KERC) tariff schedule.`,

  solar: `Solar Rooftop Tariffs & Net Metering Rules in India:
- Net Metering: Consumers get credits on their monthly bills for excess power exported from rooftop solar panels to the grid.
- Gross Metering: All solar power generated is exported to grid at a feed-in tariff, and consumer pays normal tariff for consumption.
- Net Feed-in Tariff: Excess exported units are credited/paid at ₹3.00 to ₹4.50 per unit (varying by state DISCOM guidelines, e.g. TSSPDCL or BESCOM).
Source: State Solar Rooftop Policies & Regulatory Guidelines.`,

  net_metering: `Net Metering Regulations:
- Applicability: Available for residential customers with rooftop solar systems (usually up to 100% or 150% of sanctioned load).
- Billing: Credits are carried forward to the next billing cycle. At the end of the financial year, any remaining excess credits are settled by the DISCOM at the average power purchase cost (APPC), typically around ₹3.00 to ₹4.20 per unit.
Source: State Electricity Regulatory Commissions (SERCs).`
};

const executeTool = async (name, args, config) => {
  const headers = getHeaders(config);
  const { consumerId } = config;
  
  console.log(`[AGENT-TOOLS] Executing tool "${name}" for consumer ID "${consumerId}"`);
  
  switch (name) {
    case 'get_consumer_profile': {
      const res = await axios.get(`${CONSUMER_URL}/api/consumers/me`, { headers });
      return JSON.stringify(res.data);
    }
    case 'get_consumer_bills': {
      if (!consumerId) return "Error: Missing consumer ID in context";
      const res = await axios.get(`${BILLING_URL}/api/bills/consumer/${consumerId}`, { headers });
      return JSON.stringify(res.data);
    }
    case 'get_consumer_recharges': {
      if (!consumerId) return "Error: Missing consumer ID in context";
      const res = await axios.get(`${BILLING_URL}/api/recharges/consumer/${consumerId}`, { headers });
      return JSON.stringify(res.data);
    }
    case 'get_consumer_meters_and_usage': {
      if (!consumerId) return "Error: Missing consumer ID in context";
      const meterRes = await axios.get(`${METER_URL}/api/meters/consumer/${consumerId}`, { headers });
      const meters = Array.isArray(meterRes.data) ? meterRes.data : (meterRes.data?.meters || []);
      let readings = [];
      if (meters.length > 0) {
        const readingRes = await axios.get(`${METER_URL}/api/meters/${meters[0].id}/readings`, { headers });
        readings = Array.isArray(readingRes.data) ? readingRes.data : (readingRes.data?.readings || []);
      }
      return JSON.stringify({ meters, recent_readings: readings.slice(-15) });
    }
    case 'get_active_tariff': {
      const res = await axios.get(`${BILLING_URL}/api/tariffs`, { headers });
      return JSON.stringify(res.data);
    }
    case 'web_search': {
      const q = args.query.toLowerCase();
      let localInfo = "";
      if (q.includes("andhra")) localInfo += LOCAL_KNOWLEDGE_BASE.andhra_pradesh + "\n\n";
      if (q.includes("telangana")) localInfo += LOCAL_KNOWLEDGE_BASE.telangana + "\n\n";
      if (q.includes("tamil nadu") || q.includes("tamilnadu") || q.includes("chennai")) localInfo += LOCAL_KNOWLEDGE_BASE.tamil_nadu + "\n\n";
      if (q.includes("karnataka") || q.includes("bangalore") || q.includes("bengaluru")) localInfo += LOCAL_KNOWLEDGE_BASE.karnataka + "\n\n";
      if (q.includes("solar")) localInfo += LOCAL_KNOWLEDGE_BASE.solar + "\n\n";
      if (q.includes("net metering") || q.includes("net-metering")) localInfo += LOCAL_KNOWLEDGE_BASE.net_metering + "\n\n";
      
      const searchResult = await scrapeDuckDuckGo(args.query);
      return (localInfo + searchResult).trim() || "No detailed search results found.";
    }
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
};

module.exports = {
  toolsList,
  executeTool
};
