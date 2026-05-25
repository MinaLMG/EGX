const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/auth');
const { getStocks, createStock, searchArabicStock, matchArabicStock, getStocksMatrix, getStocksExcel } = require('../controllers/stockController');

router.get('/', protect, getStocks);
router.get('/admin/matrix', protect, authorize('admin'), getStocksMatrix);
router.get('/admin/export-excel', protect, authorize('admin'), getStocksExcel);
router.post('/', protect, authorize('admin'), createStock);
router.get('/search-arabic', protect, authorize('admin'), searchArabicStock);
router.patch('/:ticker/match-arabic', protect, authorize('admin'), matchArabicStock);

module.exports = router;
