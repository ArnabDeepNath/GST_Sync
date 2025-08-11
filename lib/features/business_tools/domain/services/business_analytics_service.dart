import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:intl/intl.dart';

class BusinessAnalyticsService {
  // Calculate monthly sales trends
  List<FlSpot> generateSalesTrendData(List<Invoice> invoices) {
    final Map<int, double> monthlyData = {};
    final now = DateTime.now();

    // Initialize last 12 months
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyData[month.month] = 0.0;
    }

    // Return empty data if no invoices
    if (invoices.isEmpty) {
      return monthlyData.entries
          .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));
    }

    // Aggregate sales data
    for (final invoice in invoices) {
      try {
        final month = invoice.invoiceDate.month;
        if (invoice.invoiceDirection == InvoiceDirection.sales) {
          monthlyData[month] = (monthlyData[month] ?? 0) + invoice.totalAmount;
        }
      } catch (e) {
        print('Warning: Error processing invoice ${invoice.id}: $e');
        continue;
      }
    }

    return monthlyData.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  // Calculate GST liability by month
  List<FlSpot> generateGSTLiabilityData(List<Invoice> invoices) {
    final Map<int, double> monthlyGST = {};
    final now = DateTime.now();

    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyGST[month.month] = 0.0;
    }

    for (final invoice in invoices) {
      final month = invoice.invoiceDate.month;
      monthlyGST[month] = (monthlyGST[month] ?? 0) + invoice.taxAmount;
    }

    return monthlyGST.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  // Generate expense breakdown pie chart data
  List<PieChartSectionData> generateExpenseBreakdown(List<Invoice> invoices) {
    final Map<String, double> categoryTotals = {
      'Purchase': 0.0,
      'Office Expenses': 0.0,
      'Travel': 0.0,
      'Marketing': 0.0,
      'Other': 0.0,
    };

    for (final invoice in invoices) {
      if (invoice.invoiceDirection == InvoiceDirection.purchase) {
        categoryTotals['Purchase'] =
            (categoryTotals['Purchase'] ?? 0) + invoice.totalAmount;
      }
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    int index = 0;
    return categoryTotals.entries
        .where((entry) => entry.value > 0)
        .map((entry) => PieChartSectionData(
              color: colors[index++ % colors.length],
              value: entry.value,
              title:
                  '${entry.key}\n₹${NumberFormat.compact().format(entry.value)}',
              radius: 100,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ))
        .toList();
  }

  // Calculate balance sheet data
  Map<String, dynamic> generateBalanceSheetData(
      List<Invoice> invoices, List<InvoiceItem> items) {
    double totalAssets = 0.0;
    double totalLiabilities = 0.0;
    double totalEquity = 0.0;
    // Calculate from invoices
    double accountsReceivable = 0.0;
    double accountsPayable = 0.0;
    for (final invoice in invoices) {
      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        accountsReceivable +=
            invoice.totalAmount; // Simplified - assume all pending
      } else {
        accountsPayable += invoice.totalAmount;
      }
    }

    // Calculate actual inventory value from invoice items
    double inventoryValue = 0.0;
    final Map<String, double> itemQuantities = {};
    final Map<String, double> itemCosts = {};
    for (final item in items) {
      itemQuantities[item.name] =
          (itemQuantities[item.name] ?? 0) + item.quantity;
      itemCosts[item.name] =
          item.unitPrice; // Use latest unit price as current cost
    }

    // Calculate total inventory value
    itemQuantities.forEach((itemName, quantity) {
      final cost = itemCosts[itemName] ?? 0.0;
      inventoryValue += quantity * cost;
    });

    // Calculate cash flow from revenue minus expenses
    double totalRevenue = 0.0;
    double totalExpenses = 0.0;
    for (final invoice in invoices) {
      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        totalRevenue += invoice.totalAmount;
      } else {
        totalExpenses += invoice.totalAmount;
      }
    }

    // Estimate cash as 20% of net revenue (simplified calculation)
    double estimatedCash = (totalRevenue - totalExpenses) * 0.2;
    if (estimatedCash < 0) estimatedCash = 0.0;

    // Calculate total assets and equity
    totalAssets = estimatedCash + accountsReceivable + inventoryValue;
    totalLiabilities =
        accountsPayable + invoices.fold(0.0, (sum, inv) => sum + inv.taxAmount);
    totalEquity = totalAssets - totalLiabilities;

    return {
      'assets': {
        'current_assets': {
          'cash': estimatedCash,
          'accounts_receivable': accountsReceivable,
          'inventory': inventoryValue,
        },
        'total': totalAssets,
      },
      'liabilities': {
        'current_liabilities': {
          'accounts_payable': accountsPayable,
          'gst_payable': invoices.fold(0.0, (sum, inv) => sum + inv.taxAmount),
        },
        'total': totalLiabilities,
      },
      'equity': {
        'retained_earnings': totalEquity,
        'total': totalEquity,
      }
    };
  }

  // Calculate profit and loss data
  Map<String, dynamic> generateProfitLossData(
      List<Invoice> invoices, DateTime startDate, DateTime endDate) {
    double totalRevenue = 0.0;
    double totalExpenses = 0.0;
    double totalTaxes = 0.0;

    final filteredInvoices = invoices
        .where((invoice) =>
            invoice.invoiceDate.isAfter(startDate) &&
            invoice.invoiceDate.isBefore(endDate))
        .toList();

    for (final invoice in filteredInvoices) {
      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        totalRevenue += invoice.totalAmount;
      } else {
        totalExpenses += invoice.totalAmount;
      }
      totalTaxes += invoice.taxAmount;
    }

    final grossProfit = totalRevenue - totalExpenses;
    final netProfit = grossProfit - totalTaxes;

    return {
      'revenue': {
        'sales': totalRevenue,
        'total': totalRevenue,
      },
      'expenses': {
        'cost_of_goods_sold': totalExpenses * 0.7,
        'operating_expenses': totalExpenses * 0.3,
        'taxes': totalTaxes,
        'total': totalExpenses + totalTaxes,
      },
      'profit': {
        'gross_profit': grossProfit,
        'net_profit': netProfit,
        'profit_margin':
            totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0,
      }
    };
  }

  // Generate inventory analysis
  Map<String, dynamic> generateInventoryAnalysis(List<InvoiceItem> items) {
    if (items.isEmpty) {
      return {
        'total_value': 0.0,
        'total_items': 0,
        'inventory_turnover': 0.0,
        'top_selling': <Map<String, dynamic>>[],
      };
    }

    final Map<String, double> itemQuantities = {};
    final Map<String, double> itemValues = {};

    for (final item in items) {
      try {
        itemQuantities[item.name] =
            (itemQuantities[item.name] ?? 0) + item.quantity;
        itemValues[item.name] = (itemValues[item.name] ?? 0) + item.totalPrice;
      } catch (e) {
        print('Warning: Error processing item ${item.id}: $e');
        continue;
      }
    }

    // Calculate top-selling items
    final topItems = itemValues.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalInventoryValue =
        itemValues.values.fold(0.0, (sum, value) => sum + value);

    return {
      'total_value': totalInventoryValue,
      'total_items': itemQuantities.length,
      'top_selling': topItems
          .take(10)
          .map((entry) => {
                'name': entry.key,
                'value': entry.value,
                'quantity': itemQuantities[entry.key] ?? 0,
              })
          .toList(),
      'inventory_turnover': totalInventoryValue > 0
          ? (totalInventoryValue / 30)
          : 0, // Simplified
    };
  }

  // Calculate cash flow data
  Map<String, dynamic> generateCashFlowData(
      List<Invoice> invoices, DateTime startDate, DateTime endDate) {
    double operatingCashFlow = 0.0;
    double investingCashFlow = 0.0;
    double financingCashFlow = 0.0;

    final filteredInvoices = invoices
        .where((invoice) =>
            invoice.invoiceDate.isAfter(startDate) &&
            invoice.invoiceDate.isBefore(endDate))
        .toList();

    for (final invoice in filteredInvoices) {
      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        operatingCashFlow += invoice.totalAmount;
      } else {
        operatingCashFlow -= invoice.totalAmount;
      }
    }

    // Calculate beginning balance from historical data (before start date)
    double beginningBalance = 0.0;
    final historicalInvoices = invoices
        .where((invoice) => invoice.invoiceDate.isBefore(startDate))
        .toList();

    for (final invoice in historicalInvoices) {
      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        beginningBalance += invoice.totalAmount;
      } else {
        beginningBalance -= invoice.totalAmount;
      }
    }

    // Ensure minimum balance of 0
    if (beginningBalance < 0) beginningBalance = 0.0;

    final netCashFlow =
        operatingCashFlow + investingCashFlow + financingCashFlow;

    return {
      'operating': operatingCashFlow,
      'investing': investingCashFlow,
      'financing': financingCashFlow,
      'net_cash_flow': netCashFlow,
      'beginning_balance': beginningBalance,
      'ending_balance': beginningBalance + netCashFlow,
    };
  }

  // Generate GST analysis data
  Map<String, dynamic> generateGSTAnalysis(List<Invoice> invoices) {
    double totalGSTCollected = 0.0;
    double totalGSTPaid = 0.0;
    final Map<double, double> gstRateBreakdown = {};

    for (final invoice in invoices) {
      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        totalGSTCollected += invoice.taxAmount;
      } else {
        totalGSTPaid += invoice.taxAmount;
      }
      // Simplified GST rate calculation
      final taxRate = invoice.totalAmount > 0
          ? (invoice.taxAmount / invoice.totalAmount) * 100
          : 0.0;
      gstRateBreakdown[taxRate] =
          (gstRateBreakdown[taxRate] ?? 0.0) + invoice.taxAmount;
    }

    final netGSTLiability = totalGSTCollected - totalGSTPaid;

    // Calculate compliance score based on actual data
    double complianceScore = 100.0;

    // Reduce score if GST liability is high relative to collection
    if (totalGSTCollected > 0) {
      final liabilityRatio = netGSTLiability / totalGSTCollected;
      if (liabilityRatio > 0.5) {
        complianceScore -= 20.0; // High unpaid GST liability
      } else if (liabilityRatio > 0.3) {
        complianceScore -= 10.0; // Moderate unpaid GST liability
      }
    }

    // Reduce score if there are too few invoices (indicating poor record keeping)
    if (invoices.length < 10) {
      complianceScore -= 15.0;
    } else if (invoices.length < 5) {
      complianceScore -= 25.0;
    }

    // Ensure score doesn't go below 0
    if (complianceScore < 0) complianceScore = 0.0;

    return {
      'gst_collected': totalGSTCollected,
      'gst_paid': totalGSTPaid,
      'net_liability': netGSTLiability,
      'rate_breakdown': gstRateBreakdown,
      'compliance_score': complianceScore,
    };
  }
}
