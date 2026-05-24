const SystemConfig = require('../models/SystemConfig');

/**
 * Gets a system setting by key with a fallback value
 */
exports.getSetting = async (key, defaultValue) => {
    try {
        const config = await SystemConfig.findOne({ key });
        return config ? config.value : defaultValue;
    } catch (err) {
        return defaultValue;
    }
};

/**
 * Common settings keys
 */
exports.KEYS = {
    SCORING_WEIGHTS: 'scoring_weights',
    SCRAPER_DELAY: 'scraper_delay',
    HTTP_TIMEOUT: 'http_timeout',
    USER_AGENT: 'user_agent',
    GRAHAM_CONSTANT: 'graham_constant',
    MARKET_START_HOUR: 'market_start_hour',
    MARKET_END_HOUR: 'market_end_hour',
    MARKET_END_MINUTE: 'market_end_minute'
};
