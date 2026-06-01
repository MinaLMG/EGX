const Stock = require('../models/Stock');
const ScoringService = require('./scoringService');
const ConfigHelper = require('../utils/configHelper');

/**
 * Mubasher Trade Service - Scrapes real-time prices with high resilience
 */
class MubasherTradeService {
    constructor() {
        this.browser = null;
        this.page = null;
        this.isMonitoring = false;
    }

    /**
     * Initializes the browser. 
     * Handles the complex configuration required to run Puppeteer on Vercel.
     */
    async initBrowser() {
        if (this.browser && this.page) return;

        let puppeteer;
        let launchOptions = {
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-web-security', '--disable-features=IsolateOrigins,site-per-process'],
            headless: "new"
        };

        try {
            if (process.env.VERCEL) {
                // VERCEL-SPECIFIC LOADING
                // Use dynamic imports to support ESM packages on Vercel
                console.log('Mubasher: Configuring browser for Vercel/Serverless...');
                const chromium = (await import('@sparticuz/chromium')).default;
                const { default: p } = await import('puppeteer-core');
                puppeteer = p;

                launchOptions.executablePath = await chromium.executablePath();
                launchOptions.args = [...chromium.args, ...launchOptions.args];
            } else {
                // LOCAL/VPS LOADING
                console.log('Mubasher: Configuring browser for Local/Standard environment...');
                const { default: p } = await import('puppeteer');
                puppeteer = p;
            }

            this.browser = await puppeteer.launch(launchOptions);
            this.page = await this.browser.newPage();

            this.page.on('console', msg => {
                const txt = msg.text();
                if (txt.includes('Extraction') || txt.includes('Items:')) console.log('Mubasher:', txt);
            });

            await this.page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
            await this.page.setViewport({ width: 1440, height: 900 });

        } catch (err) {
            this.isMonitoring = false;
            console.error('Mubasher: Browser initialization failed.');
            console.error('NOTE: If running on Vercel, ensured you have "puppeteer-core" and "@sparticuz/chromium" installed.');
            console.error('Error:', err.message);
            throw err;
        }
    }

    async login() {
        const username = process.env.MUBASHER_TRADE_USERNAME;
        const password = process.env.MUBASHER_TRADE_PASSWORD;

        if (!username || !password) {
            console.error('Mubasher: MISSING CREDENTIALS! Please set MUBASHER_TRADE_USERNAME and MUBASHER_TRADE_PASSWORD.');
            return;
        }

        console.log('Logging in to Mubasher Trade...');
        await this.page.goto('https://rubixegypt.mubashertrade.com/web/login', {
            waitUntil: 'domcontentloaded',
            timeout: 60000
        });

        try {
            await this.page.waitForSelector('#form-input-live-u', { timeout: 30000 });
            await this.page.type('#form-input-live-u', username, { delay: 50 });
            await this.page.type('#form-input-live-p', password, { delay: 50 });
            await new Promise(r => setTimeout(r, 1000));
            await this.page.keyboard.press('Enter');
            await this.page.waitForFunction(() => window.location.href.includes('/secure/'), { timeout: 60000 });
            console.log('Mubasher Login success.');
            await new Promise(r => setTimeout(r, 15000)); // Allow session to settle
        } catch (e) {
            console.warn('Mubasher Login Warning:', e.message);
        }
    }

