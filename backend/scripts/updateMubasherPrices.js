const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');
const mubasherPriceService = require('../services/mubasherPriceService');

dotenv.config({ path: path.join(__dirname, '../.env') });

const runScript = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        await mubasherPriceService.updatePricesFromMubasher();

        console.log('Mubasher price update script finished.');
        process.exit(0);
    } catch (err) {
        console.error('Error during Mubasher price update script:', err.message);
        process.exit(1);
    }
};

runScript();
