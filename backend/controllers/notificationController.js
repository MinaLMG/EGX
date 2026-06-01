const Notification = require('../models/Notification');

// GET /api/notifications — fetch current user's notifications
exports.getMyNotifications = async (req, res) => {
    try {
        const notifications = await Notification.find({ user: req.user.id })
            .sort({ createdAt: -1 })
            .limit(50);

        // Mark all as seen
        await Notification.updateMany(
            { user: req.user.id, seen: false },
            { seen: true }
        );

        res.json({ success: true, notifications });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// GET /api/notifications/unread-count
exports.getUnreadCount = async (req, res) => {
    try {
        const count = await Notification.countDocuments({ user: req.user.id, seen: false });
        res.json({ success: true, count });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};
