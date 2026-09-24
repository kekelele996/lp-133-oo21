/**
 * End-to-end test for the new order settlement flow using an in-memory mock
 * of mysql2/promise. Run: node test-flow.js
 */
const Module = require('module');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// ---------- in-memory database ----------
const db = {
  users: [],
  needs: [],
  orders: [],
  reviews: [],
  gifts: [],
  exchanges: [],
  messages: [],
};
let seq = { users: 0, needs: 0, orders: 0, reviews: 0 };

const pwdHash = bcrypt.hashSync('123456', 10);
db.users.push(
  { id: ++seq.users, phone: '13900139001', password: pwdHash, name: 'resident1', role: 'resident', points: 0, service_hours: 0 },
  { id: ++seq.users, phone: '13900139002', password: pwdHash, name: 'resident2', role: 'resident', points: 0, service_hours: 0 },
  { id: ++seq.users, phone: '13800138001', password: pwdHash, name: 'vol1', role: 'volunteer', points: 100, service_hours: 10 },
  { id: ++seq.users, phone: '13800138002', password: pwdHash, name: 'vol2', role: 'volunteer', points: 0, service_hours: 0 },
);
const R1 = 1, R2 = 2, V1 = 3, V2 = 4;

// Minimal SQL emulator covering the statements used by orders.js / needs.js
class MockConn {
  async query(sql, params = []) {
    return run(sql, params);
  }
  async beginTransaction() {}
  async commit() {}
  async rollback() {}
  release() {}
}

const mockPool = {
  async query(sql, params) {
    return run(sql, params);
  },
  async getConnection() {
    return new MockConn();
  },
};

