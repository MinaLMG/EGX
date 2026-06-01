const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const connectDB = require('./config/db');

// Load environment variables
dotenv.config();

// Guard: fail fast if critical env vars are missing
if (!process.env.JWT_SECRET) {
    throw new Error('FATAL: JWT_SECRET environment variable is not set. Refusing to start.');
}

// Connect to Database
connectDB();

const app = express();

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
app.use('/api/cron', require('./routes/cronRoutes'));
app.use('/api/notifications', require('./routes/notificationRoutes'));

// Health Check
app.get('/', (req, res) => {
    res.send('Egyptian Stocks Fair Value API is running...');
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);

    // Cron Strategy:
    // 1. On Local/VPS: Use node-cron for persistent background scheduling.
    // 2. On Vercel: This does nothing (serverless). Use Vercel's config or external pingers to hit /api/cron/sync instead.
    if (!process.env.VERCEL) {
        scheduleCronJobs();
    } else {
        console.log('[Mode] Vercel detected — Background cron disabled (use external triggers).');
    }
});

// ─────────────────────────────────────────────────────────────────
// Cron Jobs — for local & VPS persistent servers only.
// ─────────────────────────────────────────────────────────────────
function scheduleCronJobs() {
    const cron = require('node-cron');
    const scraperService = require('./services/scraperService');
    const mubasherTradeService = require('./services/mubasherTradeService');

    let isScraping = false;

    // Price update: every minute during EGX market hours (Sun–Thu, 09:50–15:00)
    cron.schedule('*/1 9-14 * * 0-4', async () => {
        if (isScraping) {
            console.log('[Cron] Skipping tick — previous scrape still in progress.');
            return;
        }
        const now = new Date();
        const cairoNow = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));
        const day = cairoNow.getDay();
        const h = cairoNow.getHours();
        const m = cairoNow.getMinutes();
        const isWorkingDay = day >= 0 && day <= 4;
        const isMarketHour = (h > 9 || (h === 9 && m >= 50)) && h < 15;
        console.log(isWorkingDay, isMarketHour);
        if (!isWorkingDay || !isMarketHour) return;

        isScraping = true;
        try {
            console.log('[Cron] Triggering Mubasher price update...');
            const count = await mubasherTradeService.updatePrices();
            console.log(`[Cron] Price update done: ${count} stocks updated.`);
        } catch (err) {
            console.error('[Cron] Price update failed:', err.message);
        } finally {
            isScraping = false;
        }
    }, { timezone: 'Africa/Cairo' });

    // Daily fair-value scrape: 00:00 Cairo
    cron.schedule('0 0 * * *', async () => {
        try {
            console.log('[Cron] Running daily ArabicStock fair-value scrape...');
            await scraperService.scrapeAllArabicStocks();
            console.log('[Cron] Daily scrape complete.');
        } catch (err) {
            console.error('[Cron] Daily scrape failed:', err.message);
        }
    }, { timezone: 'Africa/Cairo' });

    console.log('[Cron] Jobs scheduled: Mubasher Price (market hours) + Daily Fair-Value Scrape (00:00).');
}
