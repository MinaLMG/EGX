const express = require('express');
const router = express.Router();
const { getStocks, createStock, searchArabicStock, matchArabicStock } = require('../controllers/stockController');

router.get('/', getStocks);
router.post('/', createStock);
router.get('/search-arabic', searchArabicStock);
router.patch('/:ticker/match-arabic', matchArabicStock);

module.exports = router;
