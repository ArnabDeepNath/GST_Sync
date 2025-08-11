import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:gspappv2/features/invoice/domain/models/document_type.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';
import 'package:gspappv2/features/invoice/presentation/widgets/item_selection_dialog_proper.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:gspappv2/features/party/presentation/bloc/party_bloc.dart';
import 'package:gspappv2/features/party/presentation/pages/add_edit_party_page.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class EditInvoicePage extends StatefulWidget {
  final Invoice invoice;

  const EditInvoicePage({
    Key? key,
    required this.invoice,
  }) : super(key: key);

  @override
  _EditInvoicePageState createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Step tracking
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Form data
  Party? _selectedParty;
  final List<InvoiceItem> _items = [];
  final _totalController = TextEditingController();
  final _receivedController = TextEditingController();
  final _notesController = TextEditingController();
  // UI state
  String _selectedStoreId = '';
  PartyType _selectedType = PartyType.buyer;
  InvoiceDirection _invoiceDirection = InvoiceDirection.sales;
  bool _isLoading = false;

  // Amendment tracking
  bool _hasChanges = false;

  // Step titles and descriptions
  final List<String> _stepTitles = [
    'Invoice Type',
    'Select Customer',
    'Edit Items',
    'Amount & Summary'
  ];

  final List<String> _stepDescriptions = [
    'Review invoice type',
    'Update customer information if needed',
    'Modify items and quantities',
    'Review and save amended invoice'
  ];
  @override
  void initState() {
    super.initState();
    _invoiceDirection = widget.invoice.invoiceDirection;
    _selectedType = _invoiceDirection == InvoiceDirection.sales
        ? PartyType.buyer
        : PartyType.seller;

    // Initialize with existing invoice data
    _totalController.text = widget.invoice.totalAmount.toString();
    _notesController.text = widget.invoice.notes ?? '';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _loadInvoiceData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _totalController.dispose();
    _receivedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadInvoiceData() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

    if (storeProvider.selectedStore != null) {
      _selectedStoreId = storeProvider.selectedStore!.id;

      // Load parties
      context.read<PartyBloc>().add(
            LoadParties(
              storeProvider.selectedStore!.id,
              type: _selectedType,
            ),
          );

      // Load invoice items and party details
      await _loadInvoiceItems();
      await _loadPartyDetails();
    }
  }

  Future<void> _loadInvoiceItems() async {
    try {
      final invoiceRepository = InvoiceRepository();
      final items = await invoiceRepository
          .getInvoiceItems(_selectedStoreId, widget.invoice.id)
          .first;

      setState(() {
        _items.clear();
        _items.addAll(items);
        _updateTotal();
      });
    } catch (e) {
      print('Error loading invoice items: $e');
    }
  }

  Future<void> _loadPartyDetails() async {
    try {
      final partyBloc = context.read<PartyBloc>();
      final partyState = partyBloc.state;

      if (partyState is PartiesLoaded) {
        final party = partyState.parties
            .where((p) => p.id == widget.invoice.partyId)
            .firstOrNull;

        if (party != null) {
          setState(() {
            _selectedParty = party;
          });
        }
      }
    } catch (e) {
      print('Error loading party details: $e');
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return true; // Invoice type is read-only in edit mode
      case 1:
        return _selectedParty != null;
      case 2:
        return true; // Items are optional
      case 3:
        return _totalController.text.isNotEmpty &&
            (double.tryParse(_totalController.text) ?? 0) > 0;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Invoice',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step ${_currentStep + 1} of $_totalSteps',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: storeProvider.selectedStore == null
          ? _buildNoStoreSelected()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildProgressIndicator(),
                  _buildStepHeader(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentStep = index;
                        });
                      },
                      children: [
                        _buildInvoiceTypeStep(),
                        _buildCustomerSelectionStep(),
                        _buildItemsStep(),
                        _buildAmountStep(),
                      ],
                    ),
                  ),
                  _buildNavigationButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildNoStoreSelected() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Store Selected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a store from the menu to edit invoices',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          bool isCompleted = index < _currentStep;
          bool isCurrent = index == _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                right: index < _totalSteps - 1 ? 8 : 0,
              ),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? Colors.orange
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isCompleted || isCurrent
                          ? Colors.orange
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stepTitles[_currentStep],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _stepDescriptions[_currentStep],
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTypeStep() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Editing this invoice will create an amended version. The original invoice will remain unchanged.',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildInvoiceTypeCard(
            title: _invoiceDirection == InvoiceDirection.sales
                ? 'Sales Invoice'
                : 'Purchase Invoice',
            subtitle: _invoiceDirection == InvoiceDirection.sales
                ? 'Selling goods or services to customers'
                : 'Buying goods or services from suppliers',
            icon: _invoiceDirection == InvoiceDirection.sales
                ? Icons.trending_up
                : Icons.trending_down,
            color: _invoiceDirection == InvoiceDirection.sales
                ? Colors.green
                : Colors.blue,
            isSelected: true,
            onTap: () {}, // Read-only in edit mode
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Invoice: ${widget.invoice.invoiceNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy').format(widget.invoice.invoiceDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedParty != null) ...[
          Container(
            margin: const EdgeInsets.all(20),
            child: _buildSelectedPartyCard(),
          ),
        ] else ...[
          Expanded(child: _buildPartySelectionList()),
        ],
      ],
    );
  }

  Widget _buildSelectedPartyCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedParty = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _invoiceDirection == InvoiceDirection.sales
                    ? Icons.person
                    : Icons.business,
                color: Colors.green[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedParty!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (_selectedParty!.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _selectedParty!.phone!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.check_circle,
              color: Colors.green[700],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartySelectionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _invoiceDirection == InvoiceDirection.sales
                ? 'Choose Customer'
                : 'Choose Supplier',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        BlocBuilder<PartyBloc, PartyState>(
          builder: (context, state) {
            if (state is PartyLoading) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (state is PartiesLoaded) {
              final parties = state.parties
                  .where((party) => party.type == _selectedType)
                  .toList();

              if (parties.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _invoiceDirection == InvoiceDirection.sales
                            ? 'No customers found'
                            : 'No suppliers found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAddNewPartyOption(),
                    ],
                  ),
                );
              }

              return Expanded(
                child: ListView(
                  children: [
                    ...parties.map((party) => _buildPartyTile(party)),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildAddNewPartyOption(),
                    ),
                  ],
                ),
              );
            }

            return const Center(child: Text('Error loading parties'));
          },
        ),
      ],
    );
  }

  Widget _buildPartyTile(Party party) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: _invoiceDirection == InvoiceDirection.sales
            ? Colors.blue[100]
            : Colors.green[100],
        child: Icon(
          _invoiceDirection == InvoiceDirection.sales
              ? Icons.person
              : Icons.business,
          color: _invoiceDirection == InvoiceDirection.sales
              ? Colors.blue[700]
              : Colors.green[700],
        ),
      ),
      title: Text(
        party.name,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: party.phone != null ? Text(party.phone!) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        setState(() {
          _selectedParty = party;
          _hasChanges = party.id != widget.invoice.partyId;
        });
      },
    );
  }

  Widget _buildAddNewPartyOption() {
    return GestureDetector(
      onTap: () => _navigateToAddParty(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: Colors.blue[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _invoiceDirection == InvoiceDirection.sales
                        ? 'Add New Customer'
                        : 'Add New Supplier',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create a new contact for future invoices',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.blue[700],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsStep() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_items.isNotEmpty) ...[
            Text(
              'Items (${_items.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: _items.asMap().entries.map((entry) {
                  int index = entry.key;
                  InvoiceItem item = entry.value;
                  return _buildItemCard(item, index);
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildAddItemButton(),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Modify items as needed. Changes will create an amended invoice.',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(InvoiceItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: index < _items.length - 1
              ? BorderSide(color: Colors.grey[200]!)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity.toStringAsFixed(0)} × ₹${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (item.hsn != null && item.hsn!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'HSN: ${item.hsn}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _removeItem(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red[600],
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemButton() {
    return GestureDetector(
      onTap: _showAddItemDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.blue[300]!, style: BorderStyle.solid),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: Colors.blue[700],
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add Item',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add products or services to this invoice',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _updateTotal();
      _hasChanges = true;
    });
  }

  Widget _buildAmountStep() {
    return Form(
      key: _formKey,
      child: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_items.isNotEmpty) ...[
              _buildItemsSummary(),
              const SizedBox(height: 24),
            ],
            _buildAmountSection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
            const SizedBox(height: 32),
            _buildInvoiceSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSummary() {
    final totalItems = _items.length;
    final totalQuantity =
        _items.fold<double>(0, (sum, item) => sum + item.quantity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Items:', style: TextStyle(color: Colors.grey[600])),
              Text('$totalItems',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Quantity:',
                  style: TextStyle(color: Colors.grey[600])),
              Text('${totalQuantity.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return Column(
      children: [
        _buildAmountField('Total Amount', _totalController),
        const SizedBox(height: 16),
        _buildAmountField('Received', _receivedController),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Balance Due',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
            Text(
              '₹${_calculateBalance()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) {
        setState(() {
          _hasChanges = true;
        });
      },
    );
  }

  Widget _buildNotesSection() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Notes (Optional)',
        hintText: 'Add any additional notes...',
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) {
        setState(() {
          _hasChanges = true;
        });
      },
    );
  }

  Widget _buildInvoiceSummary() {
    final total = double.tryParse(_totalController.text) ?? 0.0;
    final received = double.tryParse(_receivedController.text) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.orange[700]),
              const SizedBox(width: 12),
              Text(
                'Amendment Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Original Invoice', widget.invoice.invoiceNumber),
          _buildSummaryRow(
              'New Invoice Number', 'AMD-${widget.invoice.invoiceNumber}'),
          _buildSummaryRow(
              'Type',
              _invoiceDirection == InvoiceDirection.sales
                  ? 'Sales Invoice'
                  : 'Purchase Invoice'),
          _buildSummaryRow('Customer', _selectedParty?.name ?? 'Not selected'),
          _buildSummaryRow('Items', '${_items.length}'),
          _buildSummaryRow('Total Amount', '₹${total.toStringAsFixed(2)}'),
          if (received > 0)
            _buildSummaryRow(
                'Amount Received', '₹${received.toStringAsFixed(2)}'),
          _buildSummaryRow(
              'Date', DateFormat('MMM dd, yyyy').format(DateTime.now())),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Previous',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _canProceedToNextStep()
                  ? (_currentStep == _totalSteps - 1
                      ? _saveAmendedInvoice
                      : _nextStep)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    _currentStep == _totalSteps - 1
                        ? (_isLoading
                            ? 'Creating Amendment...'
                            : 'Save Amendment')
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_currentStep < _totalSteps - 1 && !_isLoading) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateBalance() {
    final total = double.tryParse(_totalController.text) ?? 0.0;
    final received = double.tryParse(_receivedController.text) ?? 0.0;
    return (total - received).toStringAsFixed(2);
  }

  void _showAddItemDialog() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;
    if (selectedStore == null) return;
    final item = await showDialog<InvoiceItem>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        storeId: selectedStore.id,
      ),
    );

    if (item != null) {
      setState(() {
        _items.add(item);
        _updateTotal();
        _hasChanges = true;
      });
    }
  }

  void _updateTotal() {
    final total = _items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    // Only update the field if there are items, otherwise let user enter manually
    if (_items.isNotEmpty) {
      _totalController.text = total.toString();
    }
  }

  void _navigateToAddParty() async {
    if (_selectedStoreId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a store first')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditPartyPage(
          storeId: _selectedStoreId,
          partyType: _selectedType,
        ),
      ),
    );

    if (result != null) {
      // Reload parties if a new party was added
      _loadParties();
    }
  }

  void _loadParties() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

    if (storeProvider.selectedStore != null) {
      _selectedStoreId = storeProvider.selectedStore!.id;
      context.read<PartyBloc>().add(
            LoadParties(
              storeProvider.selectedStore!.id,
              type: _selectedType,
            ),
          );
    }
  }

  void _saveAmendedInvoice() async {
    print('DEBUG: _saveAmendedInvoice method called');

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected')),
      );
      return;
    }

    // Validate required fields
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer/supplier')),
      );
      return;
    }

    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No store selected')),
      );
      return;
    }

    // Calculate totals from items if available
    double totalAmount = _items.isEmpty
        ? (double.tryParse(_totalController.text) ?? 0.0)
        : _items.fold(0.0, (sum, item) => sum + item.totalPrice);

    double taxAmount = _items.isEmpty
        ? 0.0 // No tax estimation when manually entering total
        : _items.fold(0.0, (sum, item) => sum + item.taxAmount);

    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Generate amended invoice number
      final amendedInvoiceNumber = 'AMD-${widget.invoice.invoiceNumber}';

      // Create amended invoice using repository
      final invoiceRepository = InvoiceRepository();

      // Create the amended invoice based on the original
      final amendedInvoice = widget.invoice.createAmendedInvoice(
        newId: DateTime.now().millisecondsSinceEpoch.toString(),
        newInvoiceNumber: amendedInvoiceNumber,
        newReason:
            'Invoice amended on ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );

      // Update the amended invoice with new values
      final updatedAmendedInvoice = Invoice(
        id: amendedInvoice.id,
        invoiceNumber: amendedInvoice.invoiceNumber,
        invoiceDate: DateTime.now(), // Use current date for amendment
        partyId: _selectedParty!.id,
        totalAmount: totalAmount,
        taxAmount: taxAmount,
        notes: _notesController.text.isEmpty
            ? amendedInvoice.notes
            : _notesController.text,
        storeId: selectedStore.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        invoiceDirection: _invoiceDirection,
        documentType: DocumentType.invoice,
        originalDocumentId: widget.invoice.id, // Link to original invoice
        reason: amendedInvoice.reason,
      );

      // Save to Firestore
      await invoiceRepository.addInvoice(
        storeId: selectedStore.id,
        partyId: updatedAmendedInvoice.partyId,
        invoiceNumber: updatedAmendedInvoice.invoiceNumber,
        invoiceDate: updatedAmendedInvoice.invoiceDate,
        totalAmount: updatedAmendedInvoice.totalAmount,
        taxAmount: updatedAmendedInvoice.taxAmount,
        notes: updatedAmendedInvoice.notes,
        invoiceDirection:
            updatedAmendedInvoice.invoiceDirection.toString().split('.').last,
        items: _items
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  'taxRate': item.taxRate,
                  'totalPrice': item.totalPrice,
                  'hsn': item.hsn,
                })
            .toList(),
        documentType: DocumentType.invoice.toString().split('.').last,
        originalDocumentId: widget.invoice.id,
        reason: updatedAmendedInvoice.reason,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Amended invoice $amendedInvoiceNumber created successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back to invoice list
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('DEBUG: Error saving amended invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating amended invoice: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
