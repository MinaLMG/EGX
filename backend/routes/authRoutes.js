const express = require('express');
const router = express.Router();
const { register, login, getMe, getUsers, updateUserStatus, resetUserPassword, changePassword, updateFcmToken, logout } = require('../controllers/authController');
const { protect, authorize } = require('../middleware/auth');

router.post('/register', register);
router.post('/login', login);
router.get('/me', protect, getMe);
router.patch('/change-password', protect, changePassword);
router.patch('/fcm-token', protect, updateFcmToken);
router.post('/logout', protect, logout);

// Admin only routes
router.get('/users', protect, authorize('admin'), getUsers);
router.patch('/users/:id/status', protect, authorize('admin'), updateUserStatus);
router.patch('/users/:id/reset-password', protect, authorize('admin'), resetUserPassword);

module.exports = router;
