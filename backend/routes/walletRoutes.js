const express = require('express');
const router = express.Router();
const { getWallet, updateWalletItem, updateWalletSettings } = require('../controllers/walletController');
const { protect } = require('../middleware/auth');

router.use(protect); // All wallet routes are protected

router.get('/', getWallet);
router.post('/items', updateWalletItem);
router.patch('/', updateWalletSettings);

module.exports = router;
