const express = require('express');
const router = express.Router();
const cronController = require('../controllers/cronController');

// Trigger Endpoints (Hybrid Model)

// 1. Live Prices (Mubasher - 5 Hour Loop)
router.get('/trigger-mubasher-prices', cronController.triggerMubasherPrices);

// 2. Fair Values (ArabicStock - Daily Scrape)
router.get('/trigger-arabicstock-values', cronController.triggerArabicStockValues);

module.exports = router;
