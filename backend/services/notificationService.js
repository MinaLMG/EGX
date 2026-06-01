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
     */
    async checkAllWalletsAndNotify() {
        console.log('Notification Check: Starting wallet analysis for all users...');
        const users = await User.find({ status: 'active' });
        
        let totalSent = 0;

        for (const user of users) {
            try {
                // 1. Calculate current metrics/suggestions
                const result = await walletService.calculateWalletMetrics(user._id);
                
                // 2. Identify active suggestions (Buy/Sell)
                const currentSuggestions = (result.analysis || [])
                    .filter(a => a.suggestion === 'Buy' || a.suggestion === 'Sell')
                    .map(a => `${a.ticker}:${a.suggestion}`)
                    .sort();

                // 3. Compare with last stored suggestions
                const lastSuggestions = (user.lastPendingSuggestions || []).sort();
                
                const hasChanged = JSON.stringify(currentSuggestions) !== JSON.stringify(lastSuggestions);

                if (hasChanged && currentSuggestions.length > 0) {
                    // Something new appeared or changed
                    const buyCount = (result.analysis || []).filter(a => a.suggestion === 'Buy').length;
                    
                    const title = 'Wallet Rebalancing Alert';
                    const content = buyCount > 0 
                        ? `You have ${buyCount} suggested buys. Time for a new top up!`
                        : `Your portfolio needs adjustments. Check your pending transactions.`;

                    await this.sendNotification(user, title, content, 'wallet_update');
                    
                    // 4. Update user record to prevent duplicate alerts
                    user.lastPendingSuggestions = currentSuggestions;
                    await user.save();
                    
                    totalSent++;
                } else if (hasChanged && currentSuggestions.length === 0) {
                    // Suggestions cleared (user took action)
                    user.lastPendingSuggestions = [];
                    await user.save();
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

            // Send via FCM if token exists and Firebase is init
            if (user.fcmToken && this.isInitialized) {
                const message = {
                    notification: { title, body: content },
                    token: user.fcmToken
                };

                await admin.messaging().send(message);
                console.log(`FCM Sent to ${user.email}`);
            } else if (user.fcmToken) {
                console.log(`[MOCK FCM] To: ${user.email} | Title: ${title} | Body: ${content}`);
            }

        } catch (error) {
            console.error(`Error sending notification to ${user.email}:`, error);
        }
    }
}

module.exports = new NotificationService();
