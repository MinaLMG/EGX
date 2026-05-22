const mongoose = require('mongoose');
const Stock = require('../models/Stock');
const dotenv = require('dotenv');

dotenv.config();

mongoose.connect(process.env.MONGO_URI)
    .then(() => console.log('Connected to MongoDB'))
    .catch(err => console.error('Could not connect to MongoDB', err));

async function updateNames() {
    try {
        const stocks = await Stock.find({ arabic_stock_getter: { $exists: true, $ne: null } });
        console.log(`Found ${stocks.length} stocks with arabic_stock_getter.`);

        for (const stock of stocks) {
            try {
                if (stock.name) continue
                // Decode URL in case it has encoded Arabic characters
                const decodedUrl = decodeURIComponent(stock.arabic_stock_getter);

                // Separate by / and take the last element
                const parts = decodedUrl.split('/');
                const lastPart = parts[parts.length - 1];

                if (!lastPart) continue;

                // Separate by -
                const nameParts = lastPart.split('-');

                if (nameParts.length <= 1) {
                    console.log(`Skipping ${stock.ticker}: Last part "${lastPart}" cannot be split by -`);
                    continue;
                }

                // Remove the last one (usually the ticker)
                nameParts.pop();

                // Gather them again with space separator
                const formattedName = nameParts.join(' ');

                console.log(`Updating ${stock.ticker}: ${formattedName}`);

                stock.name = formattedName;
                await stock.save();
            } catch (innerErr) {
                console.error(`Error processing stock ${stock.ticker}:`, innerErr.message);
            }
        }

        console.log('Finished updating stock names.');
        process.exit(0);
    } catch (err) {
        console.error('Error fetching stocks:', err);
        process.exit(1);
    }
}

updateNames();
