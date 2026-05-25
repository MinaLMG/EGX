const express = require('express');
const router = express.Router();
const cronController = require('../controllers/cronController');

// Secure sync endpoint for Vercel Cron
router.get('/sync', cronController.syncAll);

module.exports = router;
