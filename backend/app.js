const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const connectDB = require('./config/db');

// Load environment variables
dotenv.config();

// Connect to Database
connectDB();

const cron = require('node-cron');
const scraperService = require('./services/scraperService');
const mubasherTradeService = require('./services/mubasherTradeService');
const mubasherPriceService = require('./services/mubasherPriceService');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Lazy Price Update (Checks if price refresh is needed on every request)
const lazyPriceUpdate = require('./middleware/lazyPriceUpdate');
app.use(lazyPriceUpdate);

// Routes

const { protect, authorize } = require('./middleware/auth');

app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/stocks', require('./routes/stockRoutes'));
app.use('/api/recommendations', protect, authorize('admin'), require('./routes/recommendationRoutes'));
app.use('/api/mubasher', protect, authorize('admin'), require('./routes/mubasherRoutes'));
app.use('/api/wallet', require('./routes/walletRoutes'));
app.use('/api/admin', require('./routes/adminRoutes'));

// Health Check
app.get('/', (req, res) => {
    res.send('Egyptian Stocks Fair Value API is running...');
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
