import 'dart:io';
import 'package:csv/csv.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SimpleReportExportService {
  static const String _dateFormat = 'dd/MM/yyyy';

  // Export Balance Sheet to CSV
  static Future<String> exportBalanceSheetToCSV(
      Map<String, dynamic> balanceSheetData) async {
    final csvData = <List<String>>[];

    // Headers
    csvData.add(['BALANCE SHEET']);
    csvData.add(['As of ${DateFormat(_dateFormat).format(DateTime.now())}']);
    csvData.add(['']);

    // Assets Section
    csvData.add(['ASSETS']);
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

    // Liabilities Section
    csvData.add(['LIABILITIES']);
    final liabilities = balanceSheetData['liabilities'] as Map<String, dynamic>;
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

    // Equity Section
    final equity = balanceSheetData['equity'] as Map<String, dynamic>;
    csvData.add(['EQUITY']);
    csvData.add([
      'Retained Earnings',
      '',
      '₹${NumberFormat('#,##,###.##').format(equity['total'])}'
    ]);

    return await _saveCSVFile(csvData, 'balance_sheet_${_getDateString()}.csv');
  }

  // Export Profit & Loss to CSV
  static Future<String> exportProfitLossToCSV(
      Map<String, dynamic> plData) async {
    final csvData = <List<String>>[];

    // Headers
    csvData.add(['PROFIT & LOSS STATEMENT']);
    csvData.add([
      'For the period ending ${DateFormat(_dateFormat).format(DateTime.now())}'
    ]);
    csvData.add(['']);

    // Revenue Section
    csvData.add(['REVENUE']);
    final revenue = plData['revenue'] as Map<String, dynamic>;
    csvData.add(
        ['Sales', '₹${NumberFormat('#,##,###.##').format(revenue['sales'])}']);
    csvData.add([
      'Total Revenue',
      '₹${NumberFormat('#,##,###.##').format(revenue['total'])}'
    ]);
    csvData.add(['']);

    // Expenses Section
    csvData.add(['EXPENSES']);
    final expenses = plData['expenses'] as Map<String, dynamic>;
    expenses.forEach((key, value) {
      if (key != 'total') {
        csvData.add([
          _formatLabel(key),
          '₹${NumberFormat('#,##,###.##').format(value)}'
        ]);
      }
    });
    csvData.add([
      'Total Expenses',
      '₹${NumberFormat('#,##,###.##').format(expenses['total'])}'
    ]);
    csvData.add(['']);

    // Profit Section
    final profit = plData['profit'] as Map<String, dynamic>;
    csvData.add([
      'NET PROFIT',
      '₹${NumberFormat('#,##,###.##').format(profit['net_profit'])}'
    ]);
    csvData.add([
      'Profit Margin',
      '${NumberFormat('#,##0.00').format(profit['profit_margin'])}%'
    ]);

    return await _saveCSVFile(csvData, 'profit_loss_${_getDateString()}.csv');
  }

  // Export Cash Flow to CSV
  static Future<String> exportCashFlowToCSV(
      Map<String, dynamic> cashFlowData) async {
    final csvData = <List<String>>[];

    // Headers
    csvData.add(['CASH FLOW STATEMENT']);
    csvData.add([
      'For the period ending ${DateFormat(_dateFormat).format(DateTime.now())}'
    ]);
    csvData.add(['']);

    // Operating Activities
    csvData.add(['OPERATING ACTIVITIES']);
    csvData.add([
      'Net Cash from Operations',
      '₹${NumberFormat('#,##,###.##').format(cashFlowData['operating'])}'
    ]);
    csvData.add(['']);

    // Investing Activities
    csvData.add(['INVESTING ACTIVITIES']);
    csvData.add([
      'Net Cash from Investing',
      '₹${NumberFormat('#,##,###.##').format(cashFlowData['investing'])}'
    ]);
    csvData.add(['']);

    // Financing Activities
    csvData.add(['FINANCING ACTIVITIES']);
    csvData.add([
      'Net Cash from Financing',
      '₹${NumberFormat('#,##,###.##').format(cashFlowData['financing'])}'
    ]);
    csvData.add(['']);

    // Net Cash Flow
    csvData.add([
      'NET CASH FLOW',
      '₹${NumberFormat('#,##,###.##').format(cashFlowData['net_cash_flow'])}'
    ]);
    csvData.add(['']);
    csvData.add([
      'Beginning Cash Balance',
      '₹${NumberFormat('#,##,###.##').format(cashFlowData['beginning_balance'])}'
    ]);
    csvData.add([
      'Ending Cash Balance',
      '₹${NumberFormat('#,##,###.##').format(cashFlowData['ending_balance'])}'
    ]);

    return await _saveCSVFile(csvData, 'cash_flow_${_getDateString()}.csv');
  }

  // Export GST Analysis to CSV
  static Future<String> exportGSTAnalysisToCSV(
      Map<String, dynamic> gstData) async {
    final csvData = <List<String>>[];

    // Headers
    csvData.add(['GST ANALYSIS REPORT']);
    csvData.add(['As of ${DateFormat(_dateFormat).format(DateTime.now())}']);
    csvData.add(['']);

    // GST Summary
    csvData.add(['GST SUMMARY']);
    csvData.add([
      'GST Collected',
      '₹${NumberFormat('#,##,###.##').format(gstData['gst_collected'])}'
    ]);
    csvData.add([
      'GST Paid',
      '₹${NumberFormat('#,##,###.##').format(gstData['gst_paid'])}'
    ]);
    csvData.add([
      'Net GST Liability',
      '₹${NumberFormat('#,##,###.##').format(gstData['net_liability'])}'
    ]);
    csvData.add([
      'Compliance Score',
      '${NumberFormat('#,##0.0').format(gstData['compliance_score'])}%'
    ]);
    csvData.add(['']);

    // GST Rate Breakdown
    csvData.add(['GST RATE BREAKDOWN']);
    final rateBreakdown = gstData['rate_breakdown'] as Map<double, double>;
    rateBreakdown.forEach((rate, amount) {
      csvData.add([
        '${NumberFormat('#,##0.0').format(rate)}%',
        '₹${NumberFormat('#,##,###.##').format(amount)}'
      ]);
    });

    return await _saveCSVFile(csvData, 'gst_analysis_${_getDateString()}.csv');
  }

  // Export Inventory Analysis to CSV
  static Future<String> exportInventoryAnalysisToCSV(
      Map<String, dynamic> inventoryData) async {
    final csvData = <List<String>>[];

    // Headers
    csvData.add(['INVENTORY ANALYSIS REPORT']);
    csvData.add(
        ['Generated on ${DateFormat(_dateFormat).format(DateTime.now())}']);
    csvData.add(['']);

    // Summary
    csvData.add(['SUMMARY']);
    csvData.add([
      'Total Value',
      '₹${NumberFormat('#,##,###.##').format(inventoryData['total_value'])}'
    ]);
    csvData.add(['Total Items', inventoryData['total_items'].toString()]);
    csvData.add([
      'Inventory Turnover',
      NumberFormat('#,##0.00').format(inventoryData['inventory_turnover'])
    ]);
    csvData.add(['']);

    // Top Selling Items
    csvData.add(['TOP SELLING ITEMS']);
    csvData.add(['Item Name', 'Quantity', 'Value']);

    final topItems = inventoryData['top_selling'] as List<Map<String, dynamic>>;
    for (final item in topItems) {
      csvData.add([
        item['name'].toString(),
        NumberFormat('#,##0').format(item['quantity']),
        '₹${NumberFormat('#,##,###.##').format(item['value'])}'
      ]);
    }

    return await _saveCSVFile(
        csvData, 'inventory_analysis_${_getDateString()}.csv');
  }

  // Export Sales Trends to CSV
  static Future<String> exportSalesTrendsToCSV(List<Invoice> invoices) async {
    final csvData = <List<String>>[];

    // Headers
    csvData.add(['SALES TRENDS REPORT']);
    csvData.add(
        ['Generated on ${DateFormat(_dateFormat).format(DateTime.now())}']);
    csvData.add(['']);

    // Sales Data
    csvData.add(['Date', 'Invoice Number', 'Amount', 'Tax Amount', 'Total']);

    final salesInvoices = invoices
        .where((invoice) => invoice.invoiceDirection == InvoiceDirection.sales)
        .toList()
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

    for (final invoice in salesInvoices) {
      csvData.add([
        DateFormat(_dateFormat).format(invoice.invoiceDate),
        invoice.invoiceNumber,
        NumberFormat('#,##,###.##')
            .format(invoice.totalAmount - invoice.taxAmount),
        NumberFormat('#,##,###.##').format(invoice.taxAmount),
        NumberFormat('#,##,###.##').format(invoice.totalAmount),
      ]);
    }

    return await _saveCSVFile(csvData, 'sales_trends_${_getDateString()}.csv');
  }

  // Share exported file
  static Future<void> shareFile(String filePath, String subject) async {
    await Share.shareFiles([filePath], subject: subject);
  }

  // Helper methods
  static String _formatLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            word.length > 0 ? word[0].toUpperCase() + word.substring(1) : word)
        .join(' ');
  }

  static String _getDateString() {
    return DateFormat('yyyyMMdd').format(DateTime.now());
  }

  static Future<String> _saveCSVFile(
      List<List<String>> csvData, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    final csv = const ListToCsvConverter().convert(csvData);
    final file = File(filePath);
    await file.writeAsString(csv);

    return filePath;
  }
}
