const { Router } = require('express');
const pool = require('../../db');
const messages = require('../constants/messages');
const { authenticateToken } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

const router = Router();

router.get('/profile', authenticateToken, asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT id, phone, name, role, skills, address, lat, lng, points, service_hours, avatar FROM users WHERE id = ?',
    [req.user.id],
  );

  if (rows.length === 0) {
    return res.status(404).json({ message: messages.user.notFound });
  }

  res.json({ user: rows[0] });
}));

router.put('/profile', authenticateToken, asyncHandler(async (req, res) => {
  const { name, skills, address, lat, lng } = req.body;

  await pool.query(
    'UPDATE users SET name = ?, skills = ?, address = ?, lat = ?, lng = ? WHERE id = ?',
    [name, skills, address, lat, lng, req.user.id],
  );

  res.json({ message: messages.user.updated });
}));

module.exports = router;
