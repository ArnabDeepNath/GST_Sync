import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';

class BusinessToolsDataService {
  // DEPRECATED: Generate sample invoice items for demonstration
  // This method is no longer used as we now load real data from the database
  @deprecated
  static List<InvoiceItem> generateSampleInvoiceItems(List<Invoice> invoices) {
    final List<InvoiceItem> items = [];

    // Sample item data for different categories
    final sampleItems = [
      {'name': 'Widget A', 'hsn': '9999', 'category': 'Electronics'},
      {'name': 'Component B', 'hsn': '8888', 'category': 'Parts'},
      {'name': 'Service C', 'hsn': '7777', 'category': 'Services'},
      {'name': 'Material D', 'hsn': '6666', 'category': 'Raw Materials'},
      {'name': 'Product E', 'hsn': '5555', 'category': 'Finished Goods'},
      {'name': 'Tool F', 'hsn': '4444', 'category': 'Equipment'},
      {'name': 'Supply G', 'hsn': '3333', 'category': 'Office Supplies'},
      {'name': 'Item H', 'hsn': '2222', 'category': 'Inventory'},
      {'name': 'Asset I', 'hsn': '1111', 'category': 'Fixed Assets'},
      {'name': 'Consumable J', 'hsn': '0000', 'category': 'Consumables'},
    ];

    int itemIndex = 0;

    for (final invoice in invoices) {
      // Generate 1-5 items per invoice
      final itemCount = (invoice.totalAmount / 1000).clamp(1, 5).round();

      for (int i = 0; i < itemCount; i++) {
        final sampleItem = sampleItems[itemIndex % sampleItems.length];
        final unitPrice = (invoice.totalAmount / itemCount) / (i + 1);
        final quantity = (i + 1).toDouble();
        final taxRate = invoice.totalAmount > 0
            ? (invoice.taxAmount / invoice.totalAmount) * 100
            : 18.0;
        items.add(InvoiceItem(
          id: 'item_${invoice.id}_$i',
          invoiceId: invoice.id,
          name: sampleItem['name']!,
          quantity: quantity,
          unitPrice: unitPrice,
          taxRate: taxRate,
          totalPrice: unitPrice * quantity,
          hsn: sampleItem['hsn']!,
          createdAt: invoice.createdAt,
        ));

        itemIndex++;
      }
    }

    return items;
  }

  // Generate business insights
  static Map<String, dynamic> generateBusinessInsights(List<Invoice> invoices) {
    final totalInvoices = invoices.length;
    final totalRevenue = invoices
        .where((inv) => inv.invoiceDirection == InvoiceDirection.sales)
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    final totalExpenses = invoices
        .where((inv) => inv.invoiceDirection == InvoiceDirection.purchase)
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    final avgInvoiceValue =
        totalInvoices > 0 ? totalRevenue / totalInvoices : 0.0;
    final profitMargin = totalRevenue > 0
        ? ((totalRevenue - totalExpenses) / totalRevenue) * 100
        : 0.0;

    // Calculate monthly trends
    final monthlyData = <int, Map<String, double>>{};
    for (final invoice in invoices) {
      final month = invoice.invoiceDate.month;
      monthlyData[month] ??= {'revenue': 0.0, 'expenses': 0.0};

      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        monthlyData[month]!['revenue'] =
            (monthlyData[month]!['revenue'] ?? 0) + invoice.totalAmount;
      } else {
        monthlyData[month]!['expenses'] =
            (monthlyData[month]!['expenses'] ?? 0) + invoice.totalAmount;
      }
    }

    return {
      'summary': {
        'total_invoices': totalInvoices,
        'total_revenue': totalRevenue,
        'total_expenses': totalExpenses,
        'avg_invoice_value': avgInvoiceValue,
        'profit_margin': profitMargin,
        'net_profit': totalRevenue - totalExpenses,
      },
      'monthly_trends': monthlyData,
      'top_performers': _getTopPerformers(invoices),
      'gst_summary': _getGSTSummary(invoices),
    };
  }

  static List<Map<String, dynamic>> _getTopPerformers(List<Invoice> invoices) {
    // Group by month and find top performing months
    final monthlyRevenue = <int, double>{};

    for (final invoice in invoices) {
      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        final month = invoice.invoiceDate.month;
        monthlyRevenue[month] =
            (monthlyRevenue[month] ?? 0) + invoice.totalAmount;
      }
    }

    final sortedMonths = monthlyRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedMonths
        .take(3)
        .map((entry) => {
              'month': _getMonthName(entry.key),
              'revenue': entry.value,
            })
        .toList();
  }

  static Map<String, dynamic> _getGSTSummary(List<Invoice> invoices) {
    double totalGSTCollected = 0.0;
    double totalGSTPaid = 0.0;
    final Map<String, double> gstRates = {};

    for (final invoice in invoices) {
      final gstAmount = invoice.taxAmount;
      final rate = invoice.totalAmount > 0
          ? ((invoice.taxAmount / (invoice.totalAmount - invoice.taxAmount)) *
                  100)
              .round()
          : 18;

      if (invoice.invoiceDirection == InvoiceDirection.sales) {
        totalGSTCollected += gstAmount;
      } else {
        totalGSTPaid += gstAmount;
      }

      final rateKey = '${rate}%';
      gstRates[rateKey] = (gstRates[rateKey] ?? 0) + gstAmount;
    }

    return {
      'total_collected': totalGSTCollected,
      'total_paid': totalGSTPaid,
      'net_liability': totalGSTCollected - totalGSTPaid,
      'rate_breakdown': gstRates,
      'filing_due_date': _getNextFilingDate(),
    };
  }

  static String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }

  static String _getNextFilingDate() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 11);
    return '${nextMonth.day}/${nextMonth.month}/${nextMonth.year}';
  }
}
