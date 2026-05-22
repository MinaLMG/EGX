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

const app = express();

// Schedule daily scrape at 00:00
cron.schedule('0 0 * * *', async () => {
    console.log('Running daily scheduled scrape...');
    await scraperService.scrapeAllArabicStocks();
});

// Middleware
app.use(cors());
app.use(express.json());

// Routes

app.use('/api/stocks', require('./routes/stockRoutes'));

// Health Check
app.get('/', (req, res) => {
    res.send('Egyptian Stocks Fair Value API is running...');
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
