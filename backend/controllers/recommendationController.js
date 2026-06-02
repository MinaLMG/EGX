const BFValue = require('../models/BFValue');
const RFPRecommendation = require('../models/RFPRecommendation');
const RSPRecommendation = require('../models/RSPRecommendation');
const FundamentalRecommendation = require('../models/FundamentalRecommendation');
const TechnicalRecommendation = require('../models/TechnicalRecommendation');
const Stock = require('../models/Stock');
const ScoringService = require('../services/scoringService');

exports.recalculateScores = async (req, res) => {
    try {
        const result = await ScoringService.calculateAllScores(req.body?.weights);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// BF UPDATE: Clear all and insert new ones
exports.updateBfPrices = async (req, res) => {
    try {
        const { bfValues } = req.body; // Array of { ticker, value }

        // 1. Clear existing
        await BFValue.deleteMany({});

        // 2. Resolve tickers to stock IDs (Bulk approach)
        const tickers = bfValues.map(v => v.ticker.toUpperCase());
        const stocks = await Stock.find({ ticker: { $in: tickers } });
        const stockMap = new Map(stocks.map(s => [s.ticker.toUpperCase(), s._id]));

        const updates = [];
        for (const item of bfValues) {
            const stockId = stockMap.get(item.ticker.toUpperCase());
            if (stockId) {
                updates.push({
                    stock: stockId,
                    value: item.value
                });
            }
        }
        // 3. Bulk insert
        if (updates.length > 0) {
            await BFValue.insertMany(updates);
        }

        // 4. Recalculate scores
        await ScoringService.calculateAllScores();

        res.json({ message: `Successfully updated ${updates.length} BF values.` });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// GET ALL RECOMMENDATIONS
exports.getRecommendations = async (req, res) => {
    try {
        const bfValues = await BFValue.find().populate('stock');
        const rfp = await RFPRecommendation.find().populate('stock');
        const rsp = await RSPRecommendation.find().populate('stock');
        const fundamental = await FundamentalRecommendation.find().populate('stock');
        const technical = await TechnicalRecommendation.find().populate('stock');

        res.json({
            bfValues,
            rfp,
            rsp,
            fundamental,
            technical
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// FUNDAMENTAL CRUD
exports.updateFundamental = async (req, res) => {
    try {
        const { ticker, target } = req.body;
        const stock = await Stock.findOne({ ticker: ticker.toUpperCase() });
        if (!stock) return res.status(404).json({ message: 'Stock not found' });

        const recommendation = await FundamentalRecommendation.findOneAndUpdate(
            { stock: stock._id },
            { target },
            { upsert: true, returnDocument: 'after' }
        ).populate('stock');

        // Recalculate scores
        await ScoringService.calculateAllScores();

        res.json(recommendation);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.deleteFundamental = async (req, res) => {
    try {
        await FundamentalRecommendation.findByIdAndDelete(req.params.id);

        // Recalculate scores
        await ScoringService.calculateAllScores();

        res.json({ message: 'Deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// TECHNICAL CRUD
exports.updateTechnical = async (req, res) => {
    try {
        const { ticker, target, notes } = req.body;
        const stock = await Stock.findOne({ ticker: ticker.toUpperCase() });
        if (!stock) return res.status(404).json({ message: 'Stock not found' });

        const recommendation = new TechnicalRecommendation({
            stock: stock._id,
            target,
            notes
        });
        await recommendation.save();
        const populatedRec = await TechnicalRecommendation.findById(recommendation._id).populate('stock');

        // Recalculate scores
        await ScoringService.calculateAllScores();

        res.json(populatedRec);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.updateTechnicalById = async (req, res) => {
    try {
        const { target, notes } = req.body;
        const recommendation = await TechnicalRecommendation.findByIdAndUpdate(
            req.params.id,
            { target, notes },
            { returnDocument: 'after' }
        ).populate('stock');

        // Recalculate scores
        await ScoringService.calculateAllScores();

        res.json(recommendation);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.deleteTechnical = async (req, res) => {
    try {
        await TechnicalRecommendation.findByIdAndDelete(req.params.id);

        // Recalculate scores
        await ScoringService.calculateAllScores();

        res.json({ message: 'Deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// RFP CRUD (List management)
exports.updateRFP = async (req, res) => {
    try {
        const { stocks } = req.body; // Array of { ticker, score }
        // For RFP, user said internal score is always 1, but we'll accept what's passed or default to 1

        await RFPRecommendation.deleteMany({});

        const tickers = stocks.map(s => s.ticker.toUpperCase());
        const stockList = await Stock.find({ ticker: { $in: tickers } });
        const stockMap = new Map(stockList.map(s => [s.ticker.toUpperCase(), s._id]));

        const updates = [];
        for (const item of stocks) {
            const stockId = stockMap.get(item.ticker.toUpperCase());
            if (stockId) {
                updates.push({
                    stock: stockId,
                    score: item.score || 1
                });
            }
        }

        if (updates.length > 0) {
            await RFPRecommendation.insertMany(updates);
        }

        // Recalculate scores
        await ScoringService.calculateAllScores();

        const result = await RFPRecommendation.find().populate('stock');
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// RSP CRUD (List management)
exports.updateRSP = async (req, res) => {
    try {
        const { stocks } = req.body; // Array of { ticker, score }

        await RSPRecommendation.deleteMany({});

        const tickers = stocks.map(s => s.ticker.toUpperCase());
        const stockList = await Stock.find({ ticker: { $in: tickers } });
        const stockMap = new Map(stockList.map(s => [s.ticker.toUpperCase(), s._id]));

        const updates = [];
        for (const item of stocks) {
            const stockId = stockMap.get(item.ticker.toUpperCase());
            if (stockId) {
                updates.push({
                    stock: stockId,
                    score: item.score
                });
            }
        }

        if (updates.length > 0) {
            await RSPRecommendation.insertMany(updates);
        }

        // Recalculate scores
        await ScoringService.calculateAllScores();

        const result = await RSPRecommendation.find().populate('stock');
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
