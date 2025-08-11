import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gspappv2/features/business_tools/domain/models/business_tool.dart';
import 'package:gspappv2/features/business_tools/domain/services/business_analytics_service.dart';
import 'package:gspappv2/features/business_tools/domain/services/simple_report_export_service.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:intl/intl.dart';

class BusinessToolsWidget extends StatefulWidget {
  final List<Invoice> invoices;
  final List<InvoiceItem> invoiceItems;

  const BusinessToolsWidget({
    Key? key,
    required this.invoices,
    required this.invoiceItems,
  }) : super(key: key);

  @override
  State<BusinessToolsWidget> createState() => _BusinessToolsWidgetState();
}

class _BusinessToolsWidgetState extends State<BusinessToolsWidget> {
  final BusinessAnalyticsService _analyticsService = BusinessAnalyticsService();
  int _selectedToolIndex = 0;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Tools & Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Tools Grid
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: BusinessTools.tools.length,
              itemBuilder: (context, index) {
                return _buildToolCard(BusinessTools.tools[index], index);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Selected Tool Details wrapped in another scrollable container
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: _buildToolDetails(BusinessTools.tools[_selectedToolIndex]),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(BusinessTool tool, int index) {
    final isSelected = _selectedToolIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedToolIndex = index;
        });
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tool.icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              tool.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue[700] : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolDetails(BusinessTool tool) {
    switch (tool.type) {
      case BusinessToolType.gstFiling:
        return _buildGSTFilingTool();
      case BusinessToolType.balanceSheet:
        return _buildBalanceSheetTool();
      case BusinessToolType.profitLoss:
        return _buildProfitLossTool();
      case BusinessToolType.cashFlow:
        return _buildCashFlowTool();
      case BusinessToolType.taxAnalysis:
        return _buildTaxAnalysisTool();
      case BusinessToolType.inventoryAnalysis:
        return _buildInventoryAnalysisTool();
      case BusinessToolType.salesTrends:
        return _buildSalesTrendsTool();
      case BusinessToolType.expenseTracker:
        return _buildExpenseTrackerTool();
      case BusinessToolType.gstReturns:
        return _buildGSTReturnsTool();
      case BusinessToolType.financialReports:
        return _buildFinancialReportsTool();
    }
  }

