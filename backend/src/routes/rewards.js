const { Router } = require('express');
const pool = require('../../db');
const messages = require('../constants/messages');
const { authenticateToken } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

const router = Router();

router.get('/users/ranking', asyncHandler(async (req, res) => {
  const [rows] = await pool.query("SELECT id, name, service_hours, points FROM users WHERE role = 'volunteer' ORDER BY points DESC LIMIT 20");
  res.json({ ranking: rows });
}));

router.get('/gifts', asyncHandler(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM gifts ORDER BY points_required');
  res.json({ gifts: rows });
}));

router.post('/gifts/:id/exchange', authenticateToken, asyncHandler(async (req, res) => {
  const giftId = req.params.id;
  const [gifts] = await pool.query('SELECT * FROM gifts WHERE id = ?', [giftId]);

  if (gifts.length === 0) {
    return res.status(404).json({ message: messages.rewards.giftNotFound });
  }

  const [users] = await pool.query('SELECT * FROM users WHERE id = ?', [req.user.id]);
  if (users[0].points < gifts[0].points_required) {
    return res.status(400).json({ message: messages.rewards.insufficientPoints });
  }

  await pool.query(
    'UPDATE users SET points = points - ? WHERE id = ?',
    [gifts[0].points_required, req.user.id],
  );

  await pool.query(
    'INSERT INTO exchanges (user_id, gift_id, points) VALUES (?, ?, ?)',
    [req.user.id, giftId, gifts[0].points_required],
  );

  res.json({ message: messages.rewards.exchanged });
}));

router.get('/my/exchanges', authenticateToken, asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT e.*, g.name, g.description, g.image FROM exchanges e LEFT JOIN gifts g ON e.gift_id = g.id WHERE e.user_id = ? ORDER BY e.created_at DESC',
    [req.user.id],
  );

  res.json({ exchanges: rows });
}));

module.exports = router;
