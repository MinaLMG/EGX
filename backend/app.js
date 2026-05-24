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

// --- Local Cron Schedules (Disabled for Vercel Serverless) ---
// Note: These will not work on Vercel. Use vercel.json + the /api/cron routes instead.
/*
cron.schedule('0 0 * * *', async () => {
    console.log('Running daily scheduled scrape...');
    await scraperService.scrapeAllArabicStocks();
});

cron.schedule('49 13 * * 0-4', async () => {
    console.log('Starting daily Mubasher Trade monitoring at 09:50 Cairo time');
    await mubasherTradeService.startMonitoring();
}, {
    scheduled: true,
    timezone: "Africa/Cairo"
});
*/

// --- Vercel Cron Endpoints ---
app.get('/api/cron/update-prices', async (req, res) => {
    const cairoTime = new Date(new Date().toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));
    console.log('[Cron] Triggering price update at', cairoTime.toLocaleTimeString());
    try {
        // Use the fast API-based service for minute-by-minute updates
        await mubasherPriceService.updatePricesFromMubasher();
        res.status(200).json({ success: true, message: 'Prices updated via API' });
    } catch (error) {
        console.error('[Cron Error]:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/cron/daily-scrape', async (req, res) => {
    console.log('[Cron] Triggered daily fair value scrape');
    try {
        await scraperService.scrapeAllArabicStocks();
        res.status(200).json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

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
