require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3005;

app.listen(PORT, () => {
  console.log(`[Alert Service] Running on port ${PORT}`);
  console.log(`[Alert Service] Swagger Docs available at http://localhost:${PORT}/api-docs`);
});
