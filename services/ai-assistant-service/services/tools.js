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
      return await scrapeDuckDuckGo(args.query);
    }
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
};

module.exports = {
  toolsList,
  executeTool
};
