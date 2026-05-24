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
const mubasherPriceService = require('./services/mubasherPriceService');

const app = express();

// Schedule daily ArabicStock scrape at 00:00
cron.schedule('0 0 * * *', async () => {
    console.log('Running daily scheduled scrape...');
    await scraperService.scrapeAllArabicStocks();
});

// Schedule Mubasher price updates every 1 minute during EGX market hours (10:00 - 14:30 Cairo time)
// Cron: Sunday to Thursday — timezone handles Cairo local time
cron.schedule('*/1 10-14 * * 0-4', async () => {
    // Cron fires 10:00-14:59 Cairo time; guard against the 14:30-14:59 tail
    const now = new Date();
    // Use Cairo time (UTC+2 as per user)
    // Convert current UTC time to Cairo time
    const cairoTime = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));
    const hours = cairoTime.getHours();
    const minutes = cairoTime.getMinutes();

    if (hours > 14 || (hours === 14 && minutes > 30)) return;

    console.log('Running scheduled Mubasher price update...');
    await mubasherPriceService.updatePricesFromMubasher();
}, { scheduled: true, timezone: "Africa/Cairo" });

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
