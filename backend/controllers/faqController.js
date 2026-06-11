const FAQ = require('../models/FAQ');

// ─── GET /api/faq ─────────────────────────────────────────────────────────────
exports.getFAQs = async (req, res) => {
    try {
        const faqs = await FAQ.find({ isActive: true })
            .sort({ displayOrder: 1 })
            .select('-createdAt -updatedAt -__v');
        res.json(faqs);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ─── POST /api/faq (admin) ────────────────────────────────────────────────────
exports.createFAQ = async (req, res) => {
    try {
        const { question, answer, displayOrder } = req.body;
        const faq = await FAQ.create({ question, answer, displayOrder });
        res.status(201).json(faq);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ─── PATCH /api/faq/:id (admin) ───────────────────────────────────────────────
exports.updateFAQ = async (req, res) => {
    try {
        const faq = await FAQ.findByIdAndUpdate(req.params.id, req.body, { new: true });
        if (!faq) return res.status(404).json({ message: 'FAQ not found' });
        res.json(faq);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ─── DELETE /api/faq/:id (admin) ──────────────────────────────────────────────
exports.deleteFAQ = async (req, res) => {
    try {
        const faq = await FAQ.findByIdAndDelete(req.params.id);
        if (!faq) return res.status(404).json({ message: 'FAQ not found' });
        res.json({ message: 'FAQ deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