    async performUpdateCycle() {
        console.log('Mubasher: Starting price update cycle...');
        const priceData = await this.page.evaluate(async () => {
            const nav = () => {
                const btn = Array.from(document.querySelectorAll('div, span, mat-list-item'))
                    .find(d => d.innerText?.trim() === 'Watchlist');
                if (btn) { btn.click(); return true; }
                return false;
            };

            for (let i = 0; i < 3; i++) {
                nav();
                await new Promise(r => setTimeout(r, i === 0 ? 15000 : 8000));
                if (document.querySelectorAll('.ag-row').length > 0) break;
            }

            const viewport = document.querySelector('.ag-body-viewport, .ag-center-cols-viewport') ||
                Array.from(document.querySelectorAll('div')).find(d => d.scrollHeight > d.clientHeight && d.className.includes('ag-'));

            const headers = Array.from(document.querySelectorAll('.ag-header-cell'));
            let sCol = "0", pCol = "1";
            headers.forEach(h => {
                const t = h.innerText?.toLowerCase() || '';
                const id = h.getAttribute('col-id');
                if (t.includes('symbol')) sCol = id;
                if (t.includes('last') || (t.includes('price') && !t.includes('change'))) pCol = id;
            });

            const results = new Map();
            const scan = () => {
                document.querySelectorAll('.ag-row').forEach(row => {
                    const id = row.getAttribute('row-id') || row.getAttribute('aria-rowindex');
                    if (!id) return;
                    if (!results.has(id)) results.set(id, { ticker: null, price: null });
                    const entry = results.get(id);
                    const tCell = row.querySelector(`[col-id="${sCol}"]`) || row.querySelector('[col-id="0"]');
                    const pCell = row.querySelector(`[col-id="${pCol}"]`) || row.querySelector('[col-id="1"]');
                    if (tCell && !entry.ticker) {
                        const rawTicker = tCell.innerText.trim().split(/\s/)[0];
                        if (rawTicker.length > 1) entry.ticker = rawTicker;
                    }
                    if (pCell && entry.price === null) {
                        const rawPrice = pCell.innerText.trim().replace(/,/g, '');
                        const p = parseFloat(rawPrice);
                        if (!isNaN(p)) entry.price = p;
                    }
                });
            };

            for (let j = 0; j < 5; j++) {
                scan();
                if (Array.from(results.values()).some(v => v.ticker && v.price)) break;
                await new Promise(r => setTimeout(r, 2000));
            }

            let last = -1, iters = 0;
            if (viewport) {
                while (viewport.scrollTop !== last && iters < 200) {
                    last = viewport.scrollTop;
                    scan();
                    viewport.scrollTop += 400;
                    await new Promise(r => setTimeout(r, 600));
                    iters++;
                }
            } else {
                scan();
            }

            const final = Array.from(results.values()).filter(v => v.ticker && v.price !== null);
            return final;
        });

        if (!priceData || priceData.length === 0) return 0;

        const now = new Date();
        const bulkOps = priceData.map(item => ({
            updateOne: {
                filter: { ticker: item.ticker.toUpperCase() },
                update: { $set: { price: item.price, lastUpdated: now } },
                upsert: true
            }
        }));

        const result = await Stock.bulkWrite(bulkOps);
        const updated = (result.modifiedCount || 0) + (result.upsertedCount || 0);
        console.log(`Mubasher: Successfully saved ${updated} prices to the database.`);

        if (updated > 0) {
            clearTimeout(this._scoreDebounce);
            this._scoreDebounce = setTimeout(() => ScoringService.calculateAllScores(), 2000);
        }

        return updated;
    }

    async updatePrices() {
        if (this.isMonitoring) {
            console.log('Mubasher: Scrape already in progress, skipping...');
            return 0;
        }

        try {
            this.isMonitoring = true;
            await this.initBrowser();
            if (!this.page) throw new Error('Puppeteer page failed to initialize');

            const url = await this.page.url();
            if (url.includes('/login') || !url.includes('/secure/')) await this.login();

            return await this.performUpdateCycle();
        } catch (e) {
            console.error('Mubasher Trade Service Error:', e.message);
            throw e;
        } finally {
            this.isMonitoring = false;
        }
    }

    /**
     * Cleanly closes the browser. Called by external runners (e.g. runScraper.js)
     * after a full market session is complete.
     */
    async closeBrowser() {
        if (this.browser) {
            try {
                await this.browser.close();
                console.log('Mubasher: Browser closed.');
            } catch (e) {
                console.warn('Mubasher: Error closing browser:', e.message);
            } finally {
                this.browser = null;
                this.page = null;
                this.isMonitoring = false;
            }
        }
    }
}

module.exports = new MubasherTradeService();
