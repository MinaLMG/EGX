const axios = require('axios');
const Stock = require('../models/Stock');
const MubasherMatch = require('../models/MubasherMatch');
const MubasherUnmatched = require('../models/MubasherUnmatched');
const ScoringService = require('./scoringService');

/**
 * Fetch stock prices from Mubasher API and update Database
 */
exports.updatePricesFromMubasher = async () => {
    try {
        console.log('Fetching prices from Mubasher API...');

        // Use the public API endpoint discovered during browser investigation
        const response = await axios.get('https://www.mubasher.info/api/1/stocks/prices/all?country=eg', {
            timeout: 30000,
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Accept': 'application/json',
                'Referer': 'https://www.mubasher.info/countries/eg/all-stock-prices',
                'Origin': 'https://www.mubasher.info'
            }
        });

        if (!response.data || !response.data.prices || !Array.isArray(response.data.prices)) {
            throw new Error('Invalid response format from Mubasher API (prices array not found)');
        }

        const priceData = response.data.prices.map(item => {
            // value is the current price as a string, e.g., "19.00"
            const rawValue = item.value || item.lastTradePrice || "0";
            const price = parseFloat(rawValue.replace(/,/g, ''));
            return {
                name: item.name,
                price: price
            };
        }).filter(item => item.name && !isNaN(item.price));

        console.log(`Received ${priceData.length} entries from Mubasher API.`);
        // 1. Get all matches from database
        const matches = await MubasherMatch.find();

        const matchMap = {};
        matches.forEach(m => {
            matchMap[m.name] = m.ticker.toUpperCase();
        });

        // 2. Group prices by ticker
        const tickerPrices = {};
        for (const item of priceData) {

            const ticker = matchMap[item.name];

            if (ticker) {
                if (!tickerPrices[ticker]) tickerPrices[ticker] = [];
                tickerPrices[ticker].push(item.price);
            }
        }
        const tickers = Object.keys(tickerPrices);
        console.log(`Updating ${tickers.length} tickers matched in DB...`);

        // 3. Update Stocks
        let updatedCount = 0;
        for (const ticker of tickers) {
            const prices = tickerPrices[ticker];
            let priceToUse = prices[0];

            if (prices.length > 1) {
                // Pick the price closest to current price if multiple entries (though unique tickers should be rare now)
                const stock = await Stock.findOne({ ticker });
                if (stock && stock.price) {
                    priceToUse = prices.reduce((prev, curr) =>
                        Math.abs(curr - stock.price) < Math.abs(prev - stock.price) ? curr : prev
                    );
                }
            }

            const result = await Stock.findOneAndUpdate(
                { ticker },
                {
                    price: priceToUse,
                    lastUpdated: new Date()
                },
                { new: true }
            );

            if (result) updatedCount++;
        }

        console.log(`Successfully updated ${updatedCount} stocks.`);

        // --- Orphan Tracking Logic ---
        // 1. Identify Stocks without updates in this run
        const allSystemStocks = await Stock.find({}, 'ticker');
        const updatedTickersSet = new Set(tickers);
        const unmatchedTickers = allSystemStocks
            .filter(s => !updatedTickersSet.has(s.ticker.toUpperCase()))
            .map(s => s.ticker);

        // 2. Identify Mubasher Prices that didn't match any ticker
        const matchedMubasherNames = new Set();
        matches.forEach(m => matchedMubasherNames.add(m.name));
        
        const unmatchedMubasherNames = priceData
            .filter(item => !matchedMubasherNames.has(item.name) && !matchMap[item.name])
            .map(item => item.name);

        // 3. Save to Unmatched collection
        await MubasherUnmatched.deleteMany({});
        const unmatchedEntries = [
            ...unmatchedTickers.map(t => ({ type: 'stock', identifier: t })),
            ...unmatchedMubasherNames.map(n => ({ type: 'mubasher_price', identifier: n }))
        ];
        
        if (unmatchedEntries.length > 0) {
            await MubasherUnmatched.insertMany(unmatchedEntries);
            console.log(`Saved ${unmatchedEntries.length} unmatched items.`);
        }
        // -----------------------------
        
        // Recalculate scores with new prices
        await ScoringService.calculateAllScores();
    } catch (err) {
        console.error('Mubasher update error:', err.message);
        if (err.response) {
            console.error('Response status:', err.response.status);
            console.error('Response data preview:', JSON.stringify(err.response.data).substring(0, 500));
        }
    }
};
