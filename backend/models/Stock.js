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
    total_score: { type: Number, default: 0 }
});

module.exports = mongoose.model('Stock', StockSchema);
