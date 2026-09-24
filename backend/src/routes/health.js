const { Router } = require('express');
const messages = require('../constants/messages');

const router = Router();

router.get('/health', (req, res) => {
  res.json({ status: 'ok', message: messages.health });
});

module.exports = router;
