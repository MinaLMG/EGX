const SystemConfig = require('../models/SystemConfig');

exports.getSettings = async (req, res) => {
    try {
        const settings = await SystemConfig.find();
        res.json(settings);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

exports.updateSetting = async (req, res) => {
    try {
        const { key, value, description } = req.body;
        const setting = await SystemConfig.findOneAndUpdate(
            { key },
            { value, description },
            { upsert: true, returnDocument: 'after' }
        );
        res.json(setting);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

exports.getScraperLogs = async (req, res) => {
    // Placeholder for later if needed
    res.json({ message: "Scraper logs not implemented yet" });
};
