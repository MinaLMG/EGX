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

        // 2. Daily Fair Value Scraping (Every 24 hours) check
        // This runs regardless of market hours because fair values update independently.
        const lastArabScrapeStr = await ConfigHelper.getSetting('LAST_ARABSTOCK_SCRAPE', "0");
        const lastArabScrape = new Date(lastArabScrapeStr);
        const timeSinceArabScrape = now - lastArabScrape;

        if (timeSinceArabScrape >= 24 * 60 * 60 * 1000) {
            console.log(`[LazyUpdate] Triggering background ArabicStock scrape (Last was ${Math.round(timeSinceArabScrape / (1000 * 60 * 60))}h ago)`);
            
            // Set timestamp early to avoid overlaps while worker runs
            await ConfigHelper.setSetting('LAST_ARABSTOCK_SCRAPE', now.toISOString());

            setImmediate(async () => {
                try {
                    const scraperService = require('../services/scraperService');
                    console.log('[LazyUpdate] Starting background fair-value scraper (ArabicStock)...');
                    // Fast incremental scrape: up to 50 stale stocks per request, no artificial delay on Vercel
                    await scraperService.scrapeAllArabicStocks({ staleOnly: true, limit: 50, noDelay: true });
                    console.log('[LazyUpdate] Background fair-value update finished.');
                } catch (err) {
                    console.error('[LazyUpdate] Background ArabStock scrape failed:', err.message);
                }
            });
        }

        // 3. Market Hours Check (9:50 - 15:00 Cairo) for PRICE updates
        const day = cairoNow.getDay();
        const hours = cairoNow.getHours();
        const minutes = cairoNow.getMinutes();

        const isWorkingDay = day >= 0 && day <= 4;
        const isWorkingHour = (hours > 9 || (hours === 9 && minutes >= 50)) && (hours < 15);

        if (!isWorkingDay || !isWorkingHour) {
            isUpdateInProgress = false;
            return next();
        }

        // 4. Price Throttle Check (Update every 1 minute)
        const lastUpdateStr = await ConfigHelper.getSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, "0");
        const lastUpdate = new Date(lastUpdateStr);
        const diffInMs = now - lastUpdate;

        if (diffInMs < 60000) {
            isUpdateInProgress = false;
            return next();
        }

        console.log(`[LazyUpdate] Scheduling background price update (Last update was ${Math.round(diffInMs / 1000)}s ago)`);

        setImmediate(async () => {
            try {
                // Update the timestamp first
                await ConfigHelper.setSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, now.toISOString());

                // Perform the update
                console.log('[LazyUpdate] Starting background price scraper (Mubasher Trade)...');
                const count = await mubasherTradeService.updatePrices();
                console.log(`[LazyUpdate] Background price update finished: ${count} stocks updated.`);
            } catch (err) {
                console.error('[LazyUpdate] Background price task failed:', err.message);
            } finally {
                // Release the global middle-ware lock after the price check
                isUpdateInProgress = false;
            }
        });

    } catch (error) {
        console.error('[LazyUpdate] Middleware error:', error.message);
        isUpdateInProgress = false; 
    }

    next();
};
