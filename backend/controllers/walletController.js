const walletService = require('../services/walletService');
const Wallet = require('../models/Wallet');
const Stock = require('../models/Stock');

// Helper to calculate wallet metrics (used by user and admin)
const _calcWalletInternal = async (userId) => {
    return await walletService.calculateWalletMetrics(userId);
};

// @desc    Get user wallet with rebalancing metrics
// @route   GET /api/wallet
exports.getWallet = async (req, res) => {
    try {
        const data = await _calcWalletInternal(req.user._id);
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Get wallet for a specific user (Admin only)
// @route   GET /api/wallet/admin/:userId
exports.getWalletForUser = async (req, res) => {
    try {
        const data = await _calcWalletInternal(req.params.userId);
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Add or update item in wallet
// @route   POST /api/wallet/items
exports.updateWalletItem = async (req, res) => {
    try {
        const { ticker, quantity, manualPrice, userId } = req.body;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;
        const stock = await Stock.findOne({ ticker: ticker.toUpperCase() });
        if (!stock) return res.status(404).json({ message: 'Stock not found' });

        let wallet = await Wallet.findOne({ user: targetId });
        if (!wallet) {
            wallet = new Wallet({ user: targetId, items: [] });
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
        const { cash, factor, mode, manualTotalOverride, profitMode, manualProfitValue, activePointOnTimeId, liquidityFactor, rebalancingThreshold, userId } = req.body;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const update = {};
        if (cash !== undefined) update.cash = cash;
        if (factor !== undefined) update.factor = factor;
        if (mode !== undefined) update.mode = mode;
        if (manualTotalOverride !== undefined) update.manualTotalOverride = manualTotalOverride;
        if (profitMode !== undefined) update.profitMode = profitMode;
        if (manualProfitValue !== undefined) update.manualProfitValue = manualProfitValue;
        if (liquidityFactor !== undefined) update.liquidityFactor = liquidityFactor;
        if (rebalancingThreshold !== undefined) update.rebalancingThreshold = rebalancingThreshold;

        // Handle snapshot activation/deactivation
        if (activePointOnTimeId !== undefined) {
            update.activePointOnTimeId = activePointOnTimeId || null;
        }

        const wallet = await Wallet.findOneAndUpdate(
            { user: targetId },
            update,
            { returnDocument: 'after', upsert: true }
        ).populate('items.stock');
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Add a transaction (deposit/withdrawal)
// @route   POST /api/wallet/transactions
exports.addTransaction = async (req, res) => {
    try {
        const { date, value, type, userId } = req.body;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;
        const wallet = await Wallet.findOne({ user: targetId });
        if (!wallet) return res.status(404).json({ message: 'Wallet not found. Add a stock first to create one.' });
        wallet.transactions.push({ date, value, type });
        await wallet.save();
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Update a transaction
// @route   PUT /api/wallet/transactions/:id
exports.updateTransaction = async (req, res) => {
    try {
        const { date, value, type, userId } = req.body;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const wallet = await Wallet.findOne({ user: targetId });
        const transaction = wallet.transactions.id(req.params.id);
        if (!transaction) return res.status(404).json({ message: 'Transaction not found' });

        transaction.date = date;
        transaction.value = value;
        transaction.type = type;

        await wallet.save();
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Delete a transaction
// @route   DELETE /api/wallet/transactions/:id
exports.deleteTransaction = async (req, res) => {
    try {
        const { userId } = req.query;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const wallet = await Wallet.findOne({ user: targetId });
        wallet.transactions.pull(req.params.id);
        await wallet.save();
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Add a point-on-time balance snapshot
// @route   POST /api/wallet/points
exports.addPointOnTime = async (req, res) => {
    try {
        const { date, balance, bankRatio, userId } = req.body;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const snapshotDate = new Date(date);
        if (snapshotDate > new Date()) {
            return res.status(400).json({ message: 'Snapshot date cannot be in the future.' });
        }

        const wallet = await Wallet.findOne({ user: targetId });
        if (!wallet) return res.status(404).json({ message: 'Wallet not found' });

        wallet.pointsOnTime.push({ date: snapshotDate, balance, bankRatio: bankRatio || 0 });
        await wallet.save();
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Update a point-on-time snapshot
// @route   PUT /api/wallet/points/:id
exports.updatePointOnTime = async (req, res) => {
    try {
        const { date, balance, bankRatio, userId } = req.body;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const snapshotDate = new Date(date);
        if (snapshotDate > new Date()) {
            return res.status(400).json({ message: 'Snapshot date cannot be in the future.' });
        }

        const wallet = await Wallet.findOne({ user: targetId });
        if (!wallet) return res.status(404).json({ message: 'Wallet not found' });

        const point = wallet.pointsOnTime.id(req.params.id);
        if (!point) return res.status(404).json({ message: 'Snapshot not found' });

        point.date = snapshotDate;
        point.balance = balance;
        if (bankRatio !== undefined) point.bankRatio = bankRatio;
        await wallet.save();
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Delete a point-on-time snapshot
// @route   DELETE /api/wallet/points/:id
exports.deletePointOnTime = async (req, res) => {
    try {
        const { userId } = req.query;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const wallet = await Wallet.findOne({ user: targetId });
        if (!wallet) return res.status(404).json({ message: 'Wallet not found' });

        // If the deleted snapshot is currently active, clear the reference
        if (wallet.activePointOnTimeId &&
            wallet.activePointOnTimeId.toString() === req.params.id) {
            wallet.activePointOnTimeId = null;
        }

        wallet.pointsOnTime.pull(req.params.id);
        await wallet.save();
        res.json(wallet);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
// @desc    Update manual prices in bulk
// @route   PUT /api/wallet/manual-prices
exports.updateManualPricesBulk = async (req, res) => {
    try {
        const { prices, userId } = req.body; // prices is { ticker: price }
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const wallet = await Wallet.findOne({ user: targetId }).populate('items.stock');
        if (!wallet) return res.status(404).json({ message: 'Wallet not found' });

        if (prices && typeof prices === 'object') {
            Object.keys(prices).forEach(ticker => {
                const item = wallet.items.find(i => i.stock.ticker === ticker);
                if (item) {
                    item.manualPrice = prices[ticker];
                }
            });
            await wallet.save();
        }

        const data = await _calcWalletInternal(targetId);
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
