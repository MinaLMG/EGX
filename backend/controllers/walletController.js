const Wallet = require('../models/Wallet');
const Stock = require('../models/Stock');

// Helper to calculate wallet metrics (used by user and admin)
const _calcWalletInternal = async (userId) => {
    let wallet = await Wallet.findOne({ user: userId }).populate('items.stock');
    if (!wallet) {
        wallet = await Wallet.create({ user: userId, items: [], transactions: [] });
    }

    const itemsCount = wallet.items.length;
    let totalVal = wallet.cash;

    // 1. Calculate Current Portfolio Value
    wallet.items.forEach(item => {
        const price = (wallet.mode === 'manual' && item.manualPrice)
            ? item.manualPrice
            : (item.stock.price || 0);
        totalVal += (item.quantity * price);
    });

    if (wallet.mode === 'manual' && wallet.manualTotalOverride) {
        totalVal = wallet.manualTotalOverride;
    }

    // 2. Rebalancing Analysis
    const sortedItems = [...wallet.items].sort((a, b) => {
        const scoreA = a.stock.total_score || 0;
        const scoreB = b.stock.total_score || 0;
        if (scoreB !== scoreA) return scoreB - scoreA;
        return a.stock.ticker.localeCompare(b.stock.ticker);
    });

    const factor = wallet.factor;
    let diffValue = 0;
    const analysis = [];

    if (itemsCount > 0) {
        const alpha = (itemsCount - 1) / 2;
        if (itemsCount > 1) {
            diffValue = totalVal * (1 - factor) / itemsCount / (alpha + factor * alpha);
        }

        let previousSupposed = null;
        for (let i = 0; i < sortedItems.length; i++) {
            const item = sortedItems[i];
            const currentPrice = (wallet.mode === 'manual' && item.manualPrice)
                ? item.manualPrice
                : (item.stock.price || 0);

            const realMarketValue = item.quantity * currentPrice;

            let supposedValue;
            if (i === 0) {
                supposedValue = (totalVal / itemsCount) + ((itemsCount - 1) / 2 * diffValue);
            } else {
                supposedValue = previousSupposed - diffValue;
            }
            previousSupposed = supposedValue;

            const gap = supposedValue - realMarketValue;
            let suggestion = 'Hold';
            if (realMarketValue > 0) {
                const deviation = Math.abs(gap) / realMarketValue;
                if (deviation >= 0.10) suggestion = gap > 0 ? 'Buy' : 'Sell';
            } else if (gap > 0) {
                suggestion = 'Buy';
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
    }

    // 3. Profit Calculator Logic
    const now = new Date();
    let totalEffectiveValue = 0;
    let totalNetInvestment = 0;
    let firstDepositDate = null;

    // Determine if an active snapshot is selected
    const activeSnapshotId = wallet.activePointOnTimeId
        ? wallet.activePointOnTimeId.toString()
        : null;
    let activeSnapshot = null;
    if (activeSnapshotId) {
        activeSnapshot = (wallet.pointsOnTime || []).find(
            p => p._id.toString() === activeSnapshotId && new Date(p.date) <= now
        ) || null;
    }

    if (activeSnapshot) {
        // Snapshot mode: treat snapshot balance as a deposit at snapshot.date,
        // ignore all real transactions on or before that date.
        const snapshotDate = new Date(activeSnapshot.date);
        // End-of-day: include the full snapshot day
        snapshotDate.setHours(23, 59, 59, 999);

        // Synthetic starting deposit
        const syntheticDuration = (now - snapshotDate) / (1000 * 60 * 60 * 24);
        totalEffectiveValue += activeSnapshot.balance * Math.max(0, syntheticDuration);
        totalNetInvestment += activeSnapshot.balance;
        firstDepositDate = snapshotDate;

        // Add transactions AFTER the snapshot date
        (wallet.transactions || []).forEach(t => {
            const tDate = new Date(t.date);
            if (tDate <= snapshotDate) return; // skip transactions up to and including snapshot date
            const val = t.type === 'deposit' ? t.value : -t.value;
            const durationDays = (now - tDate) / (1000 * 60 * 60 * 24);
            totalEffectiveValue += val * Math.max(0, durationDays);
            totalNetInvestment += val;
        });
    } else {
        // Default mode: use all transactions
        (wallet.transactions || []).forEach(t => {
            const val = t.type === 'deposit' ? t.value : -t.value;
            const durationDays = (now - new Date(t.date)) / (1000 * 60 * 60 * 24);

            totalEffectiveValue += val * Math.max(0, durationDays);
            totalNetInvestment += val;

            if (t.type === 'deposit') {
                if (!firstDepositDate || new Date(t.date) < firstDepositDate) {
                    firstDepositDate = new Date(t.date);
                }
            }
        });
    }

    let totalDuration = 0;
    if (firstDepositDate) {
        totalDuration = (now - firstDepositDate) / (1000 * 60 * 60 * 24);
    }

    const walletEffectiveValue = totalDuration > 0 ? (totalEffectiveValue / totalDuration) : 0;

    // Use the separate profit mode/value
    const currentValueForProfit = (wallet.profitMode === 'manual' && wallet.manualProfitValue !== undefined)
        ? wallet.manualProfitValue
        : totalVal;

    const revenue = currentValueForProfit - totalNetInvestment;
    const revenuePercentage = walletEffectiveValue > 0 ? (revenue / walletEffectiveValue) : 0;

    // Daily Ratio & Yearly Revenue
    let dailyRatio = 1;
    let yearlyRevenue = 0;

    if (totalDuration > 0 && (revenuePercentage + 1) > 0) {
        dailyRatio = Math.pow(10, Math.log10(revenuePercentage + 1) / totalDuration);
        yearlyRevenue = Math.pow(dailyRatio, 365) - 1;
    }

    return {
        wallet,
        totalValue: totalVal,
        currentValueForProfit,
        activeSnapshot: activeSnapshot ? { _id: activeSnapshot._id, date: activeSnapshot.date, balance: activeSnapshot.balance } : null,
        diffValue,
        analysis,
        profit: {
            totalNetInvestment,
            walletEffectiveValue,
            revenue,
            revenuePercentage,
            dailyRatio,
            yearlyRevenue,
            totalDuration
        }
    };
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
        const { cash, factor, mode, manualTotalOverride, profitMode, manualProfitValue, activePointOnTimeId } = req.body;
        const update = { cash, factor, mode, manualTotalOverride, profitMode, manualProfitValue };
        // Allow explicitly setting to null to deactivate snapshot
        if (activePointOnTimeId !== undefined) {
            update.activePointOnTimeId = activePointOnTimeId || null;
        }
        const wallet = await Wallet.findOneAndUpdate(
            { user: req.user._id },
            update,
            { new: true, upsert: true }
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
        const { date, balance, userId } = req.body;
        const targetId = (req.user.role === 'admin' && userId) ? userId : req.user._id;

        const snapshotDate = new Date(date);
        if (snapshotDate > new Date()) {
            return res.status(400).json({ message: 'Snapshot date cannot be in the future.' });
        }

        const wallet = await Wallet.findOne({ user: targetId });
        if (!wallet) return res.status(404).json({ message: 'Wallet not found' });

        wallet.pointsOnTime.push({ date: snapshotDate, balance });
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
        const { date, balance, userId } = req.body;
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
