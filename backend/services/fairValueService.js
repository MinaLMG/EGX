const ConfigHelper = require('../utils/configHelper');

/**
 * Fair Value Calculation Service
 */
exports.calculate = async (stockData) => {
    const { financialData } = stockData;

    if (!financialData) return null;

    // Example: Graham Number calculation
    // Fair Value = sqrt(22.5 * EPS * Book Value)
    const { eps, bookValue } = financialData;

    if (eps > 0 && bookValue > 0) {
        const grahamConstant = await ConfigHelper.getSetting(ConfigHelper.KEYS.GRAHAM_CONSTANT, 22.5);
        return Math.sqrt(grahamConstant * eps * bookValue);
    }

    return null;
};
