const express = require('express');
const router = express.Router();
const recommendationController = require('../controllers/recommendationController');

// BF UPDATE
router.post('/bf-update', recommendationController.updateBfPrices);

// GET ALL
router.get('/', recommendationController.getRecommendations);

// FUNDAMENTAL
router.post('/fundamental', recommendationController.updateFundamental);
router.delete('/fundamental/:id', recommendationController.deleteFundamental);

// TECHNICAL
router.post('/technical', recommendationController.updateTechnical);
router.put('/technical/:id', recommendationController.updateTechnicalById);
router.delete('/technical/:id', recommendationController.deleteTechnical);

// RFP
router.post('/rfp', recommendationController.updateRFP);

// RSP
router.post('/rsp', recommendationController.updateRSP);

// SCORING
router.post('/recalculate-scores', recommendationController.recalculateScores);

module.exports = router;
