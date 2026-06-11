const express = require('express');
const router = express.Router();
const {
    getPreferences,
    updatePreferences,
    updateInterests,
    deleteAccount,
    getInterests
} = require('../controllers/profileController');
const { protect } = require('../middleware/auth');

// All profile routes require authentication
router.get('/preferences', protect, getPreferences);
router.patch('/preferences', protect, updatePreferences);
router.patch('/interests', protect, updateInterests);
router.delete('/account', protect, deleteAccount);
router.get('/interests', protect, getInterests);

module.exports = router;
