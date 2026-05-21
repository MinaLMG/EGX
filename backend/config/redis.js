const Redis = require('ioredis');
const dotenv = require('dotenv');

dotenv.config();

const redis = new Redis(process.env.REDIS_URL);

redis.on('connect', () => {
    console.log('Connected to Upstash Redis');
});

redis.on('error', (err) => {
    console.error('Redis error:', err);
});

module.exports = redis;
