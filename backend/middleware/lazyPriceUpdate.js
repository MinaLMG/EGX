const ConfigHelper = require('../utils/configHelper');
const mubasherTradeService = require('../services/mubasherTradeService');

// In-memory flag to prevent the SAME process from firing multiple updates at once
let isUpdateInProgress = false;

/**
 * Lazy Update Middleware
 * Checks if prices need updating and triggers it in the background
 */
module.exports = async (req, res, next) => {
    // 1. Skip if it's a request to the admin trigger itself to avoid recursion
    if (req.path.includes('/api/cron') || req.path.includes('/api/mubasher/trigger')) {
        return next();
    }

    // Prevent overlapping or rapid concurrent entry
    if (isUpdateInProgress) {
        return next();
    }

    isUpdateInProgress = true; // Set lock immediately

    try {
        const now = new Date();
        const cairoNow = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));

        // 2. Market Hours Check (9:50 - 20:30 Cairo)
        const day = cairoNow.getDay();
        const hours = cairoNow.getHours();
        const minutes = cairoNow.getMinutes();

        const isWorkingDay = day >= 0 && day <= 4;
        const isWorkingHour = (hours > 9 || (hours === 9 && minutes >= 50)) && (hours < 15);

        if (!isWorkingDay || !isWorkingHour) {
            isUpdateInProgress = false;
            return next();
        }

        // 3. Throttle Check (Update every 1 minute)
        const lastUpdateStr = await ConfigHelper.getSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, "0");
        const lastUpdate = new Date(lastUpdateStr);
        const diffInMs = now - lastUpdate;

        if (diffInMs < 60000) {
            isUpdateInProgress = false;
            return next();
        }

        console.log(`[LazyUpdate] Scheduling background update (Last update was ${Math.round(diffInMs / 1000)}s ago)`);

        setImmediate(async () => {
            try {
                // Update the timestamp first
                await ConfigHelper.setSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, now.toISOString());

                // Perform the update
                console.log('[LazyUpdate] Starting background price scraper (Mubasher Trade)...');
                const count = await mubasherTradeService.updatePrices();
                console.log(`[LazyUpdate] Background price update finished: ${count} stocks updated.`);
            } catch (err) {
                console.error('[LazyUpdate] Background task failed:', err.message);
            } finally {
                // Always release the lock
                isUpdateInProgress = false;
            }
        });

    } catch (error) {
        console.error('[LazyUpdate] Middleware error:', error.message);
        isUpdateInProgress = false; // Emergency release if error occurs before setImmediate
    }

    next();
};
