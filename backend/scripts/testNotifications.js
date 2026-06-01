const notificationService = require('../backend/services/notificationService');

// Mock data
const mockUser = {
    _id: '123',
    email: 'test@example.com',
    lastPendingSuggestions: ['AAPL:Buy', 'MSFT:Hold'],
    save: async () => console.log('User saved.')
};

const newSuggestions = ['AAPL:Buy', 'GOOG:Buy']; // Changed from MSFT to GOOG

console.log('Testing Comparison Logic...');

const lastS = [...mockUser.lastPendingSuggestions].sort();
const nextS = [...newSuggestions].sort();

const hasChanged = JSON.stringify(lastS) !== JSON.stringify(nextS);
console.log('Has Changed:', hasChanged);

if (hasChanged) {
    console.log('Notification would be sent!');
} else {
    console.log('No change, no notification.');
}
