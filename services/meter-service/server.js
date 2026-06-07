require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3003;

app.listen(PORT, () => {
  console.log(`[Meter Service] Running on port ${PORT}`);
  console.log(`[Meter Service] Swagger Docs available at http://localhost:${PORT}/api-docs`);
});
