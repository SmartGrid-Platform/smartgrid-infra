const { Meter, Consumer } = require('/home/ubuntu/electricity-grid/shared/database/models');
(async () => {
  try {
    const meters = await Meter.findAll({ include: [{ model: Consumer, as: 'consumer' }] });
    console.log('--- Meter Assignments ---');
    meters.forEach(m => {
      console.log(`ID: ${m.id} | Meter #: ${m.meter_number} | Consumer ID: ${m.consumer_id} | Consumer #: ${m.consumer ? m.consumer.consumer_number : 'None'}`);
    });
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
})();
