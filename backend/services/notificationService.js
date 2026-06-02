const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const User = require('../models/User');
const Notification = require('../models/Notification');
const walletService = require('./walletService');

class NotificationService {
    constructor() {
        this.isInitialized = false;
        this._initializeFirebase();
    }

    _initializeFirebase() {
        try {
            if (process.env.FIREBASE_SERVICE_ACCOUNT) {
                try {
                    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
                    admin.initializeApp({
                        credential: admin.credential.cert(serviceAccount)
                    });
                    this.isInitialized = true;
                    console.log('Firebase Admin initialized via Environment Variable.');
                } catch (parseError) {
                    console.error('Error parsing FIREBASE_SERVICE_ACCOUNT env var:', parseError);
                }
            } else {
                console.warn('FIREBASE_SERVICE_ACCOUNT environment variable not found.');
                console.warn('Push notifications will be logged but not sent.');
            }
        } catch (error) {
            console.error('Error initializing Firebase:', error);
        }
    }

    /**
     * Checks all users' wallets for rebalancing suggestions and sends notifications if they changed.
     * Optimized to only calculate rebalancing metrics, skipping heavy profit/history math.
     */
    async checkAllWalletsAndNotify() {
        console.log('Notification Check: Starting wallet analysis for all users...');
        const users = await User.find({ status: 'active' });

        let totalSent = 0;

        for (const user of users) {
            try {
                // 1. Fetch wallet and calculate only totalValue + rebalancing (Lightweight)
                const wallet = await walletService.getPopulatedWallet(user._id);
                if (!wallet.items || wallet.items.length === 0) continue; // Skip empty wallets

                const totalValue = walletService.calculateTotalValue(wallet);
                const { analysis } = walletService.calculateRebalancing(wallet, totalValue);

                // 2. Identify active suggestions (Buy/Sell)
                const currentSuggestions = (analysis || [])
                    .filter(a => a.suggestion === 'Buy' || a.suggestion === 'Sell')
                    .map(a => `${a.ticker}:${a.suggestion}`)
                    .sort();
                
                // 3. Compare with last stored suggestions
                const lastSuggestions = (user.lastPendingSuggestions || []).sort();
                const hasChanged = JSON.stringify(currentSuggestions) !== JSON.stringify(lastSuggestions);

                if (hasChanged) {
                    const currentTickers = currentSuggestions.map(s => s.split(':')[0]);
                    const lastTickers = lastSuggestions.map(s => s.split(':')[0]);
                    const isNewTickerAdded = currentTickers.some(t => !lastTickers.includes(t));

                    console.log(`[Notification Debug] User: ${user.email} | Change: ${hasChanged} | New Ticker: ${isNewTickerAdded}`);
                    
                    if (isNewTickerAdded && currentSuggestions.length > 0) {
                        // Build Arabic content listing each action
                        const buyTickers = (analysis || [])
                            .filter(a => a.suggestion === 'Buy')
                            .map(a => a.ticker);
                        const sellTickers = (analysis || [])
                            .filter(a => a.suggestion === 'Sell')
                            .map(a => a.ticker);

                        const lines = [];
                        if (buyTickers.length > 0)
                            lines.push(`امر زيادة مراكز على: ${buyTickers.join(', ')}`);
                        if (sellTickers.length > 0)
                            lines.push(`امر جني ارباح على: ${sellTickers.join(', ')}`);

                        const title = '🔔 البورصة فيها اكشن!';
                        const content = lines.join(' | ');

                        await this.sendNotification(user, title, content, 'wallet_update');
                        totalSent++;
                    }

                    // 4. Update user record atomically
                    await User.findByIdAndUpdate(user._id, {
                        lastPendingSuggestions: currentSuggestions
                    });
                }

            } catch (err) {
                console.error(`Error checking wallet for user ${user.email}:`, err);
            }
        }

        console.log(`Notification Check: Finished. Notifications sent: ${totalSent}`);
        return totalSent;
    }

    /**
     * Sends notification via FCM and saves to DB history.
     */
    async sendNotification(user, title, content, type = 'wallet_update') {
        try {
            // Save to Database History
            await Notification.create({
                user: user._id,
                title,
                content,
                type
            });

            // Send via FCM if tokens exist and Firebase is init
            if (user.fcmTokens && user.fcmTokens.length > 0 && this.isInitialized) {
                const invalidTokens = [];
                
                // Send to all registered devices
                const sendPromises = user.fcmTokens.map(async (token) => {
                    try {
                        const message = {
                            token: token,
                            notification: {
                                title: title,
                                body: content,
                            },
                            android: {
                                priority: 'high',
                                notification: {
                                    channelId: 'egx_alerts_channel_v2',
                                    sound: 'alert_1',
                                    priority: 'high',
                                }
                            },
                            apns: {
                                payload: {
                                    aps: {
                                        sound: 'alert_1.caf',
                                        badge: 1,
                                        'content-available': 1,
                                    }
                                }
                            },
                            webpush: {
                                notification: {
                                    title: title,
                                    body: content,
                                    icon: '/icons/Icon-192.png',
                                    badge: '/icons/Icon-192.png',
                                    dir: 'rtl',
                                },
                            }
                        };
                        await admin.messaging().send(message);
                        console.log(`FCM Sent to ${user.email} on device ${token.substring(0, 10)}...`);
                    } catch (error) {
                        // If token is invalid or expired, mark it for removal
                        if (error.code === 'messaging/registration-token-not-registered' || 
                            error.code === 'messaging/invalid-registration-token') {
                            invalidTokens.push(token);
                        } else {
                            console.error(`FCM Error for token ${token.substring(0, 10)}:`, error.message);
                        }
                    }
                });

                await Promise.all(sendPromises);

                // Self-Cleaning: Remove dead tokens from DB
                if (invalidTokens.length > 0) {
                    await User.findByIdAndUpdate(user._id, {
                        $pull: { fcmTokens: { $in: invalidTokens } }
                    });
                    console.log(`Cleaned up ${invalidTokens.length} dead tokens for ${user.email}`);
                }
            } else if (user.fcmTokens && user.fcmTokens.length > 0) {
                console.log(`[MOCK FCM] To: ${user.email} (on ${user.fcmTokens.length} devices) | Title: ${title} | Body: ${content}`);
            }

        } catch (error) {
            console.error(`Error sending notification to ${user.email}:`, error);
        }
    }
}

module.exports = new NotificationService();
