const { sequelize } = require('./models');

async function runMigrations() {
  console.log('Starting database synchronization...');
  try {
    await sequelize.authenticate();
    console.log('Database connection has been established successfully.');
    
    // Sync all models to DB tables
    await sequelize.sync({ alter: true });
    console.log('Database tables successfully synchronized.');
    process.exit(0);
  } catch (error) {
    console.error('Unable to synchronize database:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  runMigrations();
}

module.exports = runMigrations;
