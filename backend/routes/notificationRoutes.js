const express = require('express');
const router = express.Router();
const { getMyNotifications, getUnreadCount } = require('../controllers/notificationController');
const { protect } = require('../middleware/auth');

router.get('/', protect, getMyNotifications);
router.get('/unread-count', protect, getUnreadCount);

module.exports = router;
