const mongoose = require('mongoose');

const UserPreferencesSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        unique: true
    },
    language: {
        type: String,
        enum: ['en', 'ar'],
        default: 'en'
    },
    theme: {
        type: String,
        enum: ['light', 'dark', 'system'],
        default: 'system'
    },
    selectedInterests: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Interest'
    }]
}, { timestamps: true });

module.exports = mongoose.model('UserPreferences', UserPreferencesSchema);
