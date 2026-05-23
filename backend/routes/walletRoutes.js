const express = require('express');
const router = express.Router();
const { 
    getWallet, 
    updateWalletItem, 
    updateWalletSettings, 
    getWalletForUser,
    addTransaction,
    updateTransaction,
    deleteTransaction
} = require('../controllers/walletController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect); // All wallet routes are protected

router.get('/', getWallet);
router.post('/items', updateWalletItem);
router.patch('/', updateWalletSettings);

// Admin simulate wallet
router.get('/admin/:userId', authorize('admin'), getWalletForUser);

// Transactions
router.post('/transactions', addTransaction);
router.put('/transactions/:id', updateTransaction);
router.delete('/transactions/:id', deleteTransaction);

module.exports = router;
