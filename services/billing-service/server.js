require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3004;

app.listen(PORT, () => {
  console.log(`[Billing Service] Running on port ${PORT}`);
  console.log(`[Billing Service] Swagger Docs available at http://localhost:${PORT}/api-docs`);
});
