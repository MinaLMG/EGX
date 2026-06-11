/**
 * Run with: node backend/scripts/seedInterests.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const mongoose = require('mongoose');
const Interest = require('../models/Interest');

const interests = [
    { displayOrder: 1, name: 'Dividend Stocks',      nameAr: 'أسهم توزيعات الأرباح' },
    { displayOrder: 2, name: 'Growth Stocks',        nameAr: 'أسهم النمو' },
    { displayOrder: 3, name: 'Value Investing',      nameAr: 'الاستثمار في القيمة' },
    { displayOrder: 4, name: 'Trading',              nameAr: 'التداول' },
    { displayOrder: 5, name: 'Technical Analysis',   nameAr: 'التحليل الفني' },
    { displayOrder: 6, name: 'Fundamental Analysis', nameAr: 'التحليل الأساسي' },
    { displayOrder: 7, name: 'IPOs',                 nameAr: 'الاكتتابات العامة' },
    { displayOrder: 8, name: 'Market News',          nameAr: 'أخبار السوق' },
];

async function seed() {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    await Interest.deleteMany({});
    console.log('Cleared existing interests');

    const created = await Interest.insertMany(interests);
    console.log(`Seeded ${created.length} interests`);

    await mongoose.disconnect();
    console.log('Done.');
}

seed().catch(err => {
    console.error(err);
    process.exit(1);
});
