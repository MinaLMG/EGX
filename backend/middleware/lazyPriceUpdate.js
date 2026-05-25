const ConfigHelper = require('../utils/configHelper');
const mubasherTradeService = require('../services/mubasherTradeService');

// Separate in-memory locks to prevent overlapping background tasks
let isPriceUpdateInProgress = false;
let isArabScrapeInProgress = false;

/**
 * Lazy Update Middleware
 * Dynamically handles both Price and Fair-Value updates in the background.
 */
module.exports = async (req, res, next) => {
    // 1. Skip if it's a request to the admin trigger itself to avoid recursion
    if (req.path.includes('/api/cron') || req.path.includes('/api/mubasher/trigger')) {
        return next();
    }

    try {
        const now = new Date();
        const cairoNow = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));

        // 2. ArabicStock Fair Value "Smart Drip"
        // Instead of a daily block, we update small batches (5) whenever stale stocks are found.
        if (!isArabScrapeInProgress) {
            const scraperService = require('../services/scraperService');
            
            // Set the lock immediately
            isArabScrapeInProgress = true; 

            setImmediate(async () => {
                try {
                    // Check for stocks not updated in > 24 hours
                    const updatedCount = await scraperService.scrapeAllArabicStocks({ 
                        staleOnly: true, 
                        limit: 5, 
                        noDelay: true 
                    });
                    
                    if (updatedCount > 0) {
                        console.log(`[LazyUpdate] Smart Drip: ${updatedCount} stale stocks refreshed.`);
                    }
                } catch (err) {
                    console.error('[LazyUpdate] Background Drip scrape failed:', err.message);
                } finally {
                    // Always release internal lock
                    isArabScrapeInProgress = false;
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
            return next();
        }

        // 4. Price Update Logic
        // Checks if a price refresh is already in progress or happens too frequently.
        if (!isPriceUpdateInProgress) {
            const lastUpdateStr = await ConfigHelper.getSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, "0");
            const lastUpdate = new Date(lastUpdateStr);
            const diffInMs = now - lastUpdate;

            if (diffInMs >= 60000) {
                isPriceUpdateInProgress = true;
                console.log(`[LazyUpdate] Scheduling price update (${Math.round(diffInMs / 1000)}s since last)`);

                setImmediate(async () => {
                    try {
                        await ConfigHelper.setSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, now.toISOString());
                        console.log('[LazyUpdate] Starting price scraper...');
                        const count = await mubasherTradeService.updatePrices();
                        console.log(`[LazyUpdate] Price update finished: ${count} stocks updated.`);
                    } catch (err) {
                        console.error('[LazyUpdate] Background price task failed:', err.message);
                    } finally {
                        isPriceUpdateInProgress = false;
                    }
                });
            }
        }

    } catch (error) {
        console.error('[LazyUpdate] Middleware error:', error.message);
        // Ensure locks don't stay stuck if sync code fails
        isPriceUpdateInProgress = false;
        isArabScrapeInProgress = false;
    }

    next();
};
