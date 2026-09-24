const { createApp } = require('./src/app');
const env = require('./src/config/env');
const messages = require('./src/constants/messages');
const logger = require('./src/utils/logger');

const app = createApp();

app.listen(env.port, () => {
  logger.info(`${messages.server.started}，端口: ${env.port}`);
});
