const mongoose = require('mongoose');
const dotenv = require('dotenv');
const SystemConfig = require('./models/SystemConfig');

dotenv.config();

const seed = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB for seeding...');

        const settings = [
            {
                key: 'scoring_weights',
                value: {
                    fundamental: 1.0,
                    bf: 0.8,
                    rfp: 0.7,
                    rsp: 0.7,
                    technical: 0.6,
                    arabstock: 0.5
                },
                description: 'Weights for total score calculation'
            },
            {
                key: 'scraper_delay',
                value: 2000,
                description: 'Delay in ms between ArabicStock page requests'
            },
            {
                key: 'http_timeout',
                value: 30000,
                description: 'Global axios request timeout'
            },
            {
                key: 'user_agent',
                value: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                description: 'Value used in scraper headers'
            },
            {
                key: 'graham_constant',
                value: 22.5,
                description: 'Graham Number coefficient'
            },
            {
                key: 'market_schedule',
                value: '*/1 10-14 * * 0-4',
                description: 'Cron schedule for Mubasher updates'
            }
        ];

        for (const s of settings) {
            await SystemConfig.findOneAndUpdate(
                { key: s.key },
                s,
                { upsert: true }
            );
        }

        console.log('System settings seeded successfully.');
        process.exit();
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

seed();
