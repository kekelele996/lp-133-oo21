const healthRoutes = require('./health');
const authRoutes = require('./auth');
const userRoutes = require('./user');
const needsRoutes = require('./needs');
const ordersRoutes = require('./orders');
const messagesRoutes = require('./messages');
const rewardsRoutes = require('./rewards');

const registerRoutes = (app) => {
  app.use('/api', healthRoutes);
  app.use('/api/auth', authRoutes);
  app.use('/api/user', userRoutes);
  app.use('/api/needs', needsRoutes);
  app.use('/api/orders', ordersRoutes);
  app.use('/api/messages', messagesRoutes);
  app.use('/api', rewardsRoutes);
};

module.exports = {
  registerRoutes,
};