function run(sql, params) {
  let p = 0;
  const next = () => params[p++];
  sql = sql.replace(/\s+/g, ' ').trim();

  // ---- SELECT * FROM orders WHERE id = ?
  let m = sql.match(/^SELECT \* FROM orders WHERE id = \?$/);
  if (m) {
    const orderId = next();
    return [db.orders.filter((o) => String(o.id) === String(orderId)).map(clone)];
  }

  // ---- orders list
  m = sql.match(/^SELECT o\.\*.*FROM orders o/);
  if (m) {
    const reviewerId = params[0];
    let rows = db.orders.filter((o) => o.user_id === params[1] || o.volunteer_id === params[2]);
    if (sql.includes("o.status IN ('in_progress', 'submitted')")) {
      rows = rows.filter((o) => ['in_progress', 'submitted'].includes(o.status));
    } else if (sql.includes('AND o.status = ?')) {
      // eslint-disable-next-line no-unused-vars
      const st = params[3];
      rows = rows.filter((o) => o.status === st);
    }
    rows = rows
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .map((o) => ({
        ...clone(o),
        title: 't', type: 'x', address: 'a', user_name: 'u', volunteer_name: 'v',
        my_review_count: db.reviews.filter((r) => String(r.order_id) === String(o.id) && String(r.reviewer_id) === String(reviewerId)).length,
      }));
    return [rows];
  }

  // ---- review existence
  m = sql.match(/^SELECT id FROM reviews WHERE order_id = \? AND reviewer_id = \?$/);
  if (m) {
    const orderId = next(); const reviewerId = next();
    return [db.reviews.filter((r) => String(r.order_id) === String(orderId) && String(r.reviewer_id) === String(reviewerId)).map(clone)];
  }

  // ---- UPDATE orders (various forms)
  m = sql.match(/^UPDATE orders SET status = 'submitted', service_hours = \?, submitted_at = NOW\(\), reject_reason = NULL WHERE id = \?$/);
  if (m) {
    const hours = next(); const id = next();
    const o = db.orders.find((x) => String(x.id) === String(id));
    o.status = 'submitted'; o.service_hours = hours; o.submitted_at = new Date(); o.reject_reason = null;
    return [{ affectedRows: 1 }];
  }

  m = sql.match(/^UPDATE orders SET status = 'completed', confirmed_at = NOW\(\), end_time = NOW\(\) WHERE id = \? AND status = 'submitted'$/);
  if (m) {
    const id = next();
    const o = db.orders.find((x) => String(x.id) === String(id));
    if (!o || o.status !== 'submitted') return [{ affectedRows: 0 }];
    o.status = 'completed'; o.confirmed_at = new Date(); o.end_time = new Date();
    return [{ affectedRows: 1 }];
  }

  m = sql.match(/^UPDATE orders SET status = 'in_progress', reject_reason = \?, submitted_at = NULL WHERE id = \?$/);
  if (m) {
    const reason = next(); const id = next();
    const o = db.orders.find((x) => String(x.id) === String(id));
    o.status = 'in_progress'; o.reject_reason = reason; o.submitted_at = null;
    return [{ affectedRows: 1 }];
  }

  // ---- UPDATE needs
  m = sql.match(/^UPDATE needs SET status = 'completed' WHERE id = \?$/);
  if (m) {
    const o = db.needs.find((x) => String(x.id) === String(next()));
    if (o) o.status = 'completed';
    return [{ affectedRows: 1 }];
  }

  // ---- UPDATE users hours/points
  m = sql.match(/^UPDATE users SET service_hours = service_hours \+ \?, points = points \+ \? WHERE id = \?$/);
  if (m) {
    const hours = next(); const points = next(); const id = next();
    const u = db.users.find((x) => String(x.id) === String(id));
    u.service_hours = Number(u.service_hours) + Number(hours);
    u.points += points;
    return [{ affectedRows: 1 }];
  }

  // ---- INSERT review
  m = sql.match(/^INSERT INTO reviews \(order_id, reviewer_id, target_id, rating, comment\) VALUES \(\?, \?, \?, \?, \?\)$/);
  if (m) {
    const [order_id, reviewer_id, target_id, rating, comment] = [next(), next(), next(), next(), next()];
    if (db.reviews.some((r) => String(r.order_id) === String(order_id) && String(r.reviewer_id) === String(reviewer_id))) {
      const err = new Error('dup'); err.code = 'ER_DUP_ENTRY'; throw err;
    }
    db.reviews.push({ id: ++seq.reviews, order_id, reviewer_id, target_id, rating, comment });
    return [{ insertId: seq.reviews }];
  }

  // ---- SELECT needs by id
  m = sql.match(/^SELECT \* FROM needs WHERE id = \?$/);
  if (m) {
    const needIdParam = next();
    return [db.needs.filter((x) => String(x.id) === String(needIdParam)).map(clone)];
  }

  // ---- UPDATE needs accept
  m = sql.match(/^UPDATE needs SET status = 'accepted', volunteer_id = \? WHERE id = \?$/);
  if (m) {
    const volunteerId = next(); const id = next();
    const n = db.needs.find((x) => String(x.id) === String(id));
    n.status = 'accepted';
    n.volunteer_id = volunteerId;
    return [{ affectedRows: 1 }];
  }

  // ---- INSERT order
  m = sql.match(/^INSERT INTO orders \(need_id, user_id, volunteer_id, status\) VALUES \(\?, \?, \?, 'in_progress'\)$/);
  if (m) {
    const need_id = next(); const user_id = next(); const volunteer_id = next();
    const order = { id: ++seq.orders, need_id, user_id, volunteer_id, status: 'in_progress', service_hours: 0, reject_reason: null, created_at: new Date() };
    db.orders.push(order);
    return [{ insertId: order.id }];
  }

  // ---- user profile lookup
  m = sql.match(/^SELECT id, phone, name, role.*FROM users WHERE id = \?$/);
  if (m) {
    const userIdParam = next();
    return [db.users.filter((x) => String(x.id) === String(userIdParam)).map(clone)];
  }

  throw new Error('Unhandled SQL in mock: ' + sql);
}

function clone(o) {
  return { ...o };
}

// Patch require('mysql2/promise') and ('../../db')
const origLoad = Module._load;
Module._load = function patched(request, parent, isMain) {
  if (request === 'mysql2/promise') {
    return { createPool: () => mockPool };
  }
  if (request.endsWith('/db') || request.endsWith('/db.js')) {
    return mockPool;
  }
  return origLoad.apply(this, arguments);
};

