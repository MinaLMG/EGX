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

    // Call next() IMMEDIATELY so the user doesn't wait for the background logic
    // We will handle the background tasks in the next tick of the event loop.
    next();

    // 2. Wrap everything in setImmediate so it doesn't block the stack of the current request
    setImmediate(async () => {
        try {
            const now = new Date();
            const cairoNow = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));

            // --- PRIORITY 1: REAL-TIME PRICES (MubasherTrade) ---
            if (!isPriceUpdateInProgress) {
                isPriceUpdateInProgress = true;
                try {
                    const day = cairoNow.getDay();
                    const hours = cairoNow.getHours();
                    const minutes = cairoNow.getMinutes();
                    const isWorkingDay = day >= 0 && day <= 4;
                    const isWorkingHour = (hours > 9 || (hours === 9 && minutes >= 50)) && (hours < 15);

                    if (isWorkingDay && isWorkingHour) {
                        const lastUpdateStr = await ConfigHelper.getSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, "0");
                        const lastUpdate = new Date(lastUpdateStr);
                        
                        // Update if > 1 minute has passed
                        if (now - lastUpdate >= 60000) {
                            await ConfigHelper.setSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, now.toISOString());
                            console.log(`[LazyUpdate] Starting price update (Market is Open)`);
                            await mubasherTradeService.updatePrices();
                        }
                    }
                } catch (err) {
                    console.error('[LazyUpdate] Background price task failed:', err.message);
                } finally {
                    isPriceUpdateInProgress = false;
                }
            }

            // --- PRIORITY 2: FAIR VALUES (ArabicStock) ---
            // Only attempt ArabStock drip if price update isn't currently running, 
            // to prioritize CPU/Network for real-time prices.
            if (!isArabScrapeInProgress && !isPriceUpdateInProgress) {
                isArabScrapeInProgress = true;
                try {
                    const scraperService = require('../services/scraperService');
                    // scrapeAllArabicStocks handles its own internal "stale" logic
                    const updatedCount = await scraperService.scrapeAllArabicStocks({ 
                        staleOnly: true, 
                        limit: 5, 
                        noDelay: true 
                    });
                    
                    if (updatedCount > 0) {
                        console.log(`[LazyUpdate] Smart Drip: ${updatedCount} stale fair-values refreshed.`);
                    }
                } catch (err) {
                    console.error('[LazyUpdate] Background Drip scrape failed:', err.message);
                } finally {
                    isArabScrapeInProgress = false;
                }
            }

        } catch (error) {
            console.error('[LazyUpdate] Global lazy background error:', error.message);
            isPriceUpdateInProgress = false;
            isArabScrapeInProgress = false;
        }
    });
};
