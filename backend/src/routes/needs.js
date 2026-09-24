const { Router } = require('express');
const pool = require('../../db');
const messages = require('../constants/messages');
const { authenticateToken } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

const router = Router();

const toPageInt = (value, fallback) => {
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const appendDistance = (needs, lat, lng) => {
  const latitude = Number(lat);
  const longitude = Number(lng);

  needs.forEach((need) => {
    const radius = 6371;
    const dLat = (Number(need.lat) - latitude) * Math.PI / 180;
    const dLng = (Number(need.lng) - longitude) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(latitude * Math.PI / 180) * Math.cos(Number(need.lat) * Math.PI / 180) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    need.distance = radius * c;
  });
};

router.post('/', authenticateToken, asyncHandler(async (req, res) => {
  const { title, description, type, address, lat, lng, expected_time } = req.body;

  if (!title || !type) {
    return res.status(400).json({ message: messages.needs.missingFields });
  }

  const [result] = await pool.query(
    "INSERT INTO needs (user_id, title, description, type, address, lat, lng, expected_time, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')",
    [req.user.id, title, description, type, address, lat, lng, expected_time],
  );

  res.json({ message: messages.needs.created, needId: result.insertId });
}));

router.get('/', asyncHandler(async (req, res) => {
  const { type, lat, lng, distance } = req.query;
  const page = toPageInt(req.query.page, 1);
  const pageSize = toPageInt(req.query.pageSize, 10);

  let sql = "SELECT n.*, u.name as user_name, u.phone as user_phone FROM needs n LEFT JOIN users u ON n.user_id = u.id WHERE n.status = 'pending'";
  const params = [];

  if (type && type !== 'all') {
    sql += ' AND n.type = ?';
    params.push(type);
  }

  sql += ' ORDER BY n.created_at DESC LIMIT ? OFFSET ?';
  params.push(pageSize, (page - 1) * pageSize);

  const [rows] = await pool.query(sql, params);

  if (lat && lng) {
    appendDistance(rows, lat, lng);

    if (distance) {
      const maxDistance = Number(distance);
      const filteredRows = rows.filter((need) => need.distance <= maxDistance);
      res.json({ needs: filteredRows, total: filteredRows.length, page, pageSize });
      return;
    }
  }

  const [countResult] = await pool.query("SELECT COUNT(*) as total FROM needs WHERE status = 'pending'");

  res.json({
    needs: rows,
    total: countResult[0].total,
    page,
    pageSize,
  });
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT n.*, u.name as user_name, u.phone as user_phone FROM needs n LEFT JOIN users u ON n.user_id = u.id WHERE n.id = ?',
    [req.params.id],
  );

  if (rows.length === 0) {
    return res.status(404).json({ message: messages.needs.notFound });
  }

  res.json({ need: rows[0] });
}));

router.post('/:id/accept', authenticateToken, asyncHandler(async (req, res) => {
  const needId = req.params.id;
  const [needs] = await pool.query('SELECT * FROM needs WHERE id = ?', [needId]);

  if (needs.length === 0) {
    return res.status(404).json({ message: messages.needs.notFound });
  }

  if (needs[0].status !== 'pending') {
    return res.status(400).json({ message: messages.needs.alreadyAccepted });
  }

  if (needs[0].user_id === req.user.id) {
    return res.status(400).json({ message: messages.needs.cannotAcceptOwnNeed });
  }

  await pool.query(
    "UPDATE needs SET status = 'accepted', volunteer_id = ? WHERE id = ?",
    [req.user.id, needId],
  );

  await pool.query(
    "INSERT INTO orders (need_id, user_id, volunteer_id, status) VALUES (?, ?, ?, 'in_progress')",
    [needId, needs[0].user_id, req.user.id],
  );

  res.json({ message: messages.needs.accepted });
}));

module.exports = router;
