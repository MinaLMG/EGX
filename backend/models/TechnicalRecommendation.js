const mongoose = require('mongoose');

const TechnicalRecommendationSchema = new mongoose.Schema({
    stock: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Stock',
        required: true,
        unique: true
    },
    target: {
        type: Number,
        required: true
    },
    notes: {
        type: String,
        required: false
    }
}, { timestamps: true });

module.exports = mongoose.model('TechnicalRecommendation', TechnicalRecommendationSchema);
