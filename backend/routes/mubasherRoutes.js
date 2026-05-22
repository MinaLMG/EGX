const express = require('express');
const router = express.Router();
const mubasherController = require('../controllers/mubasherController');

router.get('/unmatched', mubasherController.getUnmatched);
router.post('/match', mubasherController.createMatch);
router.post('/trigger', mubasherController.triggerScrape);

module.exports = router;
