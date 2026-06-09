const { MeterReading } = require('/home/ubuntu/electricity-grid/shared/database/models');
(async () => {
  try {
    const readings = await MeterReading.findAll();
    console.log('--- Readings ---');
    readings.forEach(r => {
      console.log(`ID: ${r.id} | Meter ID: ${r.meter_id} | Units: ${r.units_consumed} | Date: ${r.reading_date}`);
    });
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
})();
