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

class ScoringService {
    async calculateAllScores(customWeights = {}) {
        const weights = { ...DEFAULT_WEIGHTS, ...customWeights };
        console.log('Starting score recalculation with weights:', weights);

        try {
            const stocks = await Stock.find();
            const bfValues = await BFValue.find();
            const fundamentalRecs = await FundamentalRecommendation.find();
            const technicalRecs = await TechnicalRecommendation.find();
            const rfpRecs = await RFPRecommendation.find();
            const rspRecs = await RSPRecommendation.find();

            // Create maps for quick lookup
            const bfMap = new Map(bfValues.map(v => [v.stock.toString(), v.value]));
            const fundamentalMap = new Map(fundamentalRecs.map(v => [v.stock.toString(), v.target]));

            // For technical, we take the highest target if multiple exist
            const technicalMap = new Map();
            technicalRecs.forEach(v => {
                const stockId = v.stock.toString();
                if (!technicalMap.has(stockId) || v.target > technicalMap.get(stockId)) {
                    technicalMap.set(stockId, v.target);
                }
            });

            const rfpMap = new Map(rfpRecs.map(v => [v.stock.toString(), v.score]));
            const rspMap = new Map(rspRecs.map(v => [v.stock.toString(), v.score]));

            // Helper to calculate rank-based score (i1, i2, i3)
            const calculateRankScores = (items) => {
                // items is an array of { stockId, potential } where potential > 0
                const validItems = items.filter(item => item.potential > 0);
                if (validItems.length === 0) return new Map();

                // Sort by potential descending
                validItems.sort((a, b) => b.potential - a.potential);

                const count = validItems.length;
                const scoreMap = new Map();

                validItems.forEach((item, index) => {
                    // Excel formula: 1 - (RANK - 1) / COUNT(>0)
                    // Index is RANK - 1 (0-based)
                    const score = 1 - (index / count);
                    scoreMap.set(item.stockId, score);
                });

                return scoreMap;
            };

            // 1. BF Potential (ratio)
            const bfPotentials = stocks.map(s => ({
                stockId: s._id.toString(),
                potential: (bfMap.get(s._id.toString()) || 0) / (s.price || 1)
            }));
            const i1Map = calculateRankScores(bfPotentials);

            // 2. Fundamental Potential
            const fundamentalPotentials = stocks.map(s => ({
                stockId: s._id.toString(),
                potential: (fundamentalMap.get(s._id.toString()) || 0) / (s.price || 1) - 1
            }));
            const i2Map = calculateRankScores(fundamentalPotentials);

            // 3. Technical Potential
            const technicalPotentials = stocks.map(s => ({
                stockId: s._id.toString(),
                potential: (technicalMap.get(s._id.toString()) || 0) / (s.price || 1) - 1
            }));
            const i3Map = calculateRankScores(technicalPotentials);

            // 4. ArabStock Potential (i4)
            const arabStockPotentials = stocks.map(s => {
                const target = s.arabic_stock_analyzers_fair_value || s.arabic_stock_fair_value || 0;
                return {
                    stockId: s._id.toString(),
                    potential: s.price == 0 ? 0 : target / s.price
                };
            });
            const i4Map = calculateRankScores(arabStockPotentials);

            // Final Calculation
            const bulkOps = [];
            for (const stock of stocks) {
                const stockId = stock._id.toString();

                const i1 = i1Map.get(stockId) || 0;
                const i2 = i2Map.get(stockId) || 0;
                const i3 = i3Map.get(stockId) || 0;
                const i4 = i4Map.get(stockId) || 0;
                const rfp = rfpMap.get(stockId) ? 1 : 0;
                const rsp = rspMap.get(stockId) || 0;
                /*
                const givenDate = new Date("2026-05-20");
                const today = new Date();
                // Convert both dates to UTC (ignoring time of day)
                const utcGiven = Date.UTC(givenDate.getFullYear(), givenDate.getMonth(), givenDate.getDate());
                const utcToday = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate());

                // Calculate difference in days
                const msPerDay = 1000 * 60 * 60 * 24;
                let ratioOfArab = Math.floor((utcToday - utcGiven) / msPerDay) / 40;
                */
                let ratioOfArab = 0
                const totalScore = (weights.bf * i1) +
                    (weights.fundamental * i2) +
                    (weights.technical * i3) +
                    (weights.rfp * rfp) +
                    (weights.rsp * rsp) + (i4 * weights.arabstock) * Math.min(1, ratioOfArab);

                bulkOps.push({
                    updateOne: {
                        filter: { _id: stock._id },
                        update: {
                            $set: {
                                bf_potential: i1,
                                fundamental_potential: i2,
                                technical_potential: i3,
                                arabstock_score: i4,
                                rfp_score: rfp,
                                rsp_score: rsp,
                                total_score: totalScore
                            }
                        }
                    }
                });
            }

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
}

module.exports = new ScoringService();
