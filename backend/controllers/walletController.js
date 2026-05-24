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

    wallet.items.forEach(item => {
        const price = (wallet.mode === 'manual' && item.manualPrice)
            ? item.manualPrice
            : (item.stock.price || 0);
        totalVal += (item.quantity * price);
    });

    // 2. Rebalancing Analysis
    const sortedItems = [...wallet.items].sort((a, b) => {
        const scoreA = a.stock.total_score || 0;
        const scoreB = b.stock.total_score || 0;
        if (scoreB !== scoreA) return scoreB - scoreA;
        return a.stock.ticker.localeCompare(b.stock.ticker);
    });

    const factor = wallet.factor;
    const liquidityFactor = wallet.liquidityFactor || 0;
    const investableValue = totalVal * (1 - liquidityFactor);

    let diffValue = 0;
    const analysis = [];

    if (itemsCount > 0) {
        const alpha = (itemsCount - 1) / 2;
        if (itemsCount > 1) {
            diffValue = investableValue * (1 - factor) / itemsCount / (alpha + factor * alpha);
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
                supposedValue = (investableValue / itemsCount) + ((itemsCount - 1) / 2 * diffValue);
            } else {
                supposedValue = previousSupposed - diffValue;
            }
            previousSupposed = supposedValue;

            const gap = supposedValue - realMarketValue;
            let suggestion = 'Hold';
            const threshold = wallet.rebalancingThreshold || 0.10;
            if (realMarketValue > 0) {
                const deviation = Math.abs(gap) / realMarketValue;
                if (deviation >= threshold) suggestion = gap > 0 ? 'Buy' : 'Sell';
            } else if (gap > 0) {
                suggestion = 'Buy';
            }

            analysis.push({
                ticker: item.stock.ticker,
                name: item.stock.name,
                quantity: item.quantity,
                rank: i + 1, // Store original score-based rank
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
            p => p._id.toString() === activeSnapshotId
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
        totalDuration = Math.max(0, (now - firstDepositDate) / (1000 * 60 * 60 * 24));
    }

    const walletEffectiveValue = totalDuration > 0 ? (totalEffectiveValue / totalDuration) : 0;

    // Use the separate profit mode/value
    const currentValueForProfit = (wallet.profitMode === 'manual' && wallet.manualProfitValue)
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

    // ── Bank comparison (only when a snapshot with bankRatio is active) ──
    let bankComparison = null;
    if (activeSnapshot && activeSnapshot.bankRatio > 0) {
        const annualRate = activeSnapshot.bankRatio / 100; // e.g. 0.25 for 25%
        const bankDailyRatio = Math.pow(10, Math.log10(annualRate + 1) / 365);
        const snapshotDate = new Date(activeSnapshot.date);
        snapshotDate.setHours(23, 59, 59, 999);
        // Revenue the bank would have generated on the snapshot balance
        const snapDuration = Math.ceil((now - snapshotDate) / (1000 * 60 * 60 * 24));
        let bankSupposedRevenue = activeSnapshot.balance * (Math.pow(bankDailyRatio, Math.max(0, snapDuration)) - 1);
        // Revenue the bank would have generated on each post-snapshot transaction
        (wallet.transactions || []).forEach(t => {
            const tDate = new Date(t.date);

            if (tDate <= snapshotDate) return;
            const val = t.type === 'deposit' ? t.value : -t.value;
            const dur = Math.ceil((now - tDate) / (1000 * 60 * 60 * 24));
            bankSupposedRevenue += val * (Math.pow(bankDailyRatio, Math.max(0, dur)) - 1);
        });

        const bankYearlyRevenue = Math.pow(bankDailyRatio, 365) - 1;
        const extraRevenue = revenue - bankSupposedRevenue;

        bankComparison = {
            bankRatio: activeSnapshot.bankRatio,        // annual %
            bankDailyRatio,                             // daily compound factor
            bankYearlyRevenue,                          // annual yield as decimal (e.g. 0.25)
            bankSupposedRevenue,                        // EGP bank would have earned
            extraRevenue,                               // walletRevenue - bankSupposedRevenue
        };
    }

    return {
        wallet,
        totalValue: totalVal,
        currentValueForProfit,
        activeSnapshot: activeSnapshot ? {
            _id: activeSnapshot._id,
            date: activeSnapshot.date,
            balance: activeSnapshot.balance,
            bankRatio: activeSnapshot.bankRatio || 0
        } : null,
        diffValue,
        analysis,
        bankComparison,
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
