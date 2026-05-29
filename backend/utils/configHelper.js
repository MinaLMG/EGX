const SystemConfig = require('../models/SystemConfig');

// In-memory cache: { key -> { value, expiresAt } }
const _cache = new Map();
const CACHE_TTL_MS = 30_000; // 30 seconds

/**
 * Gets a system setting by key with a fallback value.
 * Results are cached in memory for 30s to avoid per-request DB hits.
 */
exports.getSetting = async (key, defaultValue) => {
    const now = Date.now();
    const cached = _cache.get(key);
    if (cached && cached.expiresAt > now) return cached.value;

    try {
        const config = await SystemConfig.findOne({ key });
        const value = config ? config.value : defaultValue;
        _cache.set(key, { value, expiresAt: now + CACHE_TTL_MS });
        return value;
    } catch (err) {
        return defaultValue;
    }
};

/**
 * Sets or updates a system setting and immediately invalidates the cache.
 */
exports.setSetting = async (key, value) => {
    try {
        await SystemConfig.findOneAndUpdate(
            { key },
            { value, key },
            { upsert: true, returnDocument: 'after' }
        );
        _cache.delete(key); // Invalidate so next read is fresh
        return true;
    } catch (err) {
        return false;
    }
};

/**
 * Common settings keys
 */
exports.KEYS = {
    SCRAPER_DELAY: 'scraper_delay',
    HTTP_TIMEOUT: 'http_timeout',
    USER_AGENT: 'user_agent',
    GRAHAM_CONSTANT: 'graham_constant',
    MARKET_START_HOUR: 'market_start_hour',
    MARKET_END_HOUR: 'market_end_hour',
    MARKET_END_MINUTE: 'market_end_minute',
    MUBASHER_TRADE_UPDATE_INTERVAL: 'mubasher_trade_update_interval',
    STEEP_SCORING_WEIGHTS: 'steep_scoring_weights',
    LEGACY_SCORING_WEIGHTS: 'legacy_scoring_weights'
};
