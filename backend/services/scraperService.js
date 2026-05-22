const axios = require('axios');
const cheerio = require('cheerio');
const Stock = require('../models/Stock');

/**
 * Scrapes fair values for all stocks with an arabic_stock_getter URL
 */
exports.scrapeAllArabicStocks = async () => {
    try {
        const stocksToScrape = await Stock.find({ 
            arabic_stock_getter: { $exists: true, $ne: null, $ne: '' } 
        });
        
        console.log(`Found ${stocksToScrape.length} stocks to scrape from arabicstock.com`);

        for (const stock of stocksToScrape) {
            try {
                console.log(`Scraping ${stock.ticker} from ${stock.arabic_stock_getter}...`);
                
                const { data: html } = await axios.get(stock.arabic_stock_getter, {
                    headers: {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
                    }
                });
                
                const $ = cheerio.load(html);

                // 2. Extract Fair Value
                let fairValueText = $('.stock-valuation-hero__value').text().trim();
                if (!fairValueText) {
                    fairValueText = $('td[data-label="القيمة العادلة للسهم"]').text().trim();
                }
                const fairValueRaw = parseFloat(fairValueText.replace(/[^0-9.]/g, ''));
                const fairValue = isNaN(fairValueRaw) ? 0 : fairValueRaw;

                // 3. Extract Analyzers Fair Value
                let analyzersFairValueText = '';
                $('.stock-valuation-card').each((i, el) => {
                    if ($(el).find('.stock-valuation-card__title').text().includes('هدف المحللين')) {
                        analyzersFairValueText = $(el).find('.stock-valuation-card__value').text().trim();
                    }
                });
                if (!analyzersFairValueText) {
                    analyzersFairValueText = $('td[data-label="القيمة العادلة (هدف المحللين)"]').text().trim();
                }
                const analyzersFairValueRaw = parseFloat(analyzersFairValueText.replace(/[^0-9.]/g, ''));
                const analyzersFairValue = isNaN(analyzersFairValueRaw) ? 0 : analyzersFairValueRaw;

                // Update stock
                stock.arabic_stock_fair_value = fairValue;
                stock.arabic_stock_analyzers_fair_value = analyzersFairValue;
                stock.lastUpdated = new Date();

                await stock.save();
                console.log(`Updated ${stock.ticker}: FairValue=${fairValue}, AnalyzersFairValue=${analyzersFairValue}`);

            } catch (err) {
                console.error(`Failed to scrape ${stock.ticker}:`, err.message);
            }
            
            // Add a small delay to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 2000));
        }

        console.log('Scrape session completed.');
    } catch (err) {
        console.error('Error during scrape service:', err.message);
    }
};
