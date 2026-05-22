const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/auth');
const { getStocks, createStock, searchArabicStock, matchArabicStock } = require('../controllers/stockController');

router.get('/', getStocks);
router.post('/', protect, authorize('admin'), createStock);
router.get('/search-arabic', protect, authorize('admin'), searchArabicStock);
router.patch('/:ticker/match-arabic', protect, authorize('admin'), matchArabicStock);

module.exports = router;
