const express = require('express');
const router = express.Router();
const {
    getWallet,
    updateWalletItem,
    updateWalletSettings,
    getWalletForUser,
    addTransaction,
    updateTransaction,
    deleteTransaction,
    addPointOnTime,
    updatePointOnTime,
    deletePointOnTime,
    updateManualPricesBulk
} = require('../controllers/walletController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect); // All wallet routes are protected

router.get('/', getWallet);
router.post('/items', updateWalletItem);
router.patch('/', updateWalletSettings);
router.put('/manual-prices', updateManualPricesBulk);

// Admin simulate wallet
router.get('/admin/:userId', authorize('admin'), getWalletForUser);

// Transactions
router.post('/transactions', addTransaction);
router.put('/transactions/:id', updateTransaction);
router.delete('/transactions/:id', deleteTransaction);

// Points-on-Time (balance snapshots)
router.post('/points', authorize('admin'), addPointOnTime);
router.put('/points/:id', authorize('admin'), updatePointOnTime);
router.delete('/points/:id', authorize('admin'), deletePointOnTime);

module.exports = router;
