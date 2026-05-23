const XLSX = require('xlsx');
const path = require('path');

const filePath = path.join(__dirname, 'utils', 'fair.xlsx');
const workbook = XLSX.readFile(filePath);

const sheetName = 'panics';
const sheet = workbook.Sheets[sheetName];

if (!sheet) {
    console.log(`Sheet "${sheetName}" not found. Available sheets: ${workbook.SheetNames.join(', ')}`);
    process.exit(1);
}

// Extract headers and some rows to see formulas
const range = XLSX.utils.decode_range(sheet['!ref']);
const data = [];

for (let r = range.s.r; r <= range.s.r; r++) {
    const row = {};
    for (let c = range.s.c; c <= range.s.c + 40; c++) {
        const cellAddress = XLSX.utils.encode_cell({ r, c });
        const cell = sheet[cellAddress];
        if (cell) {
            row[XLSX.utils.encode_col(c)] = {
                v: cell.v,
                w: cell.w
            };
        }
    }
    data.push(row);
}

console.log(JSON.stringify(data, null, 2));
