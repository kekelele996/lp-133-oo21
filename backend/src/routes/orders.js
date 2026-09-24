const { Router } = require('express');
const pool = require('../../db');
const messages = require('../constants/messages');
const { authenticateToken } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

const router = Router();

const sameId = (a, b) => String(a) === String(b);

const parseHours = (value) => {
  const hours = Number(value);
  if (!Number.isFinite(hours) || hours <= 0 || hours > 999) {
    return null;
  }
  return Math.round(hours * 100) / 100;
};

router.get('/', authenticateToken, asyncHandler(async (req, res) => {
  const { status } = req.query;
  let sql = `SELECT o.*, n.title, n.type, n.address,
    u1.name as user_name, u2.name as volunteer_name,
    (SELECT COUNT(*) FROM reviews r WHERE r.order_id = o.id AND r.reviewer_id = ?) as my_review_count
    FROM orders o
    LEFT JOIN needs n ON o.need_id = n.id
    LEFT JOIN users u1 ON o.user_id = u1.id
    LEFT JOIN users u2 ON o.volunteer_id = u2.id
    WHERE o.user_id = ? OR o.volunteer_id = ?`;
  const params = [req.user.id, req.user.id, req.user.id];

  if (status === 'in_progress') {
    // “进行中”同时包含服务中与待居民确认两种未结算状态
    sql += " AND o.status IN ('in_progress', 'submitted')";
  } else if (status) {
    sql += ' AND o.status = ?';
    params.push(status);
  }

  sql += ' ORDER BY o.created_at DESC';

  const [rows] = await pool.query(sql, params);
  res.json({ orders: rows });
}));

// 志愿者服务结束后填写实际时长并提交（被退回后可重新提交）
router.post('/:id/submit', authenticateToken, asyncHandler(async (req, res) => {
  const { service_hours } = req.body;
  const orderId = req.params.id;
  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);

  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];

  if (!sameId(order.volunteer_id, req.user.id)) {
    return res.status(403).json({ message: messages.orders.notParticipant });
  }

  const hours = parseHours(service_hours);
  if (hours === null) {
    return res.status(400).json({ message: messages.orders.invalidServiceHours });
  }

  if (order.status !== 'in_progress') {
    return res.status(400).json({ message: messages.orders.submitWrongStatus });
  }

  await pool.query(
    `UPDATE orders
     SET status = 'submitted', service_hours = ?, submitted_at = NOW(), reject_reason = NULL
     WHERE id = ?`,
    [hours, orderId],
  );

  res.json({ message: messages.orders.submitted });
}));

// 居民确认服务结果：确认后才为志愿者结算时长与积分
router.post('/:id/confirm', authenticateToken, asyncHandler(async (req, res) => {
  const orderId = req.params.id;
  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);

  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];

  if (!sameId(order.user_id, req.user.id)) {
    return res.status(403).json({ message: messages.orders.confirmOnlyResident });
  }

  if (order.status !== 'submitted') {
    return res.status(400).json({ message: messages.orders.confirmWrongStatus });
  }

  const hours = Number(order.service_hours);
  const earnedPoints = Math.round(hours * 10);

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [result] = await conn.query(
      `UPDATE orders
       SET status = 'completed', confirmed_at = NOW(), end_time = NOW()
       WHERE id = ? AND status = 'submitted'`,
      [orderId],
    );
    if (result.affectedRows === 0) {
      await conn.rollback();
      return res.status(400).json({ message: messages.orders.confirmWrongStatus });
    }

    await conn.query("UPDATE needs SET status = 'completed' WHERE id = ?", [order.need_id]);

    await conn.query(
      'UPDATE users SET service_hours = service_hours + ?, points = points + ? WHERE id = ?',
      [hours, earnedPoints, order.volunteer_id],
    );

    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }

  res.json({ message: messages.orders.confirmed, service_hours: hours, points: earnedPoints });
}));

// 居民认为服务未做完：写明原因退回，订单继续，志愿者可重新提交
router.post('/:id/reject', authenticateToken, asyncHandler(async (req, res) => {
  const { reason } = req.body;
  const orderId = req.params.id;
  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);

  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];

  if (!sameId(order.user_id, req.user.id)) {
    return res.status(403).json({ message: messages.orders.rejectOnlyResident });
  }

  if (order.status !== 'submitted') {
    return res.status(400).json({ message: messages.orders.confirmWrongStatus });
  }

  const rejectReason = typeof reason === 'string' ? reason.trim() : '';
  if (!rejectReason) {
    return res.status(400).json({ message: messages.orders.missingRejectReason });
  }

  await pool.query(
    `UPDATE orders
     SET status = 'in_progress', reject_reason = ?, submitted_at = NULL
     WHERE id = ?`,
    [rejectReason.slice(0, 500), orderId],
  );

  res.json({ message: messages.orders.rejected });
}));

// 结算后订单双方各评价一次；重复评价或局外人操作均失败
router.post('/:id/review', authenticateToken, asyncHandler(async (req, res) => {
  const { rating, comment } = req.body;
  const orderId = req.params.id;
  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);

  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];

  if (!sameId(order.user_id, req.user.id) && !sameId(order.volunteer_id, req.user.id)) {
    return res.status(403).json({ message: messages.orders.notParticipant });
  }

  if (order.status !== 'completed') {
    return res.status(400).json({ message: messages.orders.reviewWrongStatus });
  }

  const score = Number(rating);
  if (!Number.isInteger(score) || score < 1 || score > 5) {
    return res.status(400).json({ message: messages.orders.invalidRating });
  }

  const [existing] = await pool.query(
    'SELECT id FROM reviews WHERE order_id = ? AND reviewer_id = ?',
    [orderId, req.user.id],
  );
  if (existing.length > 0) {
    return res.status(409).json({ message: messages.orders.alreadyReviewed });
  }

  const targetId = sameId(order.user_id, req.user.id) ? order.volunteer_id : order.user_id;

  try {
    await pool.query(
      'INSERT INTO reviews (order_id, reviewer_id, target_id, rating, comment) VALUES (?, ?, ?, ?, ?)',
      [orderId, req.user.id, targetId, score, comment || null],
    );
  } catch (err) {
    // 兜底唯一约束 uk_order_reviewer，防止并发下重复评价
    if (err && err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: messages.orders.alreadyReviewed });
    }
    throw err;
  }

  res.json({ message: messages.orders.reviewed });
}));

module.exports = router;
