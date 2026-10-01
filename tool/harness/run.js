const scenarios = {
  daoyuan_alerts: require('./scenarios/daoyuan_alerts'),
};
const name = process.argv[2] || 'daoyuan_alerts';
if (!scenarios[name]) {
  console.error(`Unknown scenario: ${name}`);
  process.exit(1);
}
scenarios[name].run().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
