const ConfigHelper = require('../utils/configHelper');
const mubasherTradeService = require('../services/mubasherTradeService');
const scraperService = require('../services/scraperService');

/**
 * Centered logic for Vercel Cron / External Cron triggers
 */
exports.syncAll = async (req, res) => {
    // 1. Security Check
    const authHeader = req.headers['authorization'];
    const cronSecret = process.env.CRON_SECRET;

    // If a secret is set in environment, enforce it
    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
        return res.status(401).json({ message: 'Unauthorized: Invalid Cron Secret' });
    }

    console.log('[Cron] Execution started...');
    const results = { prices: 0, fairValues: 0 };
    const startTime = Date.now();

    try {
        // --- TASK 1: Prices (High Priority) ---
        // We attempt the price update first.
        // NOTE: On Vercel Hobby (10s limit), Puppeteer login + scrape is very tight.
        try {
            console.log('[Cron] Attempting price sync...');
            results.prices = await mubasherTradeService.updatePrices();
        } catch (err) {
            console.error('[Cron] Price sync failed:', err.message);
        }

        // --- TASK 2: Fair Values (Drip) ---
        // Only if we have time left (e.g., spent < 7s so far)
        const elapsed = Date.now() - startTime;
        if (elapsed < 7000) {
            try {
                console.log('[Cron] Attempting fair-value drip...');
                results.fairValues = await scraperService.scrapeAllArabicStocks({
                    staleOnly: true,
                    limit: 3, // Small batch to stay within time limits
                    noDelay: true
                });
            } catch (err) {
                console.error('[Cron] Fair-value drip failed:', err.message);
            }
        }

        res.json({
            status: 'success',
            results,
            elapsed_ms: Date.now() - startTime
        });

    } catch (error) {
        console.error('[Cron] Global Error:', error.message);
        res.status(500).json({ status: 'error', message: error.message });
    }
};
