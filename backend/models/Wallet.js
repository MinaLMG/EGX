const mongoose = require('mongoose');

const WalletItemSchema = new mongoose.Schema({
    stock: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Stock',
        required: true
    },
    quantity: {
        type: Number,
        default: 0
    },
    manualPrice: {
        type: Number, // For real-time price subscription mode
        required: false
    }
});

const WalletSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        unique: true
    },
    items: [WalletItemSchema],
    cash: {
        type: Number,
        default: 0
    },
    factor: {
        type: Number,
        default: 0.6
    },
    mode: {
        type: String,
        enum: ['automatic', 'manual'],
        default: 'automatic'
    },
    manualTotalOverride: {
        type: Number, // For real-time price mode
        required: false
    }
}, { timestamps: true });

module.exports = mongoose.model('Wallet', WalletSchema);
