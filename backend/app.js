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

const app = express();

// Schedule ArabicStock scrape at 00:00
cron.schedule('0 0 * * *', async () => {
    console.log('Running daily scheduled scrape...');
    await scraperService.scrapeAllArabicStocks();
});

// Schedule Mubasher Trade daily monitoring session (9:50 AM Cairo, Sun-Thu)
cron.schedule('50 9 * * 0-4', async () => {
    console.log('Starting daily Mubasher Trade monitoring at 09:50 Cairo time');
    await mubasherTradeService.startMonitoring();
}, {
    scheduled: true,
    timezone: "Africa/Cairo"
});

// Legacy Mubasher price service (deactivated as per user request)
// cron.schedule('*/1 10-14 * * 0-4', async () => { ... });

// Middleware
app.use(cors());
app.use(express.json());

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
