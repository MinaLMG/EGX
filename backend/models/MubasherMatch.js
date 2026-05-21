const mongoose = require('mongoose');

const MubasherMatchSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true
    },
    ticker: {
        type: String,
        required: true,
        uppercase: true
    }
});

module.exports = mongoose.model('MubasherMatch', MubasherMatchSchema);
