const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');
const scraperService = require('../services/scraperService');

dotenv.config({ path: path.join(__dirname, '../.env') });

const runScript = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        await scraperService.scrapeAllArabicStocks();

        console.log('Daily scrape script finished.');
        process.exit(0);
    } catch (err) {
        console.error('Error during daily scrape script:', err.message);
        process.exit(1);
    }
};

runScript();
