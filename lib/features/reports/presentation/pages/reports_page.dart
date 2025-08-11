import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/reports/domain/models/filed_report.dart';
import 'package:gspappv2/features/reports/domain/models/report_type.dart';
import 'package:gspappv2/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:gspappv2/features/reports/presentation/pages/report_filing_page.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<ReportType> _reportTypes = ReportType.values.toList();
  ReportType _selectedReportType = ReportType.gstr1;

  // Filter variables
  String _statusFilter = 'All';
  String _directionFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  final List<String> _statusOptions = [
    'All',
    'Success',
    'Filed',
    'Processing',
    'Error',
    'Pending OTP'
  ];
  final List<String> _directionOptions = ['All', 'Inward', 'Outward'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _reportTypes.length, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Load reports for the selected store
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedReportType = _reportTypes[_tabController.index];
      });
      // When tab changes, we filter the reports in the bloc state
      final currentState = context.read<ReportsBloc>().state;
      if (currentState is FiledReportsLoaded) {
        context.read<ReportsBloc>().add(
              _UpdateTabSelection(_selectedReportType),
            );
      }
    }
  }

  void _loadReports() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore != null) {
      context.read<ReportsBloc>().add(LoadFiledReports(selectedStore.id));
    }
  }

  // Reset all filters
  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _directionFilter = 'All';
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    return Column(
      children: [
        // Tab bar
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: _reportTypes.map((type) => Tab(text: type.title)).toList(),
        ),
        // Content
        Expanded(
          child: selectedStore == null
              ? const Center(child: Text('Please select a store from the menu'))
              : BlocConsumer<ReportsBloc, ReportsState>(
                  listener: (context, state) {
                    if (state is ReportsError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message)),
                      );
                    } else if (state is ReportDeleteSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Report deleted successfully')),
                      );
                      // Reload reports
                      _loadReports();
                    }
                  },
                  builder: (context, state) {
                    if (state is ReportsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is FiledReportsLoaded) {
                      // Get all reports for statistics
                      final allReports = state.reports;

                      // Filter reports by the selected tab type
                      final typeFilteredReports = allReports
                          .where((report) => report.type == _selectedReportType)
                          .toList();

                      // Apply additional filters
                      final filteredReports = _applyFilters(typeFilteredReports);

                      return Column(
                        children: [
                          if (_showFilters) _buildFilterSection(context),

                          // Dashboard summary
                          _buildReportsDashboard(typeFilteredReports),

                          // Reports list
                          Expanded(
                            child: _buildReportsList(filteredReports),
                          ),
                        ],
                      );
                    }
                    // Initial state or other states
                    return const Center(
                      child: Text('Loading reports...'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Apply all active filters to the reports list
  List<FiledReport> _applyFilters(List<FiledReport> reports) {
    return reports.where((report) {
      // Status filter
      if (_statusFilter != 'All' &&
          !report.status.toLowerCase().contains(_statusFilter.toLowerCase())) {
        return false;
      }

      // Direction filter
      if (_directionFilter != 'All' &&
          (report.directionType == null ||
              !report.directionType!
                  .toLowerCase()
                  .contains(_directionFilter.toLowerCase()))) {
        return false;
      }

      // Date range filter - start date
      if (_startDate != null && report.filedDate.isBefore(_startDate!)) {
        return false;
      }

      // Date range filter - end date
      if (_endDate != null) {
        // Add one day to include the end date fully
        final endDatePlusOne = _endDate!.add(const Duration(days: 1));
        if (report.filedDate.isAfter(endDatePlusOne)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Build the filtering section
  Widget _buildFilterSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filters:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Reset'),
                onPressed: _resetFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status and Direction Filters
          Row(
            children: [
              // Status Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _statusFilter = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Direction Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _directionFilter,
                  decoration: const InputDecoration(
                    labelText: 'Direction',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: _directionOptions.map((direction) {
                    return DropdownMenuItem(
                      value: direction,
                      child: Text(direction),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _directionFilter = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date Range Filters
          Row(
            children: [
              // Start Date
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (selectedDate != null) {
                      setState(() {
                        _startDate = selectedDate;
                      });
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _startDate == null
                              ? 'Start Date'
                              : DateFormat('dd/MM/yyyy').format(_startDate!),
                          style: TextStyle(
                            color: _startDate == null
                                ? Colors.grey[600]
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // End Date
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (selectedDate != null) {
                      setState(() {
                        _endDate = selectedDate;
                      });
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _endDate == null
                              ? 'End Date'
                              : DateFormat('dd/MM/yyyy').format(_endDate!),
                          style: TextStyle(
                            color: _endDate == null
                                ? Colors.grey[600]
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build a dashboard summary of reports
  Widget _buildReportsDashboard(List<FiledReport> reports) {
    // Count reports by status
    final successCount = reports
        .where((r) =>
            r.status.toLowerCase() == 'success' ||
            r.status.toLowerCase() == 'filed')
        .length;

    final pendingCount = reports
        .where((r) =>
            r.status.toLowerCase() == 'processing' ||
            r.status.toLowerCase() == 'pending otp')
        .length;

    final errorCount = reports
        .where((r) =>
            r.status.toLowerCase() == 'error' ||
            r.status.toLowerCase() == 'failed')
        .length;

    // Count inward vs outward
    final inwardCount =
        reports.where((r) => r.directionType?.toLowerCase() == 'inward').length;

    final outwardCount = reports
        .where((r) => r.directionType?.toLowerCase() == 'outward')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filing Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildStatCard(
                'Success',
                successCount.toString(),
                Colors.green[100]!,
                Colors.green,
              ),
              _buildStatCard(
                'Pending',
                pendingCount.toString(),
                Colors.orange[100]!,
                Colors.orange,
              ),
              _buildStatCard(
                'Failed',
                errorCount.toString(),
                Colors.red[100]!,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildStatCard(
                'Outward',
                outwardCount.toString(),
                Colors.blue[100]!,
                Colors.blue,
                iconData: Icons.arrow_upward,
              ),
              _buildStatCard(
                'Inward',
                inwardCount.toString(),
                Colors.purple[100]!,
                Colors.purple,
                iconData: Icons.arrow_downward,
              ),
              _buildStatCard(
                'Total',
                reports.length.toString(),
                Colors.grey[200]!,
                Colors.grey[800]!,
                iconData: Icons.receipt_long,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build a stat card for the dashboard
  Widget _buildStatCard(
      String title, String value, Color bgColor, Color textColor,
      {IconData iconData = Icons.check_circle}) {
    return Expanded(
      child: Card(
        color: bgColor,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconData, color: textColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList(List<FiledReport> reports) {
    if (reports.isEmpty) {
      return const Center(
        child: Text('No reports found. File a new report.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shrinkWrap: false,
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 5),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      report.type.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      report.period,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Filed on: ${DateFormat('dd/MM/yyyy').format(report.filedDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStatusColor(report.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(report.status),
                            color: _getStatusColor(report.status),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            report.status,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(report.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Show direction type if available
                    if (report.directionType != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              report.directionType!.toLowerCase() == 'outward'
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              report.directionType!.toLowerCase() == 'outward'
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: report.directionType!.toLowerCase() ==
                                      'outward'
                                  ? Colors.blue
                                  : Colors.purple,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDirectionType(report.directionType!),
                              style: TextStyle(
                                fontSize: 12,
                                color: report.directionType!.toLowerCase() ==
                                        'outward'
                                    ? Colors.blue
                                    : Colors.purple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Show ARN if available
                if (report.acknowledgmentNo != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Acknowledgment Number:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SelectableText(
                                report.acknowledgmentNo!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Show error message if available and status is error
                if (report.errorMessage != null &&
                    report.status.toLowerCase() == 'error') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Error Message:',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (report.acknowledgmentNo != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('View PDF'),
                        onPressed: () => _viewReportPdf(report),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      onPressed: () => _confirmDelete(context, report),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'filed':
      case 'success':
        return Colors.green;
      case 'pending':
      case 'processing':
      case 'pending otp':
        return Colors.orange;
      case 'error':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'filed':
      case 'success':
        return Icons.check_circle;
      case 'pending':
      case 'processing':
      case 'pending otp':
        return Icons.hourglass_empty;
      case 'error':
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDirectionType(String directionType) {
    switch (directionType.toLowerCase()) {
      case 'inward':
        return 'Inward';
      case 'outward':
        return 'Outward';
      default:
        return directionType.capitalize();
    }
  }

  void _navigateToFilingPage(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportFilingPage(type: _selectedReportType),
      ),
    ).then((_) {
      // Reload reports when returning from filing page
      _loadReports();
    });
  }

  void _confirmDelete(BuildContext context, FiledReport report) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
            'Are you sure you want to delete this ${report.type.title} report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete the report
              context.read<ReportsBloc>().add(
                    DeleteFiledReport(selectedStore.id, report.id),
                  );
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _viewReportPdf(FiledReport report) {
    // Show a message that PDF viewing is not implemented yet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF viewing not implemented yet'),
      ),
    );
  }
}

// Helper class for text capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Private event for internal use
class _UpdateTabSelection extends ReportsEvent {
  final ReportType selectedType;

  const _UpdateTabSelection(this.selectedType);

  @override
  List<Object?> get props => [selectedType];
}
