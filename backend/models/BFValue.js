const mongoose = require('mongoose');

const BFValueSchema = new mongoose.Schema({
    stock: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Stock',
        required: true,
        unique: true
    },
    value: {
        type: Number,
        required: true
    }
}, { timestamps: true });

module.exports = mongoose.model('BFValue', BFValueSchema);
