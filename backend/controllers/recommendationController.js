const BFValue = require('../models/BFValue');
const RFPRecommendation = require('../models/RFPRecommendation');
const RSPRecommendation = require('../models/RSPRecommendation');
const FundamentalRecommendation = require('../models/FundamentalRecommendation');
const TechnicalRecommendation = require('../models/TechnicalRecommendation');
const Stock = require('../models/Stock');

// BF UPDATE: Clear all and insert new ones
exports.updateBfPrices = async (req, res) => {
    try {
        const { bfValues } = req.body; // Array of { ticker, value }
        
        // 1. Clear existing
        await BFValue.deleteMany({});
        
        // 2. Resolve tickers to stock IDs
        const updates = [];
        for (const item of bfValues) {
            const stock = await Stock.findOne({ ticker: item.ticker.toUpperCase() });
            if (stock) {
                updates.push({
                    stock: stock._id,
                    value: item.value
                });
            }
        }
        
        // 3. Bulk insert
        if (updates.length > 0) {
            await BFValue.insertMany(updates);
        }
        
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
            { upsert: true, new: true }
        ).populate('stock');
        
        res.json(recommendation);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.deleteFundamental = async (req, res) => {
    try {
        await FundamentalRecommendation.findByIdAndDelete(req.params.id);
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
        
        const recommendation = await TechnicalRecommendation.findOneAndUpdate(
            { stock: stock._id },
            { target, notes },
            { upsert: true, new: true }
        ).populate('stock');
        
        res.json(recommendation);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.deleteTechnical = async (req, res) => {
    try {
        await TechnicalRecommendation.findByIdAndDelete(req.params.id);
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
        
        const updates = [];
        for (const item of stocks) {
            const stock = await Stock.findOne({ ticker: item.ticker.toUpperCase() });
            if (stock) {
                updates.push({
                    stock: stock._id,
                    score: item.score || 1
                });
            }
        }
        
        if (updates.length > 0) {
            await RFPRecommendation.insertMany(updates);
        }
        
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
        
        const updates = [];
        for (const item of stocks) {
            const stock = await Stock.findOne({ ticker: item.ticker.toUpperCase() });
            if (stock) {
                updates.push({
                    stock: stock._id,
                    score: item.score
                });
            }
        }
        
        if (updates.length > 0) {
            await RSPRecommendation.insertMany(updates);
        }
        
        const result = await RSPRecommendation.find().populate('stock');
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
