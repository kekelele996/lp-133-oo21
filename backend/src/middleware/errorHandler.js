const logger = require('../utils/logger');
const messages = require('../constants/messages');

const notFoundHandler = (req, res) => {
  res.status(404).json({ message: messages.errors.notFound, path: req.path });
};

const errorHandler = (err, req, res, next) => {
  logger.error(messages.errors.internal, err.stack || err.message || err);
  res.status(500).json({ message: messages.errors.internal });
};

module.exports = {
  notFoundHandler,
  errorHandler,
};
