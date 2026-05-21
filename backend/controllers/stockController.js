const Stock = require('../models/Stock');
const redis = require('../config/redis');
const fairValueService = require('../services/fairValueService');

// @desc    Get all stocks (with caching)
// @route   GET /api/stocks
exports.getStocks = async (req, res) => {
    try {
        const cachedStocks = await redis.get('all_stocks');
        if (cachedStocks) {
            return res.json(JSON.parse(cachedStocks));
        }

        const stocks = await Stock.find();
        await redis.setex('all_stocks', 3600, JSON.stringify(stocks)); // Cache for 1 hour

        res.json(stocks);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

