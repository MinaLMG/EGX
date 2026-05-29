const Stock = require('../models/Stock');
const BFValue = require('../models/BFValue');
const FundamentalRecommendation = require('../models/FundamentalRecommendation');
const TechnicalRecommendation = require('../models/TechnicalRecommendation');
const RFPRecommendation = require('../models/RFPRecommendation');
const RSPRecommendation = require('../models/RSPRecommendation');
const ConfigHelper = require('../utils/configHelper');

class ScoringService {
    /**
     * Orchestrates the recalculation of scores for all stocks using both
     * Steep and Legacy strategies.
     */
    async calculateAllScores(customWeights = {}) {
        try {
            console.log('Starting score recalculation orchestration...');

            // Gathering weights from DB (Algorithm-specific)
            const steepWeights = await ConfigHelper.getSetting(ConfigHelper.KEYS.STEEP_SCORING_WEIGHTS, {});
            const legacyWeights = await ConfigHelper.getSetting(ConfigHelper.KEYS.LEGACY_SCORING_WEIGHTS, {});

            // Gathering raw data phase
            const stocks = await Stock.find();
            const bfValues = await BFValue.find();
            const fundamentalRecs = await FundamentalRecommendation.find();
            const technicalRecs = await TechnicalRecommendation.find();
            const rfpRecs = await RFPRecommendation.find();
            const rspRecs = await RSPRecommendation.find();

            const rawData = { bfValues, fundamentalRecs, technicalRecs, rfpRecs, rspRecs };

            // Scoring phase
            // 1. Steep Scoring System
            const steepResultsMap = this._steepScoringSystem(stocks, rawData, steepWeights);

            // 2. Legacy Scoring System
            const legacyResultsMap = this._legacyScoringSystem(stocks, rawData, legacyWeights);

            // Persistence phase
            const bulkOps = stocks.map(stock => {
                const stockId = stock._id.toString();
                const steep = steepResultsMap.get(stockId) || {};
                const legacy = legacyResultsMap.get(stockId) || {};

                return {
                    updateOne: {
                        filter: { _id: stock._id },
                        update: {
                            $set: {
                                // Production fields (Mapping Steep results to generic score fields)
                                total_score: steep.total || 0,
                                bf_score: steep.bfScore || 0,
                                fundamental_score: steep.fundamentalScore || 0,
                                technical_score: steep.technicalScore || 0,
                                arabstock_score: steep.arabicStockScore || 0,
                                rfp_score: steep.rfpScore || 0,
                                rsp_score: steep.rspScore || 0,

                                // Trial fields (Mapping Legacy results to generic trial score fields)
                                trial_total_score: legacy.total || 0,
                                trial_bf_score: legacy.bfScore || 0,
                                trial_fundamental_score: legacy.fundamentalScore || 0,
                                trial_technical_score: legacy.technicalScore || 0,
                                trial_rfp_score: legacy.rfpScore || 0,
                                trial_rsp_score: legacy.rspScore || 0,
                                trial_arabstock_score: legacy.arabicStockScore || 0
                            }
                        }
                    }
                };
            });

            if (bulkOps.length > 0) {
                await Stock.bulkWrite(bulkOps);
            }

            console.log(`Recalculation complete for ${stocks.length} stocks.`);
            return { success: true, count: stocks.length };
        } catch (error) {
            console.error('Error in scoring service:', error);
            throw error;
        }
    }

    // --- Private Helper: Utility for Rank-based scoring (0.0 to 1.0) ---
    _calculateRankScores(items) {
        const validItems = items.filter(item => item.potential > 0);
        if (validItems.length === 0) return new Map();

        validItems.sort((a, b) => b.potential - a.potential);
        const count = validItems.length;
        const scoreMap = new Map();

        validItems.forEach((item, index) => {
            const score = 1 - (index / count);
            scoreMap.set(item.stockId, score);
        });

        return scoreMap;
    }

