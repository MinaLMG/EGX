const express = require('express');
const router = express.Router();
const cronController = require('../controllers/cronController');

// Granular Sync Endpoints
router.get('/prices', cronController.syncPrices);
router.get('/fair-values', cronController.syncFairValues);

// NEW: Trigger GitHub Scraper (The "Hybrid" Solution)
router.get('/trigger-scraper', cronController.triggerGitHubScraper);

// Combined Sync (Maintenance)
router.get('/sync', cronController.syncAll);

module.exports = router;
