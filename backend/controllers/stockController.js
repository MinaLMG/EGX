const Stock = require('../models/Stock');
const fairValueService = require('../services/fairValueService');

// @desc    Get all stocks
// @route   GET /api/stocks
exports.getStocks = async (req, res) => {
    try {
        const stocks = await Stock.find();
        res.json(stocks);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Create a new stock
// @route   POST /api/stocks
exports.createStock = async (req, res) => {
    try {
        const { ticker, name, price } = req.body;

        let stock = await Stock.findOne({ ticker: ticker.toUpperCase() });
        if (stock) {
            return res.status(400).json({ message: 'Stock already exists' });
        }

        stock = await Stock.create({
            ticker: ticker.toUpperCase(),
            name,
            price: price || 0
        });

        res.status(201).json(stock);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};
