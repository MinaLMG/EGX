const mongoose = require('mongoose');

const RSPRecommendationSchema = new mongoose.Schema({
    stock: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Stock',
        required: true,
        unique: true
    },
    score: {
        type: Number,
        required: true
    }
}, { timestamps: true });

module.exports = mongoose.model('RSPRecommendation', RSPRecommendationSchema);
