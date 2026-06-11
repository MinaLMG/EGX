const express = require('express');
const router = express.Router();
const {
    getFAQs,
    createFAQ,
    updateFAQ,
    deleteFAQ
} = require('../controllers/faqController');
const { protect, authorize } = require('../middleware/auth');

// Public
router.get('/', getFAQs);

// Admin only
router.post('/', protect, authorize('admin'), createFAQ);
router.patch('/:id', protect, authorize('admin'), updateFAQ);
router.delete('/:id', protect, authorize('admin'), deleteFAQ);

module.exports = router;
