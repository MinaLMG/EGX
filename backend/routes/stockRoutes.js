const express = require('express');
const router = express.Router();
const { getStocks, getStockById, } = require('../controllers/stockController');

router.get('/', getStocks);
router.get('/:ticker', getStockById);

module.exports = router;
