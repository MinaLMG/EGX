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
        default: 0
    },
    arabic_stock_fair_value: Number,
    arabic_stock_analyzers_fair_value: Number,
    arabic_stock_getter: String,
    arabic_stock_target_mode: {
        type: String,
        enum: ['max', 'analyzers', 'fair_value', 'manual'],
        default: 'max'
    },
    arabic_stock_custom_fair_value: {
        type: Number,
        default: null
    },
    lastUpdated: {
        type: Date,
        default: Date.now
    },

    // --- Main Scores ---
    bf_score: { type: Number, default: 0 },
    fundamental_score: { type: Number, default: 0 },
    technical_score: { type: Number, default: 0 },
    rfp_score: { type: Number, default: 0 },
    rsp_score: { type: Number, default: 0 },
    arabstock_score: { type: Number, default: 0 },
    total_score: { type: Number, default: 0 },

    // --- Trial Scores ---
    trial_bf_score: { type: Number, default: 0 },
    trial_fundamental_score: { type: Number, default: 0 },
    trial_technical_score: { type: Number, default: 0 },
    trial_rfp_score: { type: Number, default: 0 },
    trial_rsp_score: { type: Number, default: 0 },
    trial_arabstock_score: { type: Number, default: 0 },
    trial_total_score: { type: Number, default: 0 }
});

// Index for high-performance sorting and retrieval
StockSchema.index({ total_score: -1, ticker: 1 });

module.exports = mongoose.model('Stock', StockSchema);
