const mongoose = require('mongoose');
const dotenv = require('dotenv');
const scoringService = require('../services/scoringService');

dotenv.config();

mongoose.connect(process.env.MONGO_URI)
    .then(async () => {
        console.log('Connected to MongoDB');
        await scoringService.calculateAllScores();
        console.log('Finished recalculating scores.');
        process.exit(0);
    })
    .catch(err => {
        console.error('Error:', err);
        process.exit(1);
    });
