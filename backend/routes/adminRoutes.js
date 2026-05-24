const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/auth');
const { getSettings, updateSetting, getScraperLogs } = require('../controllers/adminController');

router.use(protect);
router.use(authorize('admin'));

router.get('/settings', getSettings);
router.post('/settings', updateSetting);
router.get('/scraper-logs', getScraperLogs);
router.post('/trigger-mubasher-trade', require('../controllers/adminController').triggerMubasherTrade);

module.exports = router;
