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
        type: Number, // For portfolio rebalancing manual mode
        required: false
    },
    profitMode: {
        type: String,
        enum: ['automatic', 'manual'],
        default: 'automatic'
    },
    manualProfitValue: {
        type: Number, // Dedicated value for profit calculator manual mode
        required: false
    },
    transactions: [{
        date: { type: Date, required: true },
        value: { type: Number, required: true }, // Absolute value
        type: { type: String, enum: ['deposit', 'withdrawal'], required: true }
    }]
}, { timestamps: true });

module.exports = mongoose.model('Wallet', WalletSchema);
