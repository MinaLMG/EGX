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

// ─────────────────────────────────────────────────────────────────
// Update Strategy:
//   VERCEL=1  → Lazy middleware (per-request trigger, stateless)
//   local/VPS → node-cron (scheduled, persistent process)
// Vercel sets VERCEL=1 automatically in its environment.
// ─────────────────────────────────────────────────────────────────
if (process.env.VERCEL) {
    const lazyPriceUpdate = require('./middleware/lazyPriceUpdate');
    app.use(lazyPriceUpdate);
    console.log('[Mode] Vercel detected — using lazy price update middleware.');
} else {
    console.log('[Mode] Persistent server detected — cron jobs will be scheduled on startup.');
}

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
    if (!process.env.VERCEL) scheduleCronJobs();
});

// ─────────────────────────────────────────────────────────────────
// Cron Jobs — single approach for local & VPS persistent servers.
// (Vercel serverless can't run persistent cron; use HTTP triggers
//  there instead if ever needed.)
// ─────────────────────────────────────────────────────────────────
function scheduleCronJobs() {
    const cron = require('node-cron');
    const scraperService = require('./services/scraperService');
    const mubasherTradeService = require('./services/mubasherTradeService');

    // Lock flag — prevents a new scrape starting while the previous one
    // is still running (Mubasher scrape can exceed 1 minute).
    let isScraping = false;

    // Price update: every minute during EGX market hours (Sun–Thu, 09:50–15:00)
    cron.schedule('* * * * *', async () => {
        if (isScraping) {
            console.log('[Cron] Skipping tick — previous scrape still in progress.');
            return;
        }
        const now = new Date();
        const cairoNow = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));
        const day = cairoNow.getDay();   // 0=Sun … 6=Sat
        const h = cairoNow.getHours();
        const m = cairoNow.getMinutes();
        const isWorkingDay = day >= 0 && day <= 4;                         // Sun–Thu (EGX)
        const isMarketHour = (h > 9 || (h === 9 && m >= 50)) && h < 15;   // 09:50–15:00
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

    // Daily fair-value scrape: every day at 21:00 Cairo (after market close)
    cron.schedule('0 21 * * *', async () => {
        try {
            console.log('[Cron] Running daily ArabicStock fair-value scrape...');
            await scraperService.scrapeAllArabicStocks();
            console.log('[Cron] Daily scrape complete.');
        } catch (err) {
            console.error('[Cron] Daily scrape failed:', err.message);
        }
    }, { timezone: 'Africa/Cairo' });

    console.log('[Cron] Jobs scheduled: Mubasher price update (every min, market hours) + ArabicStock scrape (21:00 Cairo).');
}
