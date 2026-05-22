const mongoose = require('mongoose');

const FundamentalRecommendationSchema = new mongoose.Schema({
    stock: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Stock',
        required: true,
        unique: true
    },
    target: {
        type: Number,
        required: true
    }
}, { timestamps: true });

module.exports = mongoose.model('FundamentalRecommendation', FundamentalRecommendationSchema);
