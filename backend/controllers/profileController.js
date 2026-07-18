const UserPreferences = require('../models/UserPreferences');
const Interest = require('../models/Interest');
const User = require('../models/User');
const Wallet = require('../models/Wallet');

// ─── GET /api/profile/preferences ────────────────────────────────────────────
exports.getPreferences = async (req, res) => {
    try {
        let prefs = await UserPreferences.findOne({ userId: req.user._id })
            .populate('selectedInterests', 'name nameAr');

        if (!prefs) {
            // Auto-create default preferences on first access
            prefs = await UserPreferences.create({ userId: req.user._id });
        }

        res.json(prefs);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ─── PATCH /api/profile/preferences ──────────────────────────────────────────
exports.updatePreferences = async (req, res) => {
    try {
        const { language, theme } = req.body;

        const allowedFields = {};
        if (language !== undefined) allowedFields.language = language;
        if (theme !== undefined) allowedFields.theme = theme;

        const prefs = await UserPreferences.findOneAndUpdate(
            { userId: req.user._id },
            { $set: allowedFields },
            { new: true, upsert: true }
        );

        res.json(prefs);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ─── PATCH /api/profile/interests ────────────────────────────────────────────
exports.updateInterests = async (req, res) => {
    try {
        const { interestIds } = req.body;

        if (!Array.isArray(interestIds)) {
            return res.status(400).json({ message: 'interestIds must be an array' });
        }

        const prefs = await UserPreferences.findOneAndUpdate(
            { userId: req.user._id },
            { $set: { selectedInterests: interestIds } },
            { new: true, upsert: true }
        ).populate('selectedInterests', 'name nameAr');

        res.json(prefs);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ─── DELETE /api/profile/account ─────────────────────────────────────────────
// Soft delete: marks the account as deleted. A background job can hard-delete later.
exports.deleteAccount = async (req, res) => {
    try {
        return res.status(403).json({ message: 'Account deletion is currently disabled' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ─── GET /api/profile/interests (public list) ────────────────────────────────
exports.getInterests = async (req, res) => {
    try {
        const interests = await Interest.find({ isActive: true }).sort({ displayOrder: 1 });
        res.json(interests);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
