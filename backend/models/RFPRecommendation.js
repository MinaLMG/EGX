const mongoose = require('mongoose');

const RFPRecommendationSchema = new mongoose.Schema({
    stock: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Stock',
        required: true,
        unique: true
    },
    score: {
        type: Number,
        default: 1
    }
}, { timestamps: true });

module.exports = mongoose.model('RFPRecommendation', RFPRecommendationSchema);