// ---------- test harness ----------
const assert = require('assert');
const http = require('http');

process.env.JWT_SECRET = 'test-secret';
const { createApp } = require('./src/app');

const server = http.createServer(createApp());

let pass = 0;
const ok = (name) => { pass += 1; console.log(`  ✓ ${name}`); };
const fail = (name) => { console.error(`  ✗ ${name}`); process.exitCode = 1; };

const token = (userId) => jwt.sign({ id: userId }, process.env.JWT_SECRET, { expiresIn: '1h' });

function call(method, urlPath, userId, body) {
  const data = body ? JSON.stringify(body) : null;
  return new Promise((resolve) => {
    const req = http.request({
      hostname: '127.0.0.1', port: server.address().port,
      path: '/api' + urlPath, method,
      headers: {
        'Content-Type': 'application/json',
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        ...(userId ? { Authorization: `Bearer ${token(userId)}` } : {}),
      },
    }, (res) => {
      let raw = '';
      res.on('data', (c) => { raw += c; });
      res.on('end', () => resolve({ status: res.statusCode, body: raw ? JSON.parse(raw) : {} }));
    });
    if (data) req.write(data);
    req.end();
  });
}

const expectStatus = (res, expected, name) => {
  try { assert.strictEqual(res.status, expected); ok(name); }
  catch (e) { fail(`${name} -> expected ${expected}, got ${res.status} ${JSON.stringify(res.body)}`); }
};

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));

  // Create order via accept flow
  db.needs.push({ id: 1, user_id: R1, title: 'need', type: 'shopping', status: 'pending' });
  let res = await call('POST', '/needs/1/accept', V1);
  expectStatus(res, 200, 'volunteer accepts need');
  const orderId = db.orders[0].id;

  // outsider submit fails
  res = await call('POST', `/orders/${orderId}/submit`, V2, { service_hours: 2 });
  expectStatus(res, 403, 'outsider volunteer submit -> 403');
  res = await call('POST', `/orders/${orderId}/submit`, R1, { service_hours: 2 });
  expectStatus(res, 403, 'resident submit -> 403');

  // invalid hours
  res = await call('POST', `/orders/${orderId}/submit`, V1, { service_hours: 0 });
  expectStatus(res, 400, 'zero hours -> 400');
  res = await call('POST', `/orders/${orderId}/submit`, V1, { service_hours: -3 });
  expectStatus(res, 400, 'negative hours -> 400');
  res = await call('POST', `/orders/${orderId}/submit`, V1, {});
  expectStatus(res, 400, 'missing hours -> 400');

  // valid submit: no settlement yet
  const before = db.users.find((u) => u.id === V1);
  const pointsBefore = before.points; const hoursBefore = Number(before.service_hours);
  res = await call('POST', `/orders/${orderId}/submit`, V1, { service_hours: 2.5 });
  expectStatus(res, 200, 'volunteer submits 2.5h');
  assert.strictEqual(db.orders[0].status, 'submitted');
  const v1mid = db.users.find((u) => u.id === V1);
  assert.strictEqual(v1mid.points, pointsBefore, 'points unchanged after submit');
  assert.strictEqual(Number(v1mid.service_hours), hoursBefore, 'hours unchanged after submit');
  ok('no credit before resident confirms');

  // duplicate submit
  res = await call('POST', `/orders/${orderId}/submit`, V1, { service_hours: 1 });
  expectStatus(res, 400, 'duplicate submit -> 400');

  // confirm permissions
  res = await call('POST', `/orders/${orderId}/confirm`, V1);
  expectStatus(res, 403, 'volunteer confirm -> 403');
  res = await call('POST', `/orders/${orderId}/confirm`, R2);
  expectStatus(res, 403, 'outsider resident confirm -> 403');
  // reject needs reason
  res = await call('POST', `/orders/${orderId}/reject`, R1, { reason: '  ' });
  expectStatus(res, 400, 'blank reject reason -> 400');
  res = await call('POST', `/orders/${orderId}/reject`, R2, { reason: 'x' });
  expectStatus(res, 403, 'outsider reject -> 403');

  // reject: order continues
  res = await call('POST', `/orders/${orderId}/reject`, R1, { reason: '药还没送到' });
  expectStatus(res, 200, 'resident rejects with reason');
  assert.strictEqual(db.orders[0].status, 'in_progress');
  assert.strictEqual(db.orders[0].reject_reason, '药还没送到');
  ok('order back to in_progress with reason');

  // resubmit clears reason, confirm settles
  res = await call('POST', `/orders/${orderId}/submit`, V1, { service_hours: 3 });
  expectStatus(res, 200, 'volunteer resubmits 3h');
  assert.strictEqual(db.orders[0].reject_reason, null, 'reject reason cleared on resubmit');

  res = await call('POST', `/orders/${orderId}/confirm`, R1);
  expectStatus(res, 200, 'resident confirms');
  assert.strictEqual(res.body.points, 30, 'response reports 30 points');
  const after = db.users.find((u) => u.id === V1);
  assert.strictEqual(after.points, pointsBefore + 30, 'points credited after confirm only');
  assert.strictEqual(Number(after.service_hours), hoursBefore + 3, 'hours credited after confirm only');
  assert.strictEqual(db.orders[0].status, 'completed');
  assert.strictEqual(db.needs.find((n) => n.id === 1).status, 'completed');
  ok('credit happens exactly at resident confirmation');

  // post-settlement actions
  res = await call('POST', `/orders/${orderId}/submit`, V1, { service_hours: 1 });
  expectStatus(res, 400, 'submit after settlement -> 400');
  res = await call('POST', `/orders/${orderId}/confirm`, R1);
  expectStatus(res, 400, 'double confirm -> 400');
  res = await call('POST', `/orders/${orderId}/reject`, R1, { reason: 'x' });
  expectStatus(res, 400, 'reject after settlement -> 400');

  // reviews
  res = await call('POST', `/orders/${orderId}/review`, R2, { rating: 5, comment: 'out' });
  expectStatus(res, 403, 'outsider review -> 403');
  res = await call('POST', `/orders/${orderId}/review`, V2, { rating: 5, comment: 'out' });
  expectStatus(res, 403, 'outsider volunteer review -> 403');
  res = await call('POST', `/orders/${orderId}/review`, R1, { rating: 6 });
  expectStatus(res, 400, 'invalid rating -> 400');
  res = await call('POST', `/orders/${orderId}/review`, R1, { rating: 5, comment: 'good' });
  expectStatus(res, 200, 'resident reviews once');
  res = await call('POST', `/orders/${orderId}/review`, R1, { rating: 4, comment: 'again' });
  expectStatus(res, 409, 'resident duplicate review -> 409');
  res = await call('POST', `/orders/${orderId}/review`, V1, { rating: 5, comment: 'nice resident' });
  expectStatus(res, 200, 'volunteer reviews once');
  res = await call('POST', `/orders/${orderId}/review`, V1, { rating: 2, comment: 'again' });
  expectStatus(res, 409, 'volunteer duplicate review -> 409');
  assert.strictEqual(db.reviews.length, 2, 'exactly two reviews stored');

  // list returns my_review_count
  res = await call('GET', '/orders', R1);
  const listed = res.body.orders.find((o) => o.id === orderId);
  assert.strictEqual(listed.my_review_count, 1, 'my_review_count = 1 for resident');
  ok('orders list reports my review count');

  // unsettled order cannot be reviewed
  db.needs.push({ id: 2, user_id: R1, title: 'n2', type: 'accompany', status: 'pending' });
  await call('POST', '/needs/2/accept', V1);
  const order2 = db.orders[1].id;
  res = await call('POST', `/orders/${order2}/review`, R1, { rating: 5 });
  expectStatus(res, 400, 'review before settlement -> 400');

  // non-existent order
  res = await call('POST', '/orders/9999/confirm', R1);
  expectStatus(res, 404, 'missing order -> 404');

  server.close();
  console.log(`\n${process.exitCode ? 'FAILURES' : 'ALL'} — ${pass} assertions passed`);
})();
