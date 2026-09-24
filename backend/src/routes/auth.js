const { Router } = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../../db');
const env = require('../config/env');
const messages = require('../constants/messages');
const asyncHandler = require('../utils/asyncHandler');

const router = Router();

router.post('/register', asyncHandler(async (req, res) => {
  const { phone, password, name, role, skills, address, lat, lng } = req.body;

  if (!phone || !password || !name || !role) {
    return res.status(400).json({ message: messages.authFlow.missingRegisterFields });
  }

  const [rows] = await pool.query('SELECT * FROM users WHERE phone = ?', [phone]);
  if (rows.length > 0) {
    return res.status(400).json({ message: messages.authFlow.phoneRegistered });
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  const [result] = await pool.query(
    'INSERT INTO users (phone, password, name, role, skills, address, lat, lng) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [phone, hashedPassword, name, role, skills || '', address || '', lat || 0, lng || 0],
  );

  const token = jwt.sign(
    { id: result.insertId, phone, name, role },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn },
  );

  res.json({
    message: messages.authFlow.registerSuccess,
    token,
    user: { id: result.insertId, phone, name, role, skills, address },
  });
}));

router.post('/login', asyncHandler(async (req, res) => {
  const { phone, password } = req.body;

  if (!phone || !password) {
    return res.status(400).json({ message: messages.authFlow.missingLoginFields });
  }

  const [rows] = await pool.query('SELECT * FROM users WHERE phone = ?', [phone]);
  if (rows.length === 0) {
    return res.status(400).json({ message: messages.authFlow.userNotFound });
  }

  const user = rows[0];
  const valid = await bcrypt.compare(password, user.password);
  if (!valid) {
    return res.status(400).json({ message: messages.authFlow.wrongPassword });
  }

  const token = jwt.sign(
    { id: user.id, phone: user.phone, name: user.name, role: user.role },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn },
  );

  res.json({
    message: messages.authFlow.loginSuccess,
    token,
    user: {
      id: user.id,
      phone: user.phone,
      name: user.name,
      role: user.role,
      skills: user.skills,
      address: user.address,
      points: user.points,
      service_hours: user.service_hours,
    },
  });
}));

module.exports = router;
