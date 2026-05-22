const Wallet = require('../models/Wallet');
const Stock = require('../models/Stock');

// @desc    Get user wallet with rebalancing metrics
// @route   GET /api/wallet
exports.getWallet = async (req, res) => {
    try {
        let wallet = await Wallet.findOne({ user: req.user._id }).populate('items.stock');
        
        if (!wallet) {
            wallet = await Wallet.create({ user: req.user._id, items: [] });
        }

        const count = wallet.items.length;
        if (count === 0) {
            return res.json({ wallet, items: [], analysis: null });
        }

        // 1. Calculate Total Value
        let totalVal = wallet.cash;
        wallet.items.forEach(item => {
            const price = (wallet.mode === 'manual' && item.manualPrice) 
                ? item.manualPrice 
                : (item.stock.price || 0);
            totalVal += (item.quantity * price);
        });

        // Use manual override if exists and in manual mode
        if (wallet.mode === 'manual' && wallet.manualTotalOverride) {
            totalVal = wallet.manualTotalOverride;
        }

        // 2. Sort items by Score (total_score desc) then alphabetical
        const sortedItems = [...wallet.items].sort((a, b) => {
            const scoreA = a.stock.total_score || 0;
            const scoreB = b.stock.total_score || 0;
            if (scoreB !== scoreA) return scoreB - scoreA;
            return a.stock.ticker.localeCompare(b.stock.ticker);
        });

        // 3. Rebalancing Constants
        const factor = wallet.factor;
        const alpha = (count - 1) / 2;
        let diffValue = 0;
        if (count > 1) {
            diffValue = totalVal * (1 - factor) / count / (alpha + factor * alpha);
        }

        // 4. Calculate Supposed Values and Suggestions
        const analysis = [];
        let previousSupposed = null;

        for (let i = 0; i < sortedItems.length; i++) {
            const item = sortedItems[i];
            const currentPrice = (wallet.mode === 'manual' && item.manualPrice) 
                ? item.manualPrice 
                : (item.stock.price || 0);
            
            const realMarketValue = item.quantity * currentPrice;
            
            let supposedValue;
            if (i === 0) {
                supposedValue = (totalVal / count) + ((count - 1) / 2 * diffValue);
            } else {
                supposedValue = previousSupposed - diffValue;
            }
            previousSupposed = supposedValue;

            // Suggestion logic
            const gap = supposedValue - realMarketValue;
            let suggestion = 'Hold';
            
            // Check if deviation >= 10%
            if (realMarketValue > 0) {
                const deviation = Math.abs(gap) / realMarketValue;
                if (deviation >= 0.10) {
                    suggestion = gap > 0 ? 'Buy' : 'Sell';
                }
            } else if (gap > 0) {
                suggestion = 'Buy'; // If we have 0 quantity but should have value
            }

            analysis.push({
                ticker: item.stock.ticker,
                name: item.stock.name,
                quantity: item.quantity,
                currentPrice,
                realMarketValue,
                supposedValue,
                gap,
                suggestion
            });
        }

        res.json({
            wallet,
            totalValue: totalVal,
            diffValue,
            analysis
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Add or update item in wallet
// @route   POST /api/wallet/items
exports.updateWalletItem = async (req, res) => {
    try {
        const { ticker, quantity, manualPrice } = req.body;
        const stock = await Stock.findOne({ ticker: ticker.toUpperCase() });
        if (!stock) return res.status(404).json({ message: 'Stock not found' });

        let wallet = await Wallet.findOne({ user: req.user._id });
        if (!wallet) {
            wallet = new Wallet({ user: req.user._id, items: [] });
        }

        const itemIndex = wallet.items.findIndex(item => item.stock.toString() === stock._id.toString());

        if (itemIndex > -1) {
            if (quantity === 0) {
                wallet.items.splice(itemIndex, 1);
            } else {
                wallet.items[itemIndex].quantity = quantity;
                if (manualPrice !== undefined) wallet.items[itemIndex].manualPrice = manualPrice;
            }
        } else if (quantity > 0) {
            wallet.items.push({ 
                stock: stock._id, 
                quantity, 
                manualPrice 
            });
        }

        await wallet.save();
        await wallet.populate('items.stock');
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Update wallet settings (cash, factor, mode)
// @route   PATCH /api/wallet
exports.updateWalletSettings = async (req, res) => {
    try {
        const { cash, factor, mode, manualTotalOverride } = req.body;
        const wallet = await Wallet.findOneAndUpdate(
            { user: req.user._id },
            { cash, factor, mode, manualTotalOverride },
            { new: true, upsert: true }
        ).populate('items.stock');
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
