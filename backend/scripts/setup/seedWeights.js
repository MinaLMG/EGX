const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');
const SystemConfig = require('./models/SystemConfig');

dotenv.config({ path: path.join(__dirname, '.env') });

const LEGACY_STRATEGY = {
    fundamental: 1.0,
    bf: 0.8,
    rfp: 0.7,
    rsp: 0.7,
    technical: 0.6,
    arabstock: 0.5
};

const STEEP_STRATEGY = {
    fundamental: 2.0,
    bf: 0.5,
    rfp: 1.2,
    rsp: 1.2,
    technical: 0.8,
    arabstock: 1
};

async function seed() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        // Clean up old "purpose-based" keys to avoid confusion
        await SystemConfig.deleteMany({ key: { $in: ['main_scoring_weights', 'trial_scoring_weights'] } });

        // 1. Seed Steep
        await SystemConfig.findOneAndUpdate(
            { key: 'steep_scoring_weights' },
            { key: 'steep_scoring_weights', value: STEEP_STRATEGY },
            { upsert: true }
        );

        // 2. Seed Legacy
        await SystemConfig.findOneAndUpdate(
            { key: 'legacy_scoring_weights' },
            { key: 'legacy_scoring_weights', value: LEGACY_STRATEGY },
            { upsert: true }
        );

        console.log('Successfully seeded Steep and Legacy scoring weights in DB.');
        process.exit(0);
    } catch (err) {
        console.error('Seed failed:', err.message);
        process.exit(1);
    }
}

seed();
