const puppeteer = require('puppeteer');
const Stock = require('../models/Stock');
const ScoringService = require('./scoringService');
const ConfigHelper = require('../utils/configHelper');

/**
 * Mubasher Trade Service - Scrapes real-time prices using Puppeteer with credentials
 */
class MubasherTradeService {
    constructor() {
        this.browser = null;
        this.page = null;
    }

    async initBrowser() {
        if (this.browser) return;

        console.log('Launching browser for Mubasher Trade...');
        this.browser = await puppeteer.launch({
            headless: "new",
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-web-security']
        });
        this.page = await this.browser.newPage();
        await this.page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
        await this.page.setViewport({ width: 1440, height: 900 });
    }

    async login() {
        const username = process.env.MUBASHER_TRADE_USERNAME;
        const password = process.env.MUBASHER_TRADE_PASSWORD;

        if (!username || !password) {
            throw new Error('MUBASHER_TRADE_USERNAME or MUBASHER_TRADE_PASSWORD not found in environment');
        }

        console.log('Navigating to Mubasher Trade login...');
        await this.page.goto('https://rubixegypt.mubashertrade.com/web/secure/one-stop-trade', {
            waitUntil: 'networkidle0',
            timeout: 60000
        });

        // Wait for login fields
        await this.page.waitForSelector('#form-input-live-u');

        console.log('Entering credentials...');
        await this.page.type('#form-input-live-u', username, { delay: 150 });
        await this.page.type('#form-input-live-p', password, { delay: 150 });

        await new Promise(r => setTimeout(r, 1500));
        console.log('Submitting login via Enter key...');
        await this.page.keyboard.press('Enter');

        console.log('Waiting for authentication...');
        try {
            await Promise.race([
                this.page.waitForSelector('#watchlist-body-container, app-dashboard', { timeout: 60000 }),
                this.page.waitForFunction(() => window.location.href.includes('/secure/'), { timeout: 60000 }),
                this.page.waitForFunction(() => {
                    const el = document.querySelector('#rejectReason');
                    return el && el.innerText.trim().length > 0 && !el.innerText.includes('Authenticating');
                }, { timeout: 60000 })
            ]);

            const url = this.page.url();
            if (url.includes('/login')) {
                const rejectMsg = await this.page.evaluate(() => {
                    const el = document.querySelector('#rejectReason');
                    return el ? el.innerText.trim() : null;
                });
                if (rejectMsg && !rejectMsg.includes('Authenticating')) {
                    console.log('Login rejected by site:', rejectMsg);
                    throw new Error(`Mubasher Login Rejected: ${rejectMsg}`);
                }
            }
            console.log('Authentication confirmed at URL:', url);
        } catch (e) {
            console.log('Authentication failed. URL:', this.page.url());
            throw e;
        }
        console.log('Allowing session to settle and background tasks to complete...');
        await new Promise(r => setTimeout(r, 15000));
    }

    async startMonitoring() {
        if (this.isMonitoring) {
            console.log('Mubasher monitoring is already active.');
            return;
        }

        console.log('Starting daily Mubasher Trade monitoring session...');
        this.isMonitoring = true;
        this.shouldStop = false;

        try {
            await this.initBrowser();
            await this.ensureLoggedIn();

            while (!this.shouldStop) {
                const cairoTime = new Date(new Date().toLocaleString('en-US', { timeZone: 'Africa/Cairo' }));
                const hours = cairoTime.getHours();
                const minutes = cairoTime.getMinutes();

                if (hours > 14 || (hours === 14 && minutes >= 45)) {
                    console.log('Market hours ended. Closing monitoring session.');
                    break;
                }

                console.log(`[${cairoTime.toLocaleTimeString()}] Performing price update cycle...`);
                try {
                    await this.performUpdateCycle();
                } catch (e) {
                    console.error('Update cycle error, attempting recovery...', e.message);
                    await new Promise(r => setTimeout(r, 5000));
                    await this.ensureLoggedIn(); 
                }

                await new Promise(r => setTimeout(r, 60000));
            }
        } catch (error) {
            console.error('Critical monitoring error:', error);
        } finally {
            this.isMonitoring = false;
            await this.stopSession();
        }
    }