    // --- Legacy Scoring Strategy ---
    _legacyScoringSystem(stocks, data, weights) {
        const { bfValues, fundamentalRecs, technicalRecs, rfpRecs, rspRecs } = data;

        const bfMap = new Map(bfValues.map(v => [v.stock.toString(), v.value]));
        const fundamentalMap = new Map(fundamentalRecs.map(v => [v.stock.toString(), v.target]));

        const technicalMap = new Map();
        technicalRecs.forEach(v => {
            const stockId = v.stock.toString();
            if (!technicalMap.has(stockId) || v.target > technicalMap.get(stockId)) {
                technicalMap.set(stockId, v.target);
            }
        });

        const rfpMap = new Map(rfpRecs.map(v => [v.stock.toString(), v.score]));
        const rspMap = new Map(rspRecs.map(v => [v.stock.toString(), v.score]));

        // Calculate Ranks relative to current price (Only positive upside > 0)
        const bfRankMap = this._calculateRankScores(stocks.map(s => {
            const val = bfMap.get(s._id.toString()) || 0;
            return {
                stockId: s._id.toString(),
                potential: val > 0 ? (val / (s.price || 1)) - 1 : 0
            };
        }));

        const fundamentalRankMap = this._calculateRankScores(stocks.map(s => {
            const val = fundamentalMap.get(s._id.toString()) || 0;
            return {
                stockId: s._id.toString(),
                potential: val > 0 ? (val / (s.price || 1)) - 1 : 0
            };
        }));

        const technicalRankMap = this._calculateRankScores(stocks.map(s => {
            const val = technicalMap.get(s._id.toString()) || 0;
            return {
                stockId: s._id.toString(),
                potential: val > 0 ? (val / (s.price || 1)) - 1 : 0
            };
        }));

        const arabicStockRankMap = this._calculateRankScores(stocks.map(s => {
            const target = s.arabic_stock_analyzers_fair_value || s.arabic_stock_fair_value || 0;
            const potential = (target > 0 && s.price > 0) ? (target / s.price) - 1 : 0;
            return { stockId: s._id.toString(), potential };
        }));

        const resultsMap = new Map();
        for (const stock of stocks) {
            const stockId = stock._id.toString();
            const bfScore = bfRankMap.get(stockId) || 0;
            const funScore = fundamentalRankMap.get(stockId) || 0;
            const techScore = technicalRankMap.get(stockId) || 0;

            const arabRawRank = arabicStockRankMap.get(stockId);
            const arabScore = arabRawRank !== undefined ? (arabRawRank * 0.5 + 0.5) : 0;

            const rfpScore = rfpMap.get(stockId) ? 1 : 0;
            const rspScore = rspMap.get(stockId) || 0;

            const total = (weights.bf * bfScore) +
                (weights.fundamental * funScore) +
                (weights.technical * techScore) +
                (weights.rfp * rfpScore) +
                (weights.rsp * rspScore) +
                (weights.arabstock * arabScore) * 0; // Historically disabled in Legacy

            resultsMap.set(stockId, {
                bfScore,
                fundamentalScore: funScore,
                technicalScore: techScore,
                arabicStockScore: arabScore,
                rfpScore,
                rspScore,
                total
            });
        }
        return resultsMap;
    }

    // --- Steep Scoring Strategy ---
    _steepScoringSystem(stocks, data, weights) {
        const { bfValues, fundamentalRecs, technicalRecs, rfpRecs, rspRecs } = data;

        const bfMap = new Map(bfValues.map(v => [v.stock.toString(), v.value]));
        const fundamentalMap = new Map(fundamentalRecs.map(v => [v.stock.toString(), v.target]));
        const rfpMap = new Map(rfpRecs.map(v => [v.stock.toString(), v.score]));
        const rspMap = new Map(rspRecs.map(v => [v.stock.toString(), v.score]));

        // 1. Technical Summation Rank
        const technicalSumMap = new Map();
        const indexedRecs = technicalRecs.map((v) => ({
            stockId: v.stock.toString(),
            potential: v.target / (stocks.find(s => s._id.toString() === v.stock.toString())?.price || 1) - 1
        }));
        const validRecs = indexedRecs.filter(r => r.potential > 0);
        validRecs.sort((a, b) => b.potential - a.potential);
        const count = validRecs.length;
        validRecs.forEach((r, index) => {
            const recScore = count > 0 ? 1 - (index / count) : 0;
            technicalSumMap.set(r.stockId, (technicalSumMap.get(r.stockId) || 0) + recScore);
        });

        const resultsMap = new Map();
        for (const stock of stocks) {
            const stockId = stock._id.toString();
            const price = stock.price || 1;

            // 2. ArabicStock Steep: Capped Upside (Target / Price) - 1 clamped [0, 1]
            const target = Math.max(stock.arabic_stock_analyzers_fair_value || 0, stock.arabic_stock_fair_value || 0);
            let arabScore = Math.max(0, (target > 0 && price > 0) ? (target / price) - 1 : 0)
            arabScore = arabScore > 3 ? 0 : arabScore;
            // 3. BF Steep: (2.5 * BF / price) - 1
            const bfVal = bfMap.get(stockId) || 0;
            const bfScore = Math.max(0, (2.5 * bfVal / price) - 1);

            // 4. Fundamental Steep: raw Ratio - 1
            const fv = fundamentalMap.get(stockId) || 0;
            const funScore = fv > 0 ? (fv / price) - 1 : 0;

            const techScore = technicalSumMap.get(stockId) || 0;
            const rfpScore = rfpMap.get(stockId) || 0;
            const rspScore = rspMap.get(stockId) || 0;

            const total = (weights.bf * bfScore) +
                (weights.fundamental * funScore) +
                (weights.technical * techScore) +
                (weights.rfp * rfpScore) +
                (weights.rsp * rspScore) +
                (weights.arabstock * arabScore);

            resultsMap.set(stockId, {
                total,
                fundamentalScore: funScore,
                technicalScore: techScore,
                bfScore,
                rfpScore,
                rspScore,
                arabicStockScore: arabScore
            });
        }
        return resultsMap;
    }
}

module.exports = new ScoringService();
