const Stock = require('../models/Stock');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const BFValue = require('../models/BFValue');
const FundamentalRecommendation = require('../models/FundamentalRecommendation');
const TechnicalRecommendation = require('../models/TechnicalRecommendation');
const XLSX = require('xlsx');
const ExcelJS = require('exceljs');
const fairValueService = require('../services/fairValueService');
const arabicStockService = require('../services/arabicStockService');
const ConfigHelper = require('../utils/configHelper');

// @desc    Get all stocks
// @route   GET /api/stocks
exports.getStocks = async (req, res) => {
    try {
        const stocks = await Stock.find().sort({ total_score: -1, ticker: 1 });
        res.json(stocks);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Get system info (last update timestamp)
// @route   GET /api/stocks/info
exports.getStocksInfo = async (req, res) => {
    try {
        const lastUpdate = await ConfigHelper.getSetting(ConfigHelper.KEYS.LAST_PRICE_UPDATE, null);
        res.json({ lastPriceUpdate: lastUpdate });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Search for stock on ArabicStock.com
// @route   GET /api/stocks/search-arabic
exports.searchArabicStock = async (req, res) => {
    try {
        const { q } = req.query;
        if (!q) return res.status(400).json({ message: 'Query is required' });

        const results = await arabicStockService.search(q);
        res.json(results);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Match a stock with an ArabicStock.com URL
// @route   PATCH /api/stocks/:ticker/match-arabic
exports.matchArabicStock = async (req, res) => {
    try {
        const { ticker } = req.params;
        const { url } = req.body;

        if (!url) return res.status(400).json({ message: 'URL is required' });

        const stock = await Stock.findOneAndUpdate(
            { ticker: ticker.toUpperCase() },
            { arabic_stock_getter: url },
            { returnDocument: 'after' }
        );

        if (!stock) return res.status(404).json({ message: 'Stock not found' });

        res.json(stock);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Create a new stock
// @route   POST /api/stocks
exports.createStock = async (req, res) => {
    try {
        const { ticker, name, price } = req.body;

        let stock = await Stock.findOne({ ticker: ticker.toUpperCase() });
        if (stock) {
            return res.status(400).json({ message: 'Stock already exists' });
        }

        stock = await Stock.create({
            ticker: ticker.toUpperCase(),
            name,
            price: price || 0
        });

        res.status(201).json(stock);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Get stocks matrix (Admin only)
// @route   GET /api/stocks/admin/matrix
exports.getStocksMatrix = async (req, res) => {
    try {
        const stocks = await Stock.find().sort({ total_score: -1, ticker: 1 });
        const users = await User.find({ role: 'user' }).select('name username');
        const wallets = await Wallet.find().populate('items.stock');

        const matrix = stocks.map(stock => {
            const userParticipation = {};
            let existsInAnyWallet = false;

            users.forEach(user => {
                const userWallet = wallets.find(w => w.user.toString() === user._id.toString());
                const hasStock = userWallet ? userWallet.items.some(item => item.stock.ticker === stock.ticker) : false;
                userParticipation[user._id] = hasStock;
                if (hasStock) existsInAnyWallet = true;
            });

            return {
                ticker: stock.ticker,
                score: stock.total_score || 0,
                userParticipation,
                existsInAnyWallet
            };
        });

        res.json({
            users,
            matrix
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// @desc    Export stocks to Excel (Admin only)
// @route   GET /api/stocks/admin/export-excel
exports.getStocksExcel = async (req, res) => {
    try {
        const stocks = await Stock.find().sort({ total_score: -1, ticker: 1 });
        const bfValues = await BFValue.find();
        const fundamentalRecs = await FundamentalRecommendation.find();
        const technicalRecs = await TechnicalRecommendation.find();
        const users = await User.find().select('name username');
        const wallets = await Wallet.find().populate('items.stock');

        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Market Fair Analysis');

        // Define Headers
        const headers = [
            'Ticker',              // 1 (A)
            'Current Price',       // 2 (B)
            'Go (BF)',             // 3 (C)
            'Ratio',               // 4 (D)
            'Fund',                // 5 (E)
            'Techn',               // 6 (F)
            'Fundamental Score',   // 7 (G)
            'Technical Score',     // 8 (H)
            'RFP Score',           // 9 (I)
            'RSP Score',           // 10 (J)
            'ArabStock (i4)',      // 11 (K)
            'Total Score',         // 12 (L)
            'Any Participation'    // 13 (M)
        ];

        users.forEach(user => {
            headers.push(user.name || user.username); // 14+ (N+)
        });

        const headerRow = worksheet.getRow(1);
        headerRow.values = headers;
        headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        headerRow.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FF512DA8' } // Deep Purple
        };
        headerRow.alignment = { horizontal: 'center' };

        stocks.forEach((stock, index) => {
            const rowIndex = index + 2; // Data starts at row 2
            const bf = bfValues.find(b => b.stock.toString() === stock._id.toString());
            const fundRec = fundamentalRecs.find(r => r.stock.toString() === stock._id.toString());
            const techRec = technicalRecs.find(r => r.stock.toString() === stock._id.toString());

            const curr = stock.price; // No || 0
            const fundTarget = fundRec?.target;
            const techTarget = techRec?.target;

            const rowData = [
                stock.ticker,
                curr,
                bf?.value,
                (rowIndex > 1 && curr) ? { formula: `C${rowIndex}/B${rowIndex}` } : null,
                (rowIndex > 1 && curr && fundTarget) ? { formula: `${fundTarget}/B${rowIndex}-1` } : null,
                (rowIndex > 1 && curr && techTarget) ? { formula: `${techTarget}/B${rowIndex}-1` } : null,
                stock.fundamental_potential,
                stock.technical_potential,
                stock.rfp_score || null,   // blank if not in RFP list
                stock.rsp_score || null,   // blank if not in RSP list
                stock.arabstock_score,
                stock.total_score
            ];

            const userPart = [];
            let hasAnyPart = false;
            users.forEach(user => {
                const userWallet = wallets.find(w => w.user.toString() === user._id.toString());
                const hasStock = userWallet ? userWallet.items.some(item => item.stock.ticker === stock.ticker) : false;
                if (hasStock) hasAnyPart = true;
                userPart.push(hasStock ? 1 : null);
            });

            // M: Any Participation
            const nCol = 14;
            const lastCol = nCol + users.length - 1;
            const startAddr = worksheet.getCell(rowIndex, nCol).address;
            const endAddr = worksheet.getCell(rowIndex, lastCol).address;

            if (hasAnyPart) {
                rowData.push({ formula: `IF(OR(${startAddr}:${endAddr}), 1, "")` });
            } else {
                rowData.push(null);
            }

            rowData.push(...userPart);

            const row = worksheet.getRow(rowIndex);
            row.values = rowData;

            // Active Filter: Hide rows where Any Participation is empty (default filtered to "1")
            if (!hasAnyPart) {
                row.hidden = true;
            }

            // Alternating row colors
            if (index % 2 === 1) {
                row.fill = {
                    type: 'pattern',
                    pattern: 'solid',
                    fgColor: { argb: 'FFF5F5F5' }
                };
            }
        });

        // Column widths and hiding
        worksheet.columns.forEach((col, i) => {
            const index0 = i; // 0-indexed
            if (index0 === 0) col.width = 12; // Ticker
            else if (index0 < 13) col.width = 15;
            else col.width = 18; // Users

            // Hide internal rank-score columns G (i2), H (i3), K (i4)
            // Keep I (RFP) and J (RSP) visible
            if (index0 === 6 || index0 === 7 || index0 === 10) {
                col.hidden = true;
            }

            // Percentage format for Fund (E=4) and Techn (F=5)
            if (index0 === 4 || index0 === 5) {
                col.numFmt = '0.00%';
            }
        });

        // Freeze top row and first column
        worksheet.views = [
            { state: 'frozen', xSplit: 1, ySplit: 1 }
        ];

        // Add Auto-Filter to all columns
        const lastColNum = 13 + users.length;
        const lastLetter = worksheet.getColumn(lastColNum).letter;
        worksheet.autoFilter = `A1:${lastLetter}1`;

        const lastRow = stocks.length + 1;

        // Apply Conditional Formatting (Heatmaps)

        // 1. Ratio (D): 3-Color Scale (Red < 1 < Green)
        worksheet.addConditionalFormatting({
            ref: `D2:D${lastRow}`,
            rules: [
                {
                    type: 'colorScale',
                    cfvo: [
                        { type: 'num', value: 0.5 },
                        { type: 'num', value: 1.0 },
                        { type: 'num', value: 2.0 }
                    ],
                    color: [
                        { argb: 'FFF8696B' }, // Red (Low)
                        { argb: 'FFFFEB84' }, // Yellow (1.0)
                        { argb: 'FF63BE7B' }  // Green (High)
                    ]
                }
            ]
        });

        // 2. Fund (E) and Techn (F): Red < 0 < Green
        ['E', 'F'].forEach(col => {
            worksheet.addConditionalFormatting({
                ref: `${col}2:${col}${lastRow}`,
                rules: [
                    {
                        type: 'colorScale',
                        cfvo: [
                            { type: 'num', value: -0.5 },
                            { type: 'num', value: 0 },
                            { type: 'num', value: 0.5 }
                        ],
                        color: [
                            { argb: 'FFF8696B' }, // Red (Negative)
                            { argb: 'FFFFFFFF' }, // White (Near 0)
                            { argb: 'FF63BE7B' }  // Green (Positive)
                        ]
                    }
                ]
            });
        });

        // 3. Any Participation (M) and Users (N+): 2-Color Scale (White -> Green)
        const startLetter = 'M';
        // ExcelJS doesn't support easy column name generation for large indices, but we can use ranges
        const endLetter = worksheet.getColumn(lastColNum).letter;
        worksheet.addConditionalFormatting({
            ref: `${startLetter}2:${endLetter}${lastRow}`,
            rules: [
                {
                    type: 'colorScale',
                    cfvo: [
                        { type: 'min' },
                        { type: 'max' }
                    ],
                    color: [
                        { argb: 'FFFFFFFF' }, // White (0)
                        { argb: 'FF63BE7B' }  // Green (1)
                    ]
                }
            ]
        });

        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', 'attachment; filename=fair.xlsx');

        await workbook.xlsx.write(res);
        res.end();

    } catch (err) {
        console.error('Excel Export Error:', err);
        res.status(500).json({ message: err.message });
    }
};
