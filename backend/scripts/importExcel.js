const mongoose = require('mongoose');
const xlsx = require('xlsx');
const path = require('path');
const dotenv = require('dotenv');
const Stock = require('../models/Stock');
const MubasherMatch = require('../models/MubasherMatch');

dotenv.config({ path: path.join(__dirname, '../.env') });

const importExcel = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        const filePath = path.join(__dirname, '../utils/fair.xlsx');
        const workbook = xlsx.readFile(filePath);
        const sheetName = 'رموز سريعة';

        if (!workbook.SheetNames.includes(sheetName)) {
            console.error(`Sheet "${sheetName}" not found in Excel file.`);
            process.exit(1);
        }

        const worksheet = workbook.Sheets[sheetName];
        const data = xlsx.utils.sheet_to_json(worksheet, { header: 'A' }); // Use letter headers

        console.log(`Found ${data.length} rows in "${sheetName}"`);

        const uniqueTickers = new Set();
        const mubasherEntries = [];

        // Skip header if needed (assuming row 1 is header)
        for (let i = 1; i < data.length; i++) {
            const row = data[i];
            const name = row['A'];
            const ticker = row['B'] ? row['B'].toString().trim().toUpperCase() : null;

            if (ticker) {
                mubasherEntries.push({ name: name || 'Unknown', ticker });
                uniqueTickers.add(ticker);
            }
        }

        // 1. Fill MubasherMatch table
        console.log('Filling MubasherMatch table...');
        await MubasherMatch.deleteMany({}); // Optional: clear existing
        await MubasherMatch.insertMany(mubasherEntries);
        console.log(`Imported ${mubasherEntries.length} entries to MubasherMatch.`);

        // 2. Fill Stock table with unique tickers
        console.log('Filling Stock table with unique tickers...');
        for (const ticker of uniqueTickers) {
            await Stock.findOneAndUpdate(
                { ticker },
                { ticker }, // Only setting ticker for now as per instructions
                { upsert: true, returnDocument: 'after' }
            );
        }
        console.log(`Imported/Updated ${uniqueTickers.size} unique stocks.`);

        console.log('Import process completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Error during import:', err.message);
        process.exit(1);
    }
};

importExcel();
