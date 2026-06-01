const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    title: {
        type: String,
        required: true
    },
    content: {
        type: String,
        required: true
    },
    seen: {
        type: Boolean,
        default: false
    },
    type: {
        type: String,
        enum: ['wallet_update', 'system_alert'],
        default: 'wallet_update'
    }
}, { timestamps: true });

module.exports = mongoose.model('Notification', NotificationSchema);
