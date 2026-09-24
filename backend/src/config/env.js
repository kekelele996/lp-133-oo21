require('dotenv').config();

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

module.exports = {
  port: toNumber(process.env.PORT, 3233),
  jwtSecret: process.env.JWT_SECRET || 'volunteer_secret_key_2026',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: toNumber(process.env.DB_PORT, 5733),
    user: process.env.DB_USER || 'volunteer',
    password: process.env.DB_PASSWORD || 'volunteer_pwd',
    name: process.env.DB_NAME || 'volunteer_db',
  },
};
