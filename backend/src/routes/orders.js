const { Router } = require('express');
const pool = require('../../db');
const messages = require('../constants/messages');
const { authenticateToken } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

const router = Router();

// 查询订单时附带当前用户是否已评价
const ORDER_SELECT = `SELECT o.*, n.title, n.type, n.address,
  u1.name as user_name, u2.name as volunteer_name,
  EXISTS(SELECT 1 FROM reviews r WHERE r.order_id = o.id AND r.reviewer_id = ?) as reviewed
  FROM orders o
  LEFT JOIN needs n ON o.need_id = n.id
  LEFT JOIN users u1 ON o.user_id = u1.id
  LEFT JOIN users u2 ON o.volunteer_id = u2.id`;

router.get('/', authenticateToken, asyncHandler(async (req, res) => {
  const { status } = req.query;
  let sql = `${ORDER_SELECT}
    WHERE o.user_id = ? OR o.volunteer_id = ?`;
  const params = [req.user.id, req.user.id, req.user.id];

  if (status) {
    sql += ' AND o.status = ?';
    params.push(status);
  }

  sql += ' ORDER BY o.created_at DESC';

  const [rows] = await pool.query(sql, params);
  res.json({ orders: rows });
}));

// 志愿者提交服务结果（实际时长），等待居民确认
router.post('/:id/submit', authenticateToken, asyncHandler(async (req, res) => {
  const orderId = req.params.id;
  const serviceHours = Number(req.body.service_hours);

  if (!Number.isFinite(serviceHours) || serviceHours <= 0 || serviceHours > 24) {
    return res.status(400).json({ message: messages.orders.invalidServiceHours });
  }

  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);
  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];
  if (order.volunteer_id !== req.user.id) {
    return res.status(403).json({ message: messages.orders.onlyVolunteerSubmit });
  }

  if (order.status !== 'in_progress') {
    return res.status(400).json({ message: messages.orders.cannotSubmit });
  }

  await pool.query(
    `UPDATE orders
     SET status = 'pending_confirm', service_hours = ?, reject_reason = NULL, submitted_at = NOW()
     WHERE id = ?`,
    [serviceHours, orderId],
  );

  res.json({ message: messages.orders.submitted });
}));

// 居民确认服务结果：结算，为志愿者记入时长和积分
router.post('/:id/confirm', authenticateToken, asyncHandler(async (req, res) => {
  const orderId = req.params.id;
  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);

  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];
  if (order.user_id !== req.user.id) {
    return res.status(403).json({ message: messages.orders.onlyResidentConfirm });
  }

  if (order.status !== 'pending_confirm') {
    return res.status(400).json({ message: messages.orders.cannotConfirm });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    await conn.query(
      `UPDATE orders SET status = 'completed', confirmed_at = NOW() WHERE id = ?`,
      [orderId],
    );
    await conn.query(
      "UPDATE needs SET status = 'completed' WHERE id = ?",
      [order.need_id],
    );

    const hours = Number(order.service_hours);
    await conn.query(
      'UPDATE users SET service_hours = service_hours + ?, points = points + ? WHERE id = ?',
      [hours, hours * 10, order.volunteer_id],
    );

    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }

  res.json({ message: messages.orders.confirmed });
}));

// 居民退回服务结果：写明原因，订单回到服务中，志愿者可重新提交
router.post('/:id/reject', authenticateToken, asyncHandler(async (req, res) => {
  const orderId = req.params.id;
  const reason = (req.body.reason || '').trim();

  if (!reason) {
    return res.status(400).json({ message: messages.orders.reasonRequired });
  }

  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);

  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];
  if (order.user_id !== req.user.id) {
    return res.status(403).json({ message: messages.orders.onlyResidentConfirm });
  }

  if (order.status !== 'pending_confirm') {
    return res.status(400).json({ message: messages.orders.cannotReject });
  }

  await pool.query(
    `UPDATE orders SET status = 'in_progress', reject_reason = ?, submitted_at = NULL WHERE id = ?`,
    [reason.slice(0, 500), orderId],
  );

  res.json({ message: messages.orders.rejected });
}));

// 结算后双方各评价一次；重复评价或局外人评价失败
router.post('/:id/review', authenticateToken, asyncHandler(async (req, res) => {
  const { rating, comment } = req.body;
  const ratingNum = Number(rating);
  const orderId = req.params.id;

  if (!Number.isInteger(ratingNum) || ratingNum < 1 || ratingNum > 5) {
    return res.status(400).json({ message: messages.orders.invalidRating });
  }

  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);

  if (orders.length === 0) {
    return res.status(404).json({ message: messages.orders.notFound });
  }

  const order = orders[0];
  const isResident = order.user_id === req.user.id;
  const isVolunteer = order.volunteer_id === req.user.id;

  if (!isResident && !isVolunteer) {
    return res.status(403).json({ message: messages.orders.forbidden });
  }

  if (order.status !== 'completed') {
    return res.status(400).json({ message: messages.orders.reviewAfterCompletion });
  }

  const targetId = isResident ? order.volunteer_id : order.user_id;

  try {
    await pool.query(
      'INSERT INTO reviews (order_id, reviewer_id, target_id, rating, comment) VALUES (?, ?, ?, ?, ?)',
      [orderId, req.user.id, targetId, ratingNum, comment || null],
    );
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: messages.orders.alreadyReviewed });
    }
    throw err;
  }

  res.json({ message: messages.orders.reviewed });
}));

module.exports = router;
