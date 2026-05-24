const MubasherUnmatched = require('../models/MubasherUnmatched');
const MubasherMatch = require('../models/MubasherMatch');
const mubasherPriceService = require('../services/mubasherPriceService');

exports.getUnmatched = async (req, res) => {
    try {
        const unmatched = await MubasherUnmatched.find();
        res.json({
            stocks: unmatched.filter(u => u.type === 'stock').map(u => u.identifier),
            prices: unmatched.filter(u => u.type === 'mubasher_price').map(u => u.identifier)
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.createMatch = async (req, res) => {
    try {
        const { ticker, mubasherName } = req.body;

        // 1. Create the permanent match
        // Use name as the unique key because one Mubasher name should map to one ticker,
        // but one ticker can be associated with multiple Mubasher names (e.g. GDRs).
        const match = await MubasherMatch.findOneAndUpdate(
            { name: mubasherName },
            { ticker: ticker.toUpperCase() },
            { upsert: true, returnDocument: 'after' }
        );

        // 2. Clear from unmatched (optional but cleaner)
        await MubasherUnmatched.deleteMany({
            $or: [
                { identifier: ticker.toUpperCase(), type: 'stock' },
                { identifier: mubasherName, type: 'mubasher_price' }
            ]
        });

        // 3. Trigger a background update to apply this match immediately
        // We don't await this as it might take time
        mubasherPriceService.updatePricesFromMubasher().catch(console.error);

        res.json({ message: 'Match created successfully', match });
    } catch (error) {
        console.log("error", error);
        res.status(500).json({ error: error.message });
    }
};

exports.triggerScrape = async (req, res) => {
    try {
        await mubasherPriceService.updatePricesFromMubasher();
        const unmatched = await MubasherUnmatched.find();
        res.json({
            message: 'Manual update triggered successfully',
            unmatchedCount: unmatched.length
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
