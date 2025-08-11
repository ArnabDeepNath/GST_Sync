enum BusinessToolType {
  gstFiling,
  balanceSheet,
  profitLoss,
  cashFlow,
  taxAnalysis,
  inventoryAnalysis,
  salesTrends,
  expenseTracker,
  gstReturns,
  financialReports
}

class BusinessTool {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final BusinessToolType type;
  final String route;
  final bool isPremium;
  final String description;

  const BusinessTool({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
    required this.route,
    this.isPremium = false,
    required this.description,
  });
}

// Define the 10 business tools
class BusinessTools {
  static const List<BusinessTool> tools = [
    BusinessTool(
      id: 'gst_filing',
      title: 'GST Filing Assistant',
      subtitle: 'Generate GSTR-1, GSTR-3B reports',
      icon: '📋',
      type: BusinessToolType.gstFiling,
      route: '/gst-filing',
      description:
          'Automatically generate GST returns with B2B, B2C, and HSN summaries',
    ),
    BusinessTool(
      id: 'balance_sheet',
      title: 'Balance Sheet',
      subtitle: 'Assets, Liabilities & Equity',
      icon: '⚖️',
      type: BusinessToolType.balanceSheet,
      route: '/balance-sheet',
      description: 'Complete balance sheet with automated calculations',
    ),
    BusinessTool(
      id: 'profit_loss',
      title: 'Profit & Loss Report',
      subtitle: 'Income vs Expenses analysis',
      icon: '📊',
      type: BusinessToolType.profitLoss,
      route: '/profit-loss',
      description: 'Detailed P&L statement with period comparisons',
    ),
    BusinessTool(
      id: 'cash_flow',
      title: 'Cash Flow Statement',
      subtitle: 'Track money in & out',
      icon: '💰',
      type: BusinessToolType.cashFlow,
      route: '/cash-flow',
      description: 'Monitor cash movements and liquidity',
    ),
    BusinessTool(
      id: 'tax_analysis',
      title: 'Tax Analysis Dashboard',
      subtitle: 'GST liability & savings',
      icon: '🧮',
      type: BusinessToolType.taxAnalysis,
      route: '/tax-analysis',
      description: 'Comprehensive tax liability analysis and optimization',
    ),
    BusinessTool(
      id: 'inventory_analysis',
      title: 'Store Stock Analysis',
      subtitle: 'Inventory & stock levels',
      icon: '📦',
      type: BusinessToolType.inventoryAnalysis,
      route: '/inventory-analysis',
      description: 'Track inventory turnover and stock optimization',
    ),
    BusinessTool(
      id: 'sales_trends',
      title: 'Sales Trends & Analytics',
      subtitle: 'Revenue patterns & forecasts',
      icon: '📈',
      type: BusinessToolType.salesTrends,
      route: '/sales-trends',
      description: 'Analyze sales patterns and predict future trends',
    ),
    BusinessTool(
      id: 'expense_tracker',
      title: 'Expense Tracker',
      subtitle: 'Categorize & control costs',
      icon: '💳',
      type: BusinessToolType.expenseTracker,
      route: '/expense-tracker',
      description: 'Track and categorize business expenses',
    ),
    BusinessTool(
      id: 'gst_returns',
      title: 'GST Returns Manager',
      subtitle: 'GSTR-2A, GSTR-2B reconciliation',
      icon: '📄',
      type: BusinessToolType.gstReturns,
      route: '/gst-returns',
      description: 'Manage and reconcile all GST return types',
    ),
    BusinessTool(
      id: 'financial_reports',
      title: 'Financial Reports Hub',
      subtitle: 'Export all business reports',
      icon: '📑',
      type: BusinessToolType.financialReports,
      route: '/financial-reports',
      description: 'Generate and export comprehensive business reports',
    ),
  ];
}
