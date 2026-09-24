const express = require('express');
const cors = require('cors');
const { registerRoutes } = require('./routes');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

const createApp = () => {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  registerRoutes(app);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};

module.exports = {
  createApp,
};
