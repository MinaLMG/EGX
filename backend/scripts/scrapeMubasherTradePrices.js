/**
 * runScraper.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Market-hours price-scraping loop.
 *
 * Usage:  node scripts/runScraper.js
 *
 * Behaviour:
 *   • Connects to MongoDB once.
 *   • Loops: scrape → wait INTERVAL_MS → scrape → …
 *   • Automatically stops at MARKET_CLOSE_TIME (14:30 UTC+3 / 11:30 UTC).
 *   • Exits with code 0 on clean finish, 1 on fatal error.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '../.env') });

const mubasherTradeService = require('../services/mubasherTradeService');
const ConfigHelper = require('../utils/configHelper');

// ── Configuration ─────────────────────────────────────────────────────────────
const TIMEZONE_OFFSET_MS = 3 * 60 * 60 * 1000; // UTC+3

// Market close: 14:30 local (UTC+3)  →  11:30 UTC
const CLOSE_HOUR_UTC = 11;
const CLOSE_MINUTE_UTC = 30;

// Delay between scrape cycles (ms). Mubasher itself takes ~3-5 min per run.
const INTERVAL_MS = 45 * 1000; // 45 seconds waiting between attempts

// ── Helpers ───────────────────────────────────────────────────────────────────
function nowUTC() {
    return new Date();
}

function isAfterMarketClose() {
    const now = nowUTC();
    const closeToday = new Date(
        Date.UTC(
            now.getUTCFullYear(),
            now.getUTCMonth(),
            now.getUTCDate(),
            CLOSE_HOUR_UTC,
            CLOSE_MINUTE_UTC,
            0
        )
    );
    return now >= closeToday;
}

function formatLocal(date) {
    // Pretty-print in UTC+3 for readable logs
    const local = new Date(date.getTime() + TIMEZONE_OFFSET_MS);
    return local.toISOString().replace('T', ' ').slice(0, 19) + ' (UTC+3)';
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// ── Main loop ─────────────────────────────────────────────────────────────────
async function main() {
    console.log(`[Scraper] Starting at ${formatLocal(nowUTC())}`);
    console.log(`[Scraper] Will stop after ${CLOSE_HOUR_UTC + 3}:${String(CLOSE_MINUTE_UTC).padStart(2, '0')} local (UTC+3)`);

    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('[Scraper] MongoDB connected.');
    } catch (err) {
        console.error('[Scraper] MongoDB connection failed:', err.message);
        process.exit(1);
    }

    let cycle = 0;
    const waitSeconds = await ConfigHelper.getSetting(ConfigHelper.KEYS.MUBASHER_TRADE_UPDATE_INTERVAL, 45);
    console.log(`[Scraper] Using update interval: ${waitSeconds}s (DB Setting)`);

    while (true) {
        //stop if after working times
        if (isAfterMarketClose()) {
            console.log(`[Scraper] Market closed (${formatLocal(nowUTC())}). Exiting cleanly.`);
            break;
        }
        cycle++;
        console.log(`\n[Scraper] ── Cycle #${cycle} started at ${formatLocal(nowUTC())} ──`);

        try {
            const count = await mubasherTradeService.updatePrices();
            console.log(`[Scraper] Cycle #${cycle} done — ${count} stocks updated.`);
        } catch (err) {
            console.error(`[Scraper] Cycle #${cycle} error: ${err.message}`);
            // Don't exit on a single cycle failure; keep looping until close time.
        }



        console.log(`[Scraper] Waiting ${waitSeconds} seconds before next cycle…`);
        await sleep(waitSeconds * 1000);
    }

    try {
        await mubasherTradeService.closeBrowser();
        await mongoose.disconnect();
        console.log('[Scraper] Session finished. MongoDB disconnected. Goodbye.');
    } catch (_) { }

    process.exit(0);
}

main();
