function createBridge(config = {}) {
  const calls = [];
  async function sendRequest(type, payload) {
    calls.push({ type, payload });
    if (Object.prototype.hasOwnProperty.call(config, type)) {
      const value = config[type];
      return typeof value === 'function' ? value(payload) : value;
    }
    throw new Error(`No mock response configured for ${type}`);
  }
  async function thCall(type, args) {
    calls.push({ type, payload: args });
    if (Object.prototype.hasOwnProperty.call(config, type)) {
      const value = config[type];
      return typeof value === 'function' ? value(args) : value;
    }
    throw new Error(`No mock response configured for ${type}`);
  }
  return { calls, sendRequest, thCall };
}
module.exports = { createBridge };
