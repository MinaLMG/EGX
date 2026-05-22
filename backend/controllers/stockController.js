const Stock = require('../models/Stock');
const fairValueService = require('../services/fairValueService');
const arabicStockService = require('../services/arabicStockService');

// @desc    Get all stocks
// @route   GET /api/stocks
exports.getStocks = async (req, res) => {
    console.log('getStocks called');
    try {
        const stocks = await Stock.find();
        res.json(stocks);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Search for stock on ArabicStock.com
// @route   GET /api/stocks/search-arabic
exports.searchArabicStock = async (req, res) => {
    try {
        const { q } = req.query;
        if (!q) return res.status(400).json({ message: 'Query is required' });

        const results = await arabicStockService.search(q);
        res.json(results);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Match a stock with an ArabicStock.com URL
// @route   PATCH /api/stocks/:ticker/match-arabic
exports.matchArabicStock = async (req, res) => {
    try {
        const { ticker } = req.params;
        const { url } = req.body;

        if (!url) return res.status(400).json({ message: 'URL is required' });

        const stock = await Stock.findOneAndUpdate(
            { ticker: ticker.toUpperCase() },
            { arabic_stock_getter: url },
            { new: true }
        );

        if (!stock) return res.status(404).json({ message: 'Stock not found' });

        res.json(stock);
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
