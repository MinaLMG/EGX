const mongoose = require('mongoose');

const MubasherUnmatchedSchema = new mongoose.Schema({
    type: {
        type: String,
        enum: ['stock', 'mubasher_price'],
        required: true
    },
    identifier: {
        type: String, // Ticker for stocks, Name for mubasher_price
        required: true
    },
    lastAttempt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('MubasherUnmatched', MubasherUnmatchedSchema);
