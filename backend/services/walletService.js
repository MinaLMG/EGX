const Wallet = require('../models/Wallet');
const Stock = require('../models/Stock');

class WalletService {
    /**
     * Gets the populated wallet for a user.
     */
    async getPopulatedWallet(userId) {
        let wallet = await Wallet.findOne({ user: userId }).populate('items.stock').populate('user', 'name');
        if (!wallet) {
            wallet = await Wallet.create({ user: userId, items: [], transactions: [] });
        }
        return wallet;
    }

    /**
     * Calculates the current total value of the wallet.
     */
    calculateTotalValue(wallet) {
        let totalVal = wallet.cash;
        wallet.items.forEach(item => {
            const price = (wallet.mode === 'manual' && item.manualPrice)
                ? item.manualPrice
                : (item.stock.price || 0);
            totalVal += (item.quantity * price);
        });
        return totalVal;
    }

    /**
     * Performs rebalancing analysis and generates Buy/Sell suggestions.
     * This is the lightweight version used for notifications.
     */
    calculateRebalancing(wallet, totalVal) {
        const itemsCount = wallet.items.length;
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
                    const deviation = Math.abs(gap) / supposedValue;
                    if (deviation >= threshold) suggestion = gap > 0 ? 'Buy' : 'Sell';
                } else if (gap > 0) {
                    suggestion = 'Buy';
                }

                const fairPrice = item.quantity > 0 ? (supposedValue / item.quantity) : 0;
                const margin = 0.01;
                const buyTarget = fairPrice * (1 - threshold - margin);
                const sellTarget = fairPrice * (1 + threshold + margin);

                analysis.push({
                    ticker: item.stock.ticker,
                    name: item.stock.name,
                    quantity: item.quantity,
                    rank: i + 1,
                    currentPrice,
                    realMarketValue,
                    supposedValue,
                    fairPrice,
                    buyTarget,
                    sellTarget,
                    gap,
                    suggestion
                });
            }
        }

        return { analysis, diffValue };
    }

    /**
     * Calculates profit metrics, revenue, and bank comparison.
     * This is the heavy version used for the main wallet dashboard.
     */
    calculateProfitMetrics(wallet, totalVal) {
        const now = new Date();
        let totalEffectiveValue = 0;
        let totalNetInvestment = 0;
        let firstDepositDate = null;

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
            const snapshotDate = new Date(activeSnapshot.date);
            snapshotDate.setHours(23, 59, 59, 999);
            const syntheticDuration = (now - snapshotDate) / (1000 * 60 * 60 * 24);
            totalEffectiveValue += activeSnapshot.balance * Math.max(0, syntheticDuration);
            totalNetInvestment += activeSnapshot.balance;
            firstDepositDate = snapshotDate;

            (wallet.transactions || []).forEach(t => {
                const tDate = new Date(t.date);
                if (tDate <= snapshotDate) return;
                const val = t.type === 'deposit' ? t.value : -t.value;
                const durationDays = (now - tDate) / (1000 * 60 * 60 * 24);
                totalEffectiveValue += val * Math.max(0, durationDays);
                totalNetInvestment += val;
            });
        } else {
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
        const currentValueForProfit = (wallet.profitMode === 'manual' && wallet.manualProfitValue)
            ? wallet.manualProfitValue
            : totalVal;

        const revenue = currentValueForProfit - totalNetInvestment;
        const revenuePercentage = walletEffectiveValue > 0 ? (revenue / walletEffectiveValue) : 0;

        let dailyRatio = 1;
        let yearlyRevenue = 0;

        if (totalDuration > 0 && (revenuePercentage + 1) > 0) {
            dailyRatio = Math.pow(10, Math.log10(revenuePercentage + 1) / totalDuration);
            yearlyRevenue = Math.pow(dailyRatio, 365) - 1;
        }

        let bankComparison = null;
        if (activeSnapshot && activeSnapshot.bankRatio > 0) {
            const annualRate = activeSnapshot.bankRatio / 100;
            const bankDailyRatio = Math.pow(10, Math.log10(annualRate + 1) / 365);
            const snapshotDate = new Date(activeSnapshot.date);
            snapshotDate.setHours(23, 59, 59, 999);
            const snapDuration = Math.ceil((now - snapshotDate) / (1000 * 60 * 60 * 24));
            let bankSupposedRevenue = activeSnapshot.balance * (Math.pow(bankDailyRatio, Math.max(0, snapDuration)) - 1);
            
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
                bankRatio: activeSnapshot.bankRatio,
                bankDailyRatio,
                bankYearlyRevenue,
                bankSupposedRevenue,
                extraRevenue,
            };
        }

        return {
            totalNetInvestment,
            walletEffectiveValue,
            currentValueForProfit,
            revenue,
            revenuePercentage,
            dailyRatio,
            yearlyRevenue,
            totalDuration,
            bankComparison,
            activeSnapshot: activeSnapshot ? {
                _id: activeSnapshot._id,
                date: activeSnapshot.date,
                balance: activeSnapshot.balance,
                bankRatio: activeSnapshot.bankRatio || 0
            } : null
        };
    }

    /**
     * Orchestrates the calculation of all wallet metrics.
     * Used by the API to provide a complete wallet state.
     */
    async calculateWalletMetrics(userId) {
        const wallet = await this.getPopulatedWallet(userId);
        const totalValue = this.calculateTotalValue(wallet);
        
        const { analysis, diffValue } = this.calculateRebalancing(wallet, totalValue);
        const profitMetrics = this.calculateProfitMetrics(wallet, totalValue);

        return {
            wallet,
            totalValue,
            currentValueForProfit: profitMetrics.currentValueForProfit,
            activeSnapshot: profitMetrics.activeSnapshot,
            diffValue,
            analysis,
            bankComparison: profitMetrics.bankComparison,
            profit: {
                totalNetInvestment: profitMetrics.totalNetInvestment,
                walletEffectiveValue: profitMetrics.walletEffectiveValue,
                revenue: profitMetrics.revenue,
                revenuePercentage: profitMetrics.revenuePercentage,
                dailyRatio: profitMetrics.dailyRatio,
                yearlyRevenue: profitMetrics.yearlyRevenue,
                totalDuration: profitMetrics.totalDuration
            }
        };
    }
}

module.exports = new WalletService();
