const axios = require('axios');
const cheerio = require('cheerio');

/**
 * Searches arabicstock.com for matching stocks
 * @param {string} query - The search query (ticker or name)
 * @returns {Promise<Array>} - List of potential matches { title, link }
 */
exports.search = async (query) => {
    try {
        const searchUrl = `https://arabicstock.com/search?q=${encodeURIComponent(query)}`;
        const { data: html } = await axios.get(searchUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        });

        const $ = cheerio.load(html);
        const results = [];

        $('.add-title a').each((i, el) => {
            const title = $(el).text().trim();
            const link = $(el).attr('href');
            if (title && link) {
                results.push({ title, link });
            }
        });

        return results;
    } catch (err) {
        console.error('ArabicStock search error:', err.message);
        throw err;
    }
};
