const express = require('express');
const router = express.Router();
const { getStocks, createStock } = require('../controllers/stockController');

router.get('/', getStocks);
router.post('/', createStock);

module.exports = router;