    async ensureLoggedIn() {
        try {
            const url = this.page.url();
            if (url.includes('/login') || !url.includes('/secure/')) {
                console.log('Not logged in or session lost. Re-authenticating...');
                await this.login();
            } else {
                const onLogin = await this.page.evaluate(() => !!document.querySelector('#form-input-live-u'));
                if (onLogin) {
                    console.log('Login form detected. Re-authenticating...');
                    await this.login();
                }
            }
        } catch (e) {
            await this.login();
        }
    }

    async performUpdateCycle() {
        let gridFound = await this.page.evaluate(() => !!document.querySelector('ag-grid-angular'));
        if (!gridFound) {
            console.log('Grid missing, navigating to secure landing...');
            await this.page.goto('https://rubixegypt.mubashertrade.com/web/secure/one-stop-trade', { waitUntil: 'networkidle2' }).catch(() => {});
            await new Promise(r => setTimeout(r, 10000));
            gridFound = await this.page.evaluate(() => !!document.querySelector('ag-grid-angular'));
        }

        if (!gridFound) {
            throw new Error('Unable to find grid for update cycle');
        }

        const priceData = await this.page.evaluate(async () => {
            const resultsMap = new Map();
            const findContainerRecursive = (root) => {
                const c = root.querySelector('.ag-body-viewport') || root.querySelector('.ag-center-cols-viewport');
                if (c) return c;
                const iframes = Array.from(root.querySelectorAll('iframe'));
                for (const iframe of iframes) {
                    try {
                        const ic = findContainerRecursive(iframe.contentDocument);
                        if (ic) return ic;
                    } catch (e) {}
                }
                return null;
            };

            const viewport = findContainerRecursive(document);
            if (!viewport) return null;

            const extractVisible = (root) => {
                const rows = Array.from(root.querySelectorAll('.ag-row, [role="row"]'))
                    .filter(el => el.getAttribute('row-index') !== null);
                rows.forEach(row => {
                    const rowId = row.getAttribute('row-id');
                    if (!rowId) return;
                    if (!resultsMap.has(rowId)) resultsMap.set(rowId, { ticker: null, price: null });
                    const data = resultsMap.get(rowId);
                    const tickerCell = row.querySelector('[col-id="0"]');
                    if (tickerCell && !data.ticker) {
                        const tickerText = tickerCell.innerText.replace(/[\n\r]/g, ' ').trim().split(' ')[0];
                        if (tickerText && tickerText.length > 1) data.ticker = tickerText;
                    }
                    const priceCell = row.querySelector('[col-id="1"]');
                    if (priceCell && data.price === null) {
                        const priceStr = priceCell.innerText.replace(/,/g, '').trim();
                        const price = parseFloat(priceStr);
                        if (!isNaN(price)) data.price = price;
                    }
                });
            };

            let lastScrollTop = -1;
            while (viewport.scrollTop !== lastScrollTop && resultsMap.size < 500) {
                lastScrollTop = viewport.scrollTop;
                extractVisible(viewport.closest('ag-grid-angular') || viewport.ownerDocument);
                viewport.scrollTop += 500;
                await new Promise(r => setTimeout(r, 600));
            }
            viewport.scrollTop = 0; 
            return Array.from(resultsMap.values()).filter(item => item.ticker && item.price !== null);
        });

        if (!priceData) return 0;

        let updatedCount = 0;
        for (const item of priceData) {
            const result = await Stock.findOneAndUpdate(
                { ticker: item.ticker.toUpperCase() },
                { price: item.price, lastUpdated: new Date() },
                { returnDocument: 'after' }
            );
            if (result) updatedCount++;
        }

        if (updatedCount > 0) {
            await ScoringService.calculateAllScores();
        }
        return updatedCount;
    }

    async stopSession() {
        this.shouldStop = true;
        if (this.browser) {
            await this.browser.close();
            this.browser = null;
            this.page = null;
        }
    }

    async updatePrices() {
        try {
            await this.initBrowser();
            await this.ensureLoggedIn();
            const count = await this.performUpdateCycle();
            console.log(`Manual update finished: ${count} stocks updated.`);
            return count;
        } catch (e) {
            console.error('Manual update error:', e);
            throw e;
        } finally {
            await this.stopSession();
        }
    }

}

module.exports = new MubasherTradeService();
