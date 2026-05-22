const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const connectDB = require('./config/db');

// Load environment variables
dotenv.config();

// Connect to Database
connectDB();

const cron = require('node-cron');
const scraperService = require('./services/scraperService');
const mubasherPriceService = require('./services/mubasherPriceService');

const app = express();

// Schedule daily ArabicStock scrape at 00:00
cron.schedule('0 0 * * *', async () => {
    console.log('Running daily scheduled scrape...');
    await scraperService.scrapeAllArabicStocks();
});

// Schedule Mubasher price updates every 4 minutes during EGX market hours (10:00 - 14:30 Cairo time)
// Cron: Sunday to Thursday
cron.schedule('*/4 10-14 * * 0-4', async () => {
    const now = new Date();
    // Use Cairo time (UTC+2 as per user)
    // Convert current UTC time to Cairo time
    const cairoTime = new Date(now.getTime() + (2 * 60 * 60 * 1000));
    const hours = cairoTime.getUTCHours();
    const minutes = cairoTime.getUTCMinutes();

    // Check if within 10:00 - 14:30 range
    if ((hours > 10 || (hours === 10 && minutes >= 0)) && (hours < 14 || (hours === 14 && minutes <= 30))) {
        console.log('Running scheduled Mubasher price update...');
        await mubasherPriceService.updatePricesFromMubasher();
    }
});

// Middleware
app.use(cors());
app.use(express.json());

// Routes

app.use('/api/stocks', require('./routes/stockRoutes'));
app.use('/api/recommendations', require('./routes/recommendationRoutes'));
app.use('/api/mubasher', require('./routes/mubasherRoutes'));

// Health Check
app.get('/', (req, res) => {
    res.send('Egyptian Stocks Fair Value API is running...');
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
