const ConfigHelper = require('../utils/configHelper');
const mubasherTradeService = require('../services/mubasherTradeService');
const scraperService = require('../services/scraperService');

// Shared security check helper
const checkAuth = (req) => {
    const authHeader = req.headers['authorization'];
    const cronSecret = process.env.CRON_SECRET;
    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) return false;
    return true;
};

/**
 * TASK 1: Prices Only (Fastest, High Priority)
 */
exports.syncPrices = async (req, res) => {
    if (!checkAuth(req)) return res.status(401).json({ message: 'Unauthorized' });

    console.log('[Cron] Price-only sync started...');
    const startTime = Date.now();

    try {
        const results = await mubasherTradeService.updatePrices();
        res.json({
            status: 'success',
            type: 'prices',
            count: results,
            elapsed_ms: Date.now() - startTime
        });
    } catch (error) {
        console.error('[Cron] Price sync error:', error.message);
        res.status(500).json({ status: 'error', message: error.message });
    }
};

/**
 * TASK 2: Fair Value Drip Only (Slower, Low Priority)
 */
exports.syncFairValues = async (req, res) => {
    if (!checkAuth(req)) return res.status(401).json({ message: 'Unauthorized' });

    console.log('[Cron] Fair-value drip started...');
    const startTime = Date.now();

    try {
        const results = await scraperService.scrapeAllArabicStocks({
            noDelay: true
        });
        res.json({
            status: 'success',
            type: 'fair-values',
            count: results,
            elapsed_ms: Date.now() - startTime
        });
    } catch (error) {
        console.error('[Cron] Fair-value drip error:', error.message);
        res.status(500).json({ status: 'error', message: error.message });
    }
};

/**
 * Legacy: Keep syncAll for general maintenance
 */
exports.syncAll = async (req, res) => {
    if (!checkAuth(req)) return res.status(401).json({ message: 'Unauthorized' });

    // We can just call the others internally or keep the existing combined logic
    // For now, let's keep it simple and just run both in sequence for a "Deep Sync"
    console.log('[Cron] Deep Sync All started...');
    const start = Date.now();
    let p = 0, f = 0;
    try { p = await mubasherTradeService.updatePrices(); } catch (e) { }
    try { f = await scraperService.scrapeAllArabicStocks({ staleOnly: true, limit: 3 }); } catch (e) { }

    res.json({ status: 'success', prices: p, fairValues: f, elapsed: Date.now() - start });
};
