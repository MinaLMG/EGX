/**
 * triggerAction.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Manually starts the GitHub Scraper from your local machine.
 *
 * Usage: node scripts/triggerAction.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

const axios = require('axios');
const path = require('path');
const dotenv = require('dotenv');

// Load env for GITHUB_PAT
dotenv.config({ path: path.join(__dirname, '../.env') });

const GITHUB_PAT = process.env.GITHUB_PAT;
const REPO_OWNER = 'MinaLMG';
const REPO_NAME = 'EGX';

async function trigger() {
    console.log(`[Local Trigger] Attempting to wake up GitHub Action for ${REPO_OWNER}/${REPO_NAME}...`);

    if (!GITHUB_PAT) {
        console.error('❌ ERROR: GITHUB_PAT not found in backend/.env file.');
        return;
    }

    try {
        const response = await axios.post(
            `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/dispatches`,
            { event_type: 'trigger-scraper' },
            {
                headers: {
                    'Authorization': `token ${GITHUB_PAT}`,
                    'Accept': 'application/vnd.github.v3+json',
                    'User-Agent': 'EGX-Local-Trigger'
                }
            }
        );

        console.log(`✅ SUCCESS! GitHub responded with status: ${response.status}`);
        console.log('Check your Actions tab: https://github.com/MinaLMG/EGX/actions');
    } catch (error) {
        console.error('❌ FAILED:', error.response?.data || error.message);
    }
}

trigger();
