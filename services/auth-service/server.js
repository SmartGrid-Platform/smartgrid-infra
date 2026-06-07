require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3001;

app.listen(PORT, () => {
  console.log(`[Auth Service] Running on port ${PORT}`);
  console.log(`[Auth Service] Swagger Docs available at http://localhost:${PORT}/api-docs`);
});
