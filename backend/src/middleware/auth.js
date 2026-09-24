const jwt = require('jsonwebtoken');
const env = require('../config/env');
const messages = require('../constants/messages');

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: messages.auth.unauthorized });
  }

  jwt.verify(token, env.jwtSecret, (err, user) => {
    if (err) {
      return res.status(403).json({ message: messages.auth.invalidToken });
    }

    req.user = user;
    next();
  });
};

module.exports = {
  authenticateToken,
};
