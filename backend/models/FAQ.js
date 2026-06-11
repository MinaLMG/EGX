const mongoose = require('mongoose');

const FAQSchema = new mongoose.Schema({
    question: {
        type: String,
        required: true,
        trim: true
    },
    questionAr: {
        type: String,
        trim: true
    },
    answer: {
        type: String,
        required: true,
        trim: true
    },
    answerAr: {
        type: String,
        trim: true
    },
    displayOrder: {
        type: Number,
        default: 0
    },
    isActive: {
        type: Boolean,
        default: true
    }
}, { timestamps: true });

module.exports = mongoose.model('FAQ', FAQSchema);