  Widget _buildGSTFilingTool() {
    final gstData = _analyticsService.generateGSTAnalysis(widget.invoices);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'GST Filing Assistant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('GST Filing Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'GST Collected',
                  '₹${NumberFormat('#,##,###').format(gstData['gst_collected'])}',
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'GST Paid',
                  '₹${NumberFormat('#,##,###').format(gstData['gst_paid'])}',
                  Colors.orange,
                  Icons.trending_down,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Net Liability',
                  '₹${NumberFormat('#,##,###').format(gstData['net_liability'])}',
                  Colors.blue,
                  Icons.account_balance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compliance Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildComplianceScore(gstData['compliance_score']),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetTool() {
    final balanceSheetData = _analyticsService.generateBalanceSheetData(
      widget.invoices,
      widget.invoiceItems,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚖️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Balance Sheet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('Balance Sheet'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Total Assets',
                  '₹${NumberFormat('#,##,###').format(balanceSheetData['assets']['total'])}',
                  Colors.blue,
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Total Liabilities',
                  '₹${NumberFormat('#,##,###').format(balanceSheetData['liabilities']['total'])}',
                  Colors.red,
                  Icons.credit_card,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Total Equity',
                  '₹${NumberFormat('#,##,###').format(balanceSheetData['equity']['total'])}',
                  Colors.green,
                  Icons.savings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            child: _buildBalanceSheetChart(balanceSheetData),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLossTool() {
    final plData = _analyticsService.generateProfitLossData(
      widget.invoices,
      DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
      DateTime.now(),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Profit & Loss Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('Profit & Loss Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Total Revenue',
                  '₹${NumberFormat('#,##,###').format(plData['revenue']['total'])}',
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Total Expenses',
                  '₹${NumberFormat('#,##,###').format(plData['expenses']['total'])}',
                  Colors.red,
                  Icons.trending_down,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Net Profit',
                  '₹${NumberFormat('#,##,###').format(plData['profit']['net_profit'])}',
                  plData['profit']['net_profit'] > 0
                      ? Colors.green
                      : Colors.red,
                  Icons.account_balance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Profit Margin',
                  '${NumberFormat('#,##0.00').format(plData['profit']['profit_margin'])}%',
                  Colors.blue,
                  Icons.percent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 120,
                  child: _buildProfitLossChart(plData),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrendsTool() {
    final trendData = _analyticsService.generateSalesTrendData(widget.invoices);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Sales Trends & Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('Sales Trends Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 250,
            child: _buildSalesTrendsChart(trendData),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryAnalysisTool() {
    final inventoryData =
        _analyticsService.generateInventoryAnalysis(widget.invoiceItems);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Store Stock Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('Inventory Analysis Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Total Value',
                  '₹${NumberFormat('#,##,###').format(inventoryData['total_value'])}',
                  Colors.blue,
                  Icons.inventory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Total Items',
                  inventoryData['total_items'].toString(),
                  Colors.green,
                  Icons.category,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Turnover Rate',
                  NumberFormat('#,##0.0')
                      .format(inventoryData['inventory_turnover']),
                  Colors.orange,
                  Icons.rotate_right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowTool() {
    final cashFlowData = _analyticsService.generateCashFlowData(
      widget.invoices,
      DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
      DateTime.now(),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💰', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Cash Flow Statement',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('Cash Flow Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Operating Cash Flow',
                  '₹${NumberFormat('#,##,###').format(cashFlowData['operating'])}',
                  Colors.green,
                  Icons.business_center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Net Cash Flow',
                  '₹${NumberFormat('#,##,###').format(cashFlowData['net_cash_flow'])}',
                  cashFlowData['net_cash_flow'] > 0 ? Colors.green : Colors.red,
                  Icons.account_balance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Ending Balance',
                  '₹${NumberFormat('#,##,###').format(cashFlowData['ending_balance'])}',
                  Colors.blue,
                  Icons.savings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxAnalysisTool() {
    final gstData = _analyticsService.generateGSTAnalysis(widget.invoices);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧮', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Tax Analysis Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('Tax Analysis Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 200,
                  child: _buildGSTBreakdownChart(
                      gstData['rate_breakdown'] as Map<double, double>),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildInfoCard(
                      'Total GST Liability',
                      '₹${NumberFormat('#,##,###').format(gstData['net_liability'])}',
                      Colors.red,
                      Icons.receipt_long,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      'Compliance Score',
                      '${NumberFormat('#,##0.0').format(gstData['compliance_score'])}%',
                      Colors.green,
                      Icons.verified,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTrackerTool() {
    final expenseData =
        _analyticsService.generateExpenseBreakdown(widget.invoices);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💳', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Expense Tracker',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('Expense Analysis Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 250,
            child: _buildExpenseBreakdownChart(expenseData),
          ),
        ],
      ),
    );
  }

  Widget _buildGSTReturnsTool() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📄', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'GST Returns Manager',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportReport('GST Returns Report'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildGSTReturnCard(
                      'GSTR-1', 'Sales Returns', 'Due: 11th', Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildGSTReturnCard(
                      'GSTR-3B', 'Monthly Returns', 'Due: 20th', Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildGSTReturnCard('GSTR-2A', 'Purchase Returns',
                      'Auto-populated', Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialReportsTool() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📑', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Financial Reports Hub',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportAllReports(),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth > 600 ? 3 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth > 600 ? 2 : 1.5,
                children: [
                  _buildReportButton(
                      'Balance Sheet', Icons.account_balance, Colors.blue),
                  _buildReportButton(
                      'P&L Statement', Icons.trending_up, Colors.green),
                  _buildReportButton(
                      'Cash Flow', Icons.monetization_on, Colors.orange),
                  _buildReportButton(
                      'GST Analysis', Icons.receipt_long, Colors.purple),
                  _buildReportButton(
                      'Inventory Report', Icons.inventory, Colors.teal),
                  _buildReportButton(
                      'Tax Summary', Icons.calculate, Colors.red),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildInfoCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceScore(double score) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.green[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            strokeWidth: 6,
          ),
          const SizedBox(width: 12),
          Text(
            '${score.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionButton('Generate GSTR-1', Icons.file_download, Colors.blue),
        const SizedBox(height: 8),
        _buildActionButton(
            'Generate GSTR-3B', Icons.file_download, Colors.green),
        const SizedBox(height: 8),
        _buildActionButton('View Filing History', Icons.history, Colors.orange),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _performQuickAction(title),
        icon: Icon(icon, size: 16),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildGSTReturnCard(
      String title, String subtitle, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(String title, IconData icon, Color color) {
    return ElevatedButton(
      onPressed: () => _exportReport(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Chart widgets
  Widget _buildSalesTrendsChart(List<FlSpot> data) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetChart(Map<String, dynamic> data) {
    final assets = data['assets']['total'] as double;
    final liabilities = data['liabilities']['total'] as double;
    final equity = data['equity']['total'] as double;

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.blue,
            value: assets,
            title: 'Assets',
            radius: 60,
          ),
          PieChartSectionData(
            color: Colors.red,
            value: liabilities,
            title: 'Liabilities',
            radius: 60,
          ),
          PieChartSectionData(
            color: Colors.green,
            value: equity,
            title: 'Equity',
            radius: 60,
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLossChart(Map<String, dynamic> data) {
    final revenue = data['revenue']['total'] as double;
    final expenses = data['expenses']['total'] as double;

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.green,
            value: revenue,
            title: 'Revenue',
            radius: 50,
          ),
          PieChartSectionData(
            color: Colors.red,
            value: expenses,
            title: 'Expenses',
            radius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildGSTBreakdownChart(Map<double, double> rateBreakdown) {
    int index = 0;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red
    ];

    return PieChart(
      PieChartData(
        sections: rateBreakdown.entries.map((entry) {
          final color = colors[index++ % colors.length];
          return PieChartSectionData(
            color: color,
            value: entry.value,
            title: '${entry.key.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpenseBreakdownChart(List<PieChartSectionData> data) {
    return PieChart(
      PieChartData(
        sections: data,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  // Action methods
  Future<void> _exportReport(String reportName) async {
    try {
      String? filePath;

      switch (reportName) {
        case 'Balance Sheet':
          final balanceSheetData = _analyticsService.generateBalanceSheetData(
            widget.invoices,
            widget.invoiceItems,
          );
          filePath = await SimpleReportExportService.exportBalanceSheetToCSV(
              balanceSheetData);
          break;

        case 'Profit & Loss Report':
          final plData = _analyticsService.generateProfitLossData(
            widget.invoices,
            DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
            DateTime.now(),
          );
          filePath =
              await SimpleReportExportService.exportProfitLossToCSV(plData);
          break;

        case 'Cash Flow Report':
          final cashFlowData = _analyticsService.generateCashFlowData(
            widget.invoices,
            DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
            DateTime.now(),
          );
          filePath =
              await SimpleReportExportService.exportCashFlowToCSV(cashFlowData);
          break;

        case 'GST Analysis Report':
        case 'GST Filing Report':
        case 'Tax Analysis Report':
          final gstData =
              _analyticsService.generateGSTAnalysis(widget.invoices);
          filePath =
              await SimpleReportExportService.exportGSTAnalysisToCSV(gstData);
          break;

        case 'Inventory Analysis Report':
          final inventoryData =
              _analyticsService.generateInventoryAnalysis(widget.invoiceItems);
          filePath =
              await SimpleReportExportService.exportInventoryAnalysisToCSV(
                  inventoryData);
          break;

        case 'Sales Trends Report':
          filePath = await SimpleReportExportService.exportSalesTrendsToCSV(
              widget.invoices);
          break;

        default:
          // For other reports, show a message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$reportName export feature coming soon!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
      }
      if (filePath.isNotEmpty) {
        // Show success and offer to share
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reportName exported successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                if (filePath != null) {
                  SimpleReportExportService.shareFile(filePath, reportName);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting $reportName: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportAllReports() async {
    try {
      final reports = [
        'Balance Sheet',
        'Profit & Loss Report',
        'Cash Flow Report',
        'GST Analysis Report',
        'Inventory Analysis Report',
        'Sales Trends Report',
      ];

      for (final report in reports) {
        await _exportReport(report);
        // Small delay between exports
        await Future.delayed(const Duration(milliseconds: 500));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All reports exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting reports: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _performQuickAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Performing: $action'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
