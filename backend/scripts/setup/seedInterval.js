const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');
const SystemConfig = require('./models/SystemConfig');

dotenv.config({ path: path.join(__dirname, '.env') });

async function seed() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        // 1. Rename old key if it exists
        const old = await SystemConfig.findOne({ key: 'mubasher_update_interval' });
        if (old) {
            console.log('Found old key, renaming...');
            await SystemConfig.deleteOne({ key: 'mubasher_update_interval' });
        }

        // 2. Set new key with value 45
        await SystemConfig.findOneAndUpdate(
            { key: 'mubasher_trade_update_interval' },
            { key: 'mubasher_trade_update_interval', value: 45 },
            { upsert: true }
        );

        console.log('Successfully seeded MUBASHER_TRADE_UPDATE_INTERVAL with value: 45');
        process.exit(0);
    } catch (err) {
        console.error('Seed failed:', err.message);
        process.exit(1);
    }
}

seed();
