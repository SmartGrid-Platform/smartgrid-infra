exports.handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  const rate_per_unit = event.rate_per_unit !== undefined ? parseFloat(event.rate_per_unit) : 0.00;
  const fixed_charge = event.fixed_charge !== undefined ? parseFloat(event.fixed_charge) : 0.00;
  return { rate_per_unit, fixed_charge };
};
