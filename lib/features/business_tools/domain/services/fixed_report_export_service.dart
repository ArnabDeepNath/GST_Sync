import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class FixedReportExportService {
  static const String _dateFormat = 'dd/MM/yyyy';

  // Export Balance Sheet to Excel
  Future<String> exportBalanceSheetToExcel(
      Map<String, dynamic> balanceSheetData) async {
    final excel = Excel.createExcel();
    final sheet = excel['Balance Sheet'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('BALANCE SHEET');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'As of ${DateFormat(_dateFormat).format(DateTime.now())}');

    int row = 4;

    // Assets Section
    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('ASSETS');
    row++;

    final assets = balanceSheetData['assets'] as Map<String, dynamic>;
    final currentAssets = assets['current_assets'] as Map<String, dynamic>;

    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('Current Assets:');
    row++;

    currentAssets.forEach((key, value) {
      sheet.cell(CellIndex.indexByString('B$row')).value =
          TextCellValue(_formatLabel(key));
      sheet.cell(CellIndex.indexByString('C$row')).value =
          TextCellValue('₹${NumberFormat('#,##,###.##').format(value)}');
      row++;
    });

    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('Total Assets');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '₹${NumberFormat('#,##,###.##').format(assets['total'])}');
    row += 2;

    // Liabilities Section
    final liabilities = balanceSheetData['liabilities'] as Map<String, dynamic>;
    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('LIABILITIES');
    row++;

    final currentLiabilities =
        liabilities['current_liabilities'] as Map<String, dynamic>;

    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('Current Liabilities:');
    row++;

    currentLiabilities.forEach((key, value) {
      sheet.cell(CellIndex.indexByString('B$row')).value =
          TextCellValue(_formatLabel(key));
      sheet.cell(CellIndex.indexByString('C$row')).value =
          TextCellValue('₹${NumberFormat('#,##,###.##').format(value)}');
      row++;
    });

    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('Total Liabilities');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '₹${NumberFormat('#,##,###.##').format(liabilities['total'])}');
    row += 2;

    // Equity Section
    final equity = balanceSheetData['equity'] as Map<String, dynamic>;
    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('EQUITY');
    row++;
    sheet.cell(CellIndex.indexByString('B$row')).value =
        TextCellValue('Retained Earnings');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '₹${NumberFormat('#,##,###.##').format(equity['total'])}');

    return await _saveExcelFile(
        excel, 'balance_sheet_${_getDateString()}.xlsx');
  }

  // Export Profit & Loss to Excel
  Future<String> exportProfitLossToExcel(Map<String, dynamic> plData) async {
    final excel = Excel.createExcel();
    final sheet = excel['Profit & Loss'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('PROFIT & LOSS STATEMENT');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'For the period ending ${DateFormat(_dateFormat).format(DateTime.now())}');

    int row = 4;

    // Revenue Section
    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('REVENUE');
    row++;

    final revenue = plData['revenue'] as Map<String, dynamic>;
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('Sales');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '₹${NumberFormat('#,##,###.##').format(revenue['sales'])}');
    row++;

    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('Total Revenue');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '₹${NumberFormat('#,##,###.##').format(revenue['total'])}');
    row += 2;

    // Expenses Section
    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('EXPENSES');
    row++;

    final expenses = plData['expenses'] as Map<String, dynamic>;
    expenses.forEach((key, value) {
      if (key != 'total') {
        sheet.cell(CellIndex.indexByString('B$row')).value =
            TextCellValue(_formatLabel(key));
        sheet.cell(CellIndex.indexByString('C$row')).value =
            TextCellValue('₹${NumberFormat('#,##,###.##').format(value)}');
        row++;
      }
    });

    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('Total Expenses');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '₹${NumberFormat('#,##,###.##').format(expenses['total'])}');
    row += 2;

    // Profit Section
    final profit = plData['profit'] as Map<String, dynamic>;
    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('NET PROFIT');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '₹${NumberFormat('#,##,###.##').format(profit['net_profit'])}');
    row++;

    sheet.cell(CellIndex.indexByString('A$row')).value =
        TextCellValue('Profit Margin');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        '${NumberFormat('#,##0.00').format(profit['profit_margin'])}%');

    return await _saveExcelFile(excel, 'profit_loss_${_getDateString()}.xlsx');
  }

  // Export Balance Sheet to CSV
  Future<String> exportBalanceSheetToCSV(
      Map<String, dynamic> balanceSheetData) async {
    final List<List<String>> csvData = [
      ['BALANCE SHEET'],
      ['As of ${DateFormat(_dateFormat).format(DateTime.now())}'],
      [''],
      ['ASSETS'],
    ];

    final assets = balanceSheetData['assets'] as Map<String, dynamic>;
    final currentAssets = assets['current_assets'] as Map<String, dynamic>;

    csvData.add(['Current Assets:']);
    currentAssets.forEach((key, value) {
      csvData.add([
        '',
        _formatLabel(key),
        '₹${NumberFormat('#,##,###.##').format(value)}'
      ]);
    });

    csvData.add([
      'Total Assets',
      '',
      '₹${NumberFormat('#,##,###.##').format(assets['total'])}'
    ]);
    csvData.add(['']);

    // Liabilities
    final liabilities = balanceSheetData['liabilities'] as Map<String, dynamic>;
    csvData.add(['LIABILITIES']);
    final currentLiabilities =
        liabilities['current_liabilities'] as Map<String, dynamic>;

    csvData.add(['Current Liabilities:']);
    currentLiabilities.forEach((key, value) {
      csvData.add([
        '',
        _formatLabel(key),
        '₹${NumberFormat('#,##,###.##').format(value)}'
      ]);
    });

    csvData.add([
      'Total Liabilities',
      '',
      '₹${NumberFormat('#,##,###.##').format(liabilities['total'])}'
    ]);
    csvData.add(['']);

    // Equity
    final equity = balanceSheetData['equity'] as Map<String, dynamic>;
    csvData.add(['EQUITY']);
    csvData.add([
      '',
      'Retained Earnings',
      '₹${NumberFormat('#,##,###.##').format(equity['total'])}'
    ]);

    return await _saveCSVFile(csvData, 'balance_sheet_${_getDateString()}.csv');
  }

  // Export Profit & Loss to CSV
  Future<String> exportProfitLossToCSV(Map<String, dynamic> plData) async {
    final List<List<String>> csvData = [
      ['PROFIT & LOSS STATEMENT'],
      [
        'For the period ending ${DateFormat(_dateFormat).format(DateTime.now())}'
      ],
      [''],
      ['REVENUE'],
    ];

    final revenue = plData['revenue'] as Map<String, dynamic>;
    csvData.add([
      '',
      'Sales',
      '₹${NumberFormat('#,##,###.##').format(revenue['sales'])}'
    ]);
    csvData.add([
      'Total Revenue',
      '',
      '₹${NumberFormat('#,##,###.##').format(revenue['total'])}'
    ]);
    csvData.add(['']);

    csvData.add(['EXPENSES']);
    final expenses = plData['expenses'] as Map<String, dynamic>;
    expenses.forEach((key, value) {
      if (key != 'total') {
        csvData.add([
          '',
          _formatLabel(key),
          '₹${NumberFormat('#,##,###.##').format(value)}'
        ]);
      }
    });

    csvData.add([
      'Total Expenses',
      '',
      '₹${NumberFormat('#,##,###.##').format(expenses['total'])}'
    ]);
    csvData.add(['']);

    final profit = plData['profit'] as Map<String, dynamic>;
    csvData.add([
      'NET PROFIT',
      '',
      '₹${NumberFormat('#,##,###.##').format(profit['net_profit'])}'
    ]);
    csvData.add([
      'Profit Margin',
      '',
      '${NumberFormat('#,##0.00').format(profit['profit_margin'])}%'
    ]);

    return await _saveCSVFile(csvData, 'profit_loss_${_getDateString()}.csv');
  }

  // Export GST Analysis to CSV
  Future<String> exportGSTAnalysisToCSV(Map<String, dynamic> gstData) async {
    final List<List<String>> csvData = [
      ['GST ANALYSIS REPORT'],
      ['As of ${DateFormat(_dateFormat).format(DateTime.now())}'],
      [''],
      ['GST SUMMARY'],
      [
        '',
        'GST Collected',
        '₹${NumberFormat('#,##,###.##').format(gstData['gst_collected'])}'
      ],
      [
        '',
        'GST Paid',
        '₹${NumberFormat('#,##,###.##').format(gstData['gst_paid'])}'
      ],
      [
        '',
        'Net GST Liability',
        '₹${NumberFormat('#,##,###.##').format(gstData['net_liability'])}'
      ],
      [
        '',
        'Compliance Score',
        '${NumberFormat('#,##0.0').format(gstData['compliance_score'])}%'
      ],
      [''],
      ['GST RATE BREAKDOWN'],
    ];

    final rateBreakdown = gstData['rate_breakdown'] as Map<double, double>;
    rateBreakdown.forEach((rate, amount) {
      csvData.add([
        '',
        '${NumberFormat('#,##0.0').format(rate)}%',
        '₹${NumberFormat('#,##,###.##').format(amount)}'
      ]);
    });

    return await _saveCSVFile(csvData, 'gst_analysis_${_getDateString()}.csv');
  }

  // Export Sales Trends to CSV
  Future<String> exportSalesTrendsToCSV(
      List<Map<String, dynamic>> trendsData) async {
    final List<List<String>> csvData = [
      ['SALES TRENDS REPORT'],
      ['As of ${DateFormat(_dateFormat).format(DateTime.now())}'],
      [''],
      ['Month', 'Sales Amount', 'Growth %'],
    ];

    for (final trend in trendsData) {
      csvData.add([
        trend['month'].toString(),
        '₹${NumberFormat('#,##,###.##').format(trend['amount'])}',
        '${NumberFormat('#,##0.0').format(trend['growth'] ?? 0)}%'
      ]);
    }

    return await _saveCSVFile(csvData, 'sales_trends_${_getDateString()}.csv');
  }

  // Export Inventory Analysis to CSV
  Future<String> exportInventoryAnalysisToCSV(
      List<Map<String, dynamic>> inventoryData) async {
    final List<List<String>> csvData = [
      ['INVENTORY ANALYSIS REPORT'],
      ['As of ${DateFormat(_dateFormat).format(DateTime.now())}'],
      [''],
      ['Item', 'Quantity', 'Value', 'Status'],
    ];

    for (final item in inventoryData) {
      csvData.add([
        item['name'].toString(),
        item['quantity'].toString(),
        '₹${NumberFormat('#,##,###.##').format(item['value'])}',
        item['status'].toString()
      ]);
    }

    return await _saveCSVFile(
        csvData, 'inventory_analysis_${_getDateString()}.csv');
  }

  // Helper methods
  String _formatLabel(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getDateString() {
    return DateFormat('yyyyMMdd').format(DateTime.now());
  }

  Future<String> _saveExcelFile(Excel excel, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    final fileBytes = excel.save();
    final file = File(filePath);
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }

    return filePath;
  }

  Future<String> _saveCSVFile(
      List<List<String>> csvData, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    final csv = const ListToCsvConverter().convert(csvData);
    final file = File(filePath);
    await file.writeAsString(csv);

    return filePath;
  }
}
