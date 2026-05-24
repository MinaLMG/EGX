const ConfigHelper = require('../utils/configHelper');
const mubasherPriceService = require('../services/mubasherPriceService');

/**
 * Lazy Update Middleware
 * Checks if prices need updating and triggers it in the background
 */
module.exports = async (req, res, next) => {
    // 1. Skip if it's a request to the admin trigger itself to avoid recursion
    if (req.path.includes('/api/cron') || req.path.includes('/api/mubasher/trigger')) {
        return next();
    }

    try {
        const now = new Date();
        const cairoNow = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));
        
        // 2. Market Hours Check (9:50 - 14:30 Cairo)
        const day = cairoNow.getDay(); // 0 (Sun) to 4 (Thu) are working days
        const hours = cairoNow.getHours();
        const minutes = cairoNow.getMinutes();

        const isWorkingDay = day >= 0 && day <= 4;
        const isWorkingHour = (hours > 9 || (hours === 9 && minutes >= 50)) && (hours < 14 || (hours === 14 && minutes <= 30));

        if (!isWorkingDay || !isWorkingHour) {
            return next();
        }

        // 3. Throttle Check (Update every 1 minute)
        const lastUpdateStr = await ConfigHelper.getSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, "0");
        const lastUpdate = new Date(lastUpdateStr);
        const diffInMs = now - lastUpdate;

        if (diffInMs > 60000) { // 1 minute
            console.log(`[LazyUpdate] Triggering background update (Last update was ${Math.round(diffInMs/1000)}s ago)`);
            
            // Update the timestamp immediately to prevent other concurrent requests from triggering
            await ConfigHelper.setSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, now.toISOString());

            // Trigger update in background (don't await)
            mubasherPriceService.updatePricesFromMubasher().catch(err => {
                console.error('[LazyUpdate] Background update failed:', err.message);
            });
        }
    } catch (error) {
        console.error('[LazyUpdate] Middleware error:', error.message);
    }

    next();
};
