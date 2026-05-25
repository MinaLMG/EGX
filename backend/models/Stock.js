const mongoose = require('mongoose');

const StockSchema = new mongoose.Schema({
    ticker: {
        type: String,
        required: true,
        unique: true,
        uppercase: true
    },
    name: {
        type: String,
        required: false
    },
    price: {
        type: Number,
    },
    arabic_stock_fair_value: Number,
    arabic_stock_analyzers_fair_value: Number,
    arabic_stock_getter: String,
    lastUpdated: {
        type: Date,
        default: Date.now
    },
    // Scoring fields
    bf_potential: Number,
    fundamental_potential: Number,
    technical_potential: Number,
    rfp_score: { type: Number, default: 0 },
    rsp_score: { type: Number, default: 0 },
    arabstock_score: { type: Number, default: 0 },
    total_score: { type: Number, default: 0 },
    trial_total_score: { type: Number, default: 0 },
    trial_fundamental_raw: { type: Number, default: 0 },  // raw FV/price - 1 (trial only)
    trial_technical_sum: { type: Number, default: 0 },   // sum of per-rec rank scores (trial only)
    trial_bf_potential: { type: Number, default: 0 },     // (2*BF/price)-1 (trial only)
    trial_rfp_score: { type: Number, default: 0 },
    trial_rsp_score: { type: Number, default: 0 },
    trial_arabstock_score: { type: Number, default: 0 }
});

// Index matching the sort used in getStocks / getStocksMatrix / scoringService
// Converts full-collection-scan → index-scan for every stock list query
StockSchema.index({ total_score: -1, ticker: 1 });

module.exports = mongoose.model('Stock', StockSchema);
