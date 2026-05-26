const axios = require('axios');
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

/**
 * NEW: Triggers the GitHub Action Scraper via API
 * This allows us to use an external pinger (cron-job.org) to start the heavy
 * 5-hour scraper on GitHub without hitting Vercel timeouts or CPU limits.
 */
exports.triggerGitHubScraper = async (req, res) => {
    if (!checkAuth(req)) return res.status(401).json({ message: 'Unauthorized' });

    console.log('[Trigger] Waking up GitHub Scraper...');
    
    const GITHUB_PAT = process.env.GITHUB_PAT;
    const REPO_OWNER = 'MinaLMG';
    const REPO_NAME = 'EGX';

    if (!GITHUB_PAT) {
        return res.status(500).json({ status: 'error', message: 'GITHUB_PAT not configured' });
    }

    try {
        await axios.post(
            `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/dispatches`,
            { event_type: 'trigger-scraper' },
            {
                headers: {
                    'Authorization': `token ${GITHUB_PAT}`,
                    'Accept': 'application/vnd.github.v3+json'
                }
            }
        );

        res.json({ status: 'success', message: 'GitHub Action triggered successfully' });
    } catch (error) {
        console.error('[Trigger] GitHub API Error:', error.response?.data || error.message);
        res.status(500).json({ 
            status: 'error', 
            message: 'Failed to trigger GitHub',
            details: error.response?.data || error.message
        });
    }
};
