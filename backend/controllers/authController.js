const User = require('../models/User');
const jwt = require('jsonwebtoken');

// @desc    Register user
// @route   POST /api/auth/register
exports.register = async (req, res) => {
    try {
        const { name, email, password } = req.body;
        const userExists = await User.findOne({ email });
        if (userExists) {
            return res.status(400).json({ message: 'User already exists' });
        }
        const user = await User.create({ name, email, password, role: 'user' });
        res.status(201).json({
            message: 'Registration successful. Waiting for admin approval.',
            user: { id: user._id, name: user.name, email: user.email, status: user.status }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Login user
// @route   POST /api/auth/login
exports.login = async (req, res) => {
    try {
        const { email, password } = req.body;

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const isMatch = await user.matchPassword(password);
        if (!isMatch) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        if (user.status === 'pending') {
            return res.status(403).json({ message: 'Account pending approval' });
        }

        const token = jwt.sign(
            { id: user._id, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '30d' }
        );

        res.json({
            token,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                role: user.role
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Get all users (Admin only)
// @route   GET /api/auth/users
exports.getUsers = async (req, res) => {
    try {
        const users = await User.find({}).select('-password');
        res.json(users);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Update user status (Admin only)
// @route   PATCH /api/auth/users/:id/status
exports.updateUserStatus = async (req, res) => {
    try {
        const { status } = req.body;
        if (!['active', 'pending', 'rejected'].includes(status)) {
            return res.status(400).json({ message: 'Invalid status' });
        }

        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        if (status === 'rejected') {
            await User.findByIdAndDelete(req.params.id);
            return res.json({ message: 'User registration rejected and account deleted' });
        }

        user.status = status;
        await user.save();
        res.json(user);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Reset any user password (Admin only)
// @route   PATCH /api/auth/users/:id/reset-password
exports.resetUserPassword = async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        user.password = '00000000'; // Default reset password
        await user.save();
        res.json({ message: 'Password reset to 00000000 successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Change own password
// @route   PATCH /api/auth/change-password
exports.changePassword = async (req, res) => {
    try {
        const { oldPassword, newPassword } = req.body;
        
        if (!newPassword || newPassword.length < 6) {
            return res.status(400).json({ message: 'New password must be at least 6 characters long' });
        }

        const user = await User.findById(req.user._id);
        
        // Verify old password
        const isMatch = await user.matchPassword(oldPassword);
        if (!isMatch) {
            return res.status(401).json({ message: 'Current password is incorrect' });
        }

        user.password = newPassword;
        await user.save();
        res.json({ message: 'Password updated successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// @desc    Get current user
// @route   GET /api/auth/me
exports.getMe = async (req, res) => {
    res.json(req.user);
};

// @desc    Update FCM Token
// @route   PATCH /api/auth/fcm-token
exports.updateFcmToken = async (req, res) => {
    try {
        const { fcmToken } = req.body;
        const user = await User.findById(req.user._id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        user.fcmToken = fcmToken;
        await user.save();
        res.json({ message: 'FCM token updated successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
