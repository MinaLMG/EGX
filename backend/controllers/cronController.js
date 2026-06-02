const axios = require('axios');
const ConfigHelper = require('../utils/configHelper');

// Shared security check helper
const checkAuth = (req) => {
    const authHeader = req.headers['authorization'];
    const cronSecret = process.env.CRON_SECRET;
    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) return false;
    if (!cronSecret) return false;
    return true;
};

/**
 * Triggers the GitHub Action: Live Prices (Mubasher)
 */
exports.triggerMubasherPrices = async (req, res) => {
    if (!checkAuth(req)) return res.status(401).json({ message: 'Unauthorized' });

    console.log('[Trigger] Waking up Mubasher Live Price Scraper...');

    const GITHUB_PAT = process.env.GITHUB_PAT;
    const REPO_OWNER = 'MinaLMG';
    const REPO_NAME = 'EGX';

    if (!GITHUB_PAT) {
        return res.status(500).json({ status: 'error', message: 'GITHUB_PAT not configured' });
    }

    try {
        const response = await axios.post(
            `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/dispatches`,
            { event_type: 'trigger-mubasher-prices' },
            {
                headers: {
                    'Authorization': `token ${GITHUB_PAT}`,
                    'Accept': 'application/vnd.github.v3+json'
                }
            }
        );

        console.log(`[Trigger] GitHub responded with status: ${response.status}`);
        res.json({ status: 'success', message: 'Mubasher Prices triggered successfully', code: response.status });
    } catch (error) {
        console.error('[Trigger] GitHub API Error (Mubasher):', error.response?.data || error.message);
        res.status(500).json({
            status: 'error',
            message: 'Failed to trigger Mubasher GitHub',
            details: error.response?.data || error.message
        });
    }
};

/**
 * Triggers the GitHub Action: Fair Values (ArabicStock)
 */
exports.triggerArabicStockValues = async (req, res) => {
    if (!checkAuth(req)) return res.status(401).json({ message: 'Unauthorized' });

    console.log('[Trigger] Waking up ArabicStock Fair Value Scraper...');

    const GITHUB_PAT = process.env.GITHUB_PAT;
    const REPO_OWNER = 'MinaLMG';
    const REPO_NAME = 'EGX';

    if (!GITHUB_PAT) {
        return res.status(500).json({ status: 'error', message: 'GITHUB_PAT not configured' });
    }

    try {
        const response = await axios.post(
            `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/dispatches`,
            { event_type: 'trigger-arabicstock-values' },
            {
                headers: {
                    'Authorization': `token ${GITHUB_PAT}`,
                    'Accept': 'application/vnd.github.v3+json'
                }
            }
        );

        console.log(`[Trigger] GitHub responded with status: ${response.status}`);
        res.json({ status: 'success', message: 'ArabicStock Values triggered successfully', code: response.status });
    } catch (error) {
        console.error('[Trigger] GitHub API Error (ArabicStock):', error.response?.data || error.message);
        res.status(500).json({
            status: 'error',
            message: 'Failed to trigger ArabicStock GitHub',
            details: error.response?.data || error.message
        });
    }
};
