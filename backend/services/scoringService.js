const Stock = require('../models/Stock');
const BFValue = require('../models/BFValue');
const FundamentalRecommendation = require('../models/FundamentalRecommendation');
const TechnicalRecommendation = require('../models/TechnicalRecommendation');
const RFPRecommendation = require('../models/RFPRecommendation');
const RSPRecommendation = require('../models/RSPRecommendation');

const DEFAULT_WEIGHTS = {
    fundamental: 1.0,
    bf: 0.8,
    rfp: 0.7,
    rsp: 0.7,
    technical: 0.6,
    arabstock: 0.5
};
const TRIAL_WEIGHTS = {
    fundamental: 2.0,
    bf: 0.5,
    rfp: 1.2,
    rsp: 1.2,
    technical: 0.8,
    arabstock: 0
};

const ConfigHelper = require('../utils/configHelper');

class ScoringService {
    async calculateAllScores(customWeights = {}) {
        let weights = { ...DEFAULT_WEIGHTS, ...customWeights };

        try {
            const dbWeights = await ConfigHelper.getSetting(ConfigHelper.KEYS.SCORING_WEIGHTS, {});
            weights = { ...weights, ...dbWeights };

            console.log('Starting score recalculation orchestration...');

            // Gathering raw data phase
            const stocks = await Stock.find();
            const bfValues = await BFValue.find();
            const fundamentalRecs = await FundamentalRecommendation.find();
            const technicalRecs = await TechnicalRecommendation.find();
            const rfpRecs = await RFPRecommendation.find();
            const rspRecs = await RSPRecommendation.find();

            const rawData = { bfValues, fundamentalRecs, technicalRecs, rfpRecs, rspRecs };

            // Scoring phase
            // 1. Legacy Scoring System (Standard calculations)
            const legacyResultsMap = this._legacyScoringSystem(stocks, rawData, weights);

            // 2. Steep Scoring System (Aggressive calculations)
            const steepResultsMap = this._steepScoringSystem(stocks, rawData, TRIAL_WEIGHTS);

            // Persistence phase
            const bulkOps = stocks.map(stock => {
                const stockId = stock._id.toString();
                const legacy = legacyResultsMap.get(stockId) || {};
                const steep = steepResultsMap.get(stockId) || {};

                return {
                    updateOne: {
                        filter: { _id: stock._id },
                        update: {
                            $set: {
                                // Default/Legacy fields
                                total_score: legacy.total || 0,
                                bf_potential: legacy.bf || 0,
                                fundamental_potential: legacy.fundamental || 0,
                                technical_potential: legacy.technical || 0,
                                arabstock_score: legacy.arabstock || 0,
                                rfp_score: legacy.rfp || 0,
                                rsp_score: legacy.rsp || 0,

                                // Trial/Steep fields
                                trial_total_score: steep.total || 0,
                                trial_bf_potential: steep.bf || 0,
                                trial_fundamental_raw: steep.fundamental || 0,
                                trial_technical_sum: steep.technical || 0,
                                trial_rfp_score: steep.rfp || 0,
                                trial_rsp_score: steep.rsp || 0,
                                trial_arabstock_score: steep.arabstock || 0
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

    // --- Private Helper: Rank Ranking ---
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

    // --- Legacy Scoring System ---
    _legacyScoringSystem(stocks, data, weights) {
        const { bfValues, fundamentalRecs, technicalRecs, rfpRecs, rspRecs } = data;

        // Internal maps for this specific system
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

        // Calculate Ranks
        const i1Map = this._calculateRankScores(stocks.map(s => ({
            stockId: s._id.toString(),
            potential: (bfMap.get(s._id.toString()) || 0) / (s.price || 1)
        })));

        const i2Map = this._calculateRankScores(stocks.map(s => ({
            stockId: s._id.toString(),
            potential: (fundamentalMap.get(s._id.toString()) || 0) / (s.price || 1) - 1
        })));

        const i3Map = this._calculateRankScores(stocks.map(s => ({
            stockId: s._id.toString(),
            potential: (technicalMap.get(s._id.toString()) || 0) / (s.price || 1) - 1
        })));

        const i4Map = this._calculateRankScores(stocks.map(s => {
            const target = s.arabic_stock_analyzers_fair_value || s.arabic_stock_fair_value || 0;
            const potential = s.price == 0 ? 0 : (target / s.price) - 1;
            return { stockId: s._id.toString(), potential };
        }));

        const resultsMap = new Map();
        for (const stock of stocks) {
            const stockId = stock._id.toString();
            const i1 = i1Map.get(stockId) || 0;
            const i2 = i2Map.get(stockId) || 0;
            const i3 = i3Map.get(stockId) || 0;
            const i4Raw = i4Map.get(stockId);
            const i4 = i4Raw !== undefined ? (i4Raw * 0.5 + 0.5) : 0;
            const rfp = rfpMap.get(stockId) ? 1 : 0;
            const rsp = rspMap.get(stockId) || 0;

            const totalScore = (weights.bf * i1) +
                (weights.fundamental * i2) +
                (weights.technical * i3) +
                (weights.rfp * rfp) +
                (weights.rsp * rsp) + (i4 * weights.arabstock) * 0;

            resultsMap.set(stockId, {
                bf: i1,
                fundamental: i2,
                technical: i3,
                arabstock: i4,
                rfp: rfp,
                rsp: rsp,
                total: totalScore
            });
        }
        return resultsMap;
    }

    // --- Steep Scoring System ---
    _steepScoringSystem(stocks, data, weights) {
        const { bfValues, fundamentalRecs, technicalRecs, rfpRecs, rspRecs } = data;

        const bfMap = new Map(bfValues.map(v => [v.stock.toString(), v.value]));
        const fundamentalMap = new Map(fundamentalRecs.map(v => [v.stock.toString(), v.target]));
        const rfpMap = new Map(rfpRecs.map(v => [v.stock.toString(), v.score]));
        const rspMap = new Map(rspRecs.map(v => [v.stock.toString(), v.score]));

        // Steep technical summation logic
        const i3SumMapFinal = new Map();
        const indexedRecs = technicalRecs.map((v, idx) => ({
            stockId: v.stock.toString(),
            potential: v.target / (stocks.find(s => s._id.toString() === v.stock.toString())?.price || 1) - 1
        }));
        const validRecs = indexedRecs.filter(r => r.potential > 0);
        validRecs.sort((a, b) => b.potential - a.potential);
        const count = validRecs.length;
        validRecs.forEach((r, index) => {
            const recScore = count > 0 ? 1 - (index / count) : 0;
            i3SumMapFinal.set(r.stockId, (i3SumMapFinal.get(r.stockId) || 0) + recScore);
        });

        // Steep ArabStock rank
        const i4Map = this._calculateRankScores(stocks.map(s => {
            const target = s.arabic_stock_analyzers_fair_value || s.arabic_stock_fair_value || 0;
            const potential = s.price == 0 ? 0 : (target / s.price) - 1;
            return { stockId: s._id.toString(), potential };
        }));

        const resultsMap = new Map();
        for (const stock of stocks) {
            const stockId = stock._id.toString();
            const price = stock.price || 1;

            // i1 Steep: (2.5*BF/price)-1 filtered
            const bfVal = bfMap.get(stockId) || 0;
            const i1Steep = Math.max(0, (2.5 * bfVal / price) - 1);

            // i2 Steep: raw Ratio
            const fv = fundamentalMap.get(stockId) || 0;
            const i2Steep = fv > 0 ? (fv / price) - 1 : 0;

            const i3Steep = i3SumMapFinal.get(stockId) || 0;
            const rfpSteep = rfpMap.get(stockId) || 0;
            const rspSteep = rspMap.get(stockId) || 0;
            const i4Raw = i4Map.get(stockId);
            const i4 = i4Raw !== undefined ? (i4Raw * 0.5 + 0.5) : 0;

            const trialTotalScore = (weights.bf * i1Steep) +
                (weights.fundamental * i2Steep) +
                (weights.technical * i3Steep) +
                (weights.rfp * rfpSteep) +
                (weights.rsp * rspSteep) +
                (weights.arabstock * i4);

            resultsMap.set(stockId, {
                total: trialTotalScore,
                fundamental: i2Steep,
                technical: i3Steep,
                bf: i1Steep,
                rfp: rfpSteep,
                rsp: rspSteep,
                arabstock: i4
            });
        }
        return resultsMap;
    }
}

module.exports = new ScoringService();
