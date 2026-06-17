const axios = require('axios');
const { DynamicTool } = require('@langchain/core/tools');

const CONSUMER_URL = process.env.CONSUMER_SERVICE_URL || 'http://localhost:3002';
const METER_URL = process.env.METER_SERVICE_URL || 'http://localhost:3003';
const BILLING_URL = process.env.BILLING_SERVICE_URL || 'http://localhost:3004';

// A helper to generate axios headers if we have a stored authHeader
const getHeaders = (config) => {
  if (config && config.authHeader) {
    return { Authorization: config.authHeader };
  }
  return {};
};

const getConsumerProfileTool = new DynamicTool({
  name: "get_consumer_profile",
  description: "Fetches the consumer's profile information, including balance, address, phone, and connection status. Does not require arguments.",
  func: async (input, runManager, config) => {
    try {
      const headers = getHeaders(config.configurable);
      const res = await axios.get(`${CONSUMER_URL}/api/consumers/me`, { headers });
      return JSON.stringify(res.data);
    } catch (error) {
      console.error('get_consumer_profile error:', error?.response?.data || error.message);
      return `Failed to fetch consumer profile: ${error?.response?.data?.error || error.message}`;
    }
  }
});

const getConsumerBillsTool = new DynamicTool({
  name: "get_consumer_bills",
  description: "Fetches the historical bills for the consumer. It requires no input.",
  func: async (input, runManager, config) => {
    try {
      const { consumerId } = config.configurable;
      const headers = getHeaders(config.configurable);
      if (!consumerId) return "Error: Missing consumer ID in context";
      const res = await axios.get(`${BILLING_URL}/api/bills/consumer/${consumerId}`, { headers });
      return JSON.stringify(res.data);
    } catch (error) {
      console.error('get_consumer_bills error:', error?.response?.data || error.message);
      return `Failed to fetch bills: ${error?.response?.data?.error || error.message}`;
    }
  }
});

const getConsumerRechargesTool = new DynamicTool({
  name: "get_consumer_recharges",
  description: "Fetches the recent recharge/payment history for the consumer. Requires no input.",
  func: async (input, runManager, config) => {
    try {
      const { consumerId } = config.configurable;
      const headers = getHeaders(config.configurable);
      if (!consumerId) return "Error: Missing consumer ID in context";
      const res = await axios.get(`${BILLING_URL}/api/recharges/consumer/${consumerId}`, { headers });
      return JSON.stringify(res.data);
    } catch (error) {
      return `Failed to fetch recharges: ${error?.response?.data?.error || error.message}`;
    }
  }
});

const getConsumerMetersAndUsageTool = new DynamicTool({
  name: "get_consumer_meters_and_usage",
  description: "Fetches the consumer's assigned meters and the recent 15 usage readings for the first meter. Requires no input.",
  func: async (input, runManager, config) => {
    try {
      const { consumerId } = config.configurable;
      const headers = getHeaders(config.configurable);
      if (!consumerId) return "Error: Missing consumer ID in context";
      
      const meterRes = await axios.get(`${METER_URL}/api/meters/consumer/${consumerId}`, { headers });
      const meters = Array.isArray(meterRes.data) ? meterRes.data : (meterRes.data?.meters || []);
      
      let readings = [];
      if (meters.length > 0) {
        const readingRes = await axios.get(`${METER_URL}/api/meters/${meters[0].id}/readings`, { headers });
        readings = Array.isArray(readingRes.data) ? readingRes.data : (readingRes.data?.readings || []);
      }
      
      return JSON.stringify({ meters, recent_readings: readings.slice(-15) });
    } catch (error) {
      return `Failed to fetch meters and usage: ${error?.response?.data?.error || error.message}`;
    }
  }
});

const getActiveTariffTool = new DynamicTool({
  name: "get_active_tariff",
  description: "Fetches the current active electricity tariff rates. Requires no input.",
  func: async (input, runManager, config) => {
    try {
      const headers = getHeaders(config.configurable);
      const res = await axios.get(`${BILLING_URL}/api/tariffs`, { headers });
      return JSON.stringify(res.data);
    } catch (error) {
      return `Failed to fetch tariffs: ${error?.response?.data?.error || error.message}`;
    }
  }
});

const getAllTools = () => [
  getConsumerProfileTool,
  getConsumerBillsTool,
  getConsumerRechargesTool,
  getConsumerMetersAndUsageTool,
  getActiveTariffTool
];

module.exports = { 
  getAllTools,
  getConsumerProfileTool,
  getConsumerBillsTool,
  getConsumerRechargesTool,
  getConsumerMetersAndUsageTool,
  getActiveTariffTool
};
