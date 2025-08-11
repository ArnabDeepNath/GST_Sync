import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:gspappv2/features/invoice/presentation/bloc/invoice_bloc.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';
import 'package:gspappv2/features/invoice/presentation/widgets/item_selection_dialog_proper.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:gspappv2/features/party/presentation/bloc/party_bloc.dart';
import 'package:gspappv2/features/party/presentation/pages/add_edit_party_page.dart';
// import 'package:gspappv2/features/invoice/presentation/widgets/item_selection_dialog.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class CreateInvoicePage extends StatefulWidget {
  final InvoiceDirection initialDirection;

  const CreateInvoicePage({
    Key? key,
    this.initialDirection = InvoiceDirection.sales,
  }) : super(key: key);

  @override
  _CreateInvoicePageState createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage>
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
  bool _showPartyList = false;
  String _selectedStoreId = '';
  PartyType _selectedType = PartyType.buyer;
  InvoiceDirection _invoiceDirection = InvoiceDirection.sales;
  bool _isLoading = false;

  // Step titles and descriptions
  final List<String> _stepTitles = [
    'Invoice Type',
    'Select Customer',
    'Add Items (Optional)',
    'Amount & Summary'
  ];

  final List<String> _stepDescriptions = [
    'Choose whether this is a sales or purchase invoice',
    'Pick an existing customer or add a new one',
    'Add individual items or skip to enter total amount',
    'Enter total amount and complete your invoice'
  ];

  @override
  void initState() {
    super.initState();
    _invoiceDirection = widget.initialDirection;
    _selectedType = _invoiceDirection == InvoiceDirection.sales
        ? PartyType.buyer
        : PartyType.seller;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _loadParties();
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
        return true; // Invoice type is always selected
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
          'Create New Invoice',
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
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step ${_currentStep + 1} of $_totalSteps',
              style: TextStyle(
                color: Colors.blue[700],
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
              'Please select a store from the menu to create invoices',
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
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? Colors.blue
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _totalSteps - 1)
                  Container(
                    width: 8,
                    height: 4,
                    color: Colors.transparent,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepHeader() {
    return Container(
      width: double.infinity,
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
          _buildInvoiceTypeCard(
            title: 'Sales Invoice',
            subtitle: 'Selling goods or services to customers',
            icon: Icons.trending_up,
            color: Colors.green,
            isSelected: _invoiceDirection == InvoiceDirection.sales,
            onTap: () => _onDirectionChanged(InvoiceDirection.sales),
          ),
          const SizedBox(height: 16),
          _buildInvoiceTypeCard(
            title: 'Purchase Invoice',
            subtitle: 'Buying goods or services from suppliers',
            icon: Icons.trending_down,
            color: Colors.blue,
            isSelected: _invoiceDirection == InvoiceDirection.purchase,
            onTap: () => _onDirectionChanged(InvoiceDirection.purchase),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Sales invoices are for money coming in, Purchase invoices are for money going out',
                    style: TextStyle(
                      color: Colors.blue[700],
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
              color: isSelected
                  ? color.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
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
                color: isSelected ? color : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
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
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedParty != null) ...[
            _buildSelectedPartyCard(),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedParty = null;
                  _showPartyList = false;
                });
              },
              icon: const Icon(Icons.change_circle_outlined),
              label: Text(_invoiceDirection == InvoiceDirection.sales
                  ? 'Change Customer'
                  : 'Change Supplier'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ] else ...[
            _buildPartySelector(),
            const SizedBox(height: 20),
            if (_showPartyList)
              _buildPartyList()
            else
              _buildAddNewPartyOption(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedPartyCard() {
    if (_selectedParty == null) return const SizedBox.shrink();

    return Container(
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
    );
  }

  Widget _buildPartySelector() {
    return GestureDetector(
      onTap: () => setState(() => _showPartyList = !_showPartyList),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
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
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _invoiceDirection == InvoiceDirection.sales
                    ? Icons.person_search
                    : Icons.business_center,
                color: Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _invoiceDirection == InvoiceDirection.sales
                    ? 'Select Customer *'
                    : 'Select Supplier *',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              _showPartyList
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a new one below',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children:
                      parties.map((party) => _buildPartyTile(party)).toList(),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'Failed to load parties',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPartyTile(Party party) {
    return ListTile(
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
          _showPartyList = false;
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

  Widget _buildItemTile(InvoiceItem item) {
    return ListTile(
      title: Text(item.name),
      subtitle: Text('HSN/SAC: ${item.hsn}'),
      trailing: Text(
        '₹${item.totalPrice}',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
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
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _saveInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save'),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.share),
              onPressed: _handleShare,
            ),
          ),
        ],
      ),
    );
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

  String _calculateBalance() {
    final total = double.tryParse(_totalController.text) ?? 0.0;
    final received = double.tryParse(_receivedController.text) ?? 0.0;
    return (total - received).toStringAsFixed(2);
  }

  void _saveInvoice() async {
    print('DEBUG: _saveInvoice method called');

    // Add detailed field validation debugging before form validation
    print('DEBUG: Form field values check:');
    print('DEBUG: - Total: "${_totalController.text}"');
    print('DEBUG: - Received: "${_receivedController.text}"');
    print('DEBUG: - Notes: "${_notesController.text}"');
    print('DEBUG: - Selected Party: ${_selectedParty?.name ?? "null"}');
    print('DEBUG: - Selected Store ID: $_selectedStoreId');
    print('DEBUG: - Items count: ${_items.length}');

    // Check individual field validations manually
    List<String> validationErrors = [];

    // Check total amount
    if (_totalController.text.isEmpty) {
      validationErrors.add('Total amount is empty');
    } else {
      final totalAmount = double.tryParse(_totalController.text);
      if (totalAmount == null) {
        validationErrors.add('Total amount is not a valid number');
      } else if (totalAmount <= 0) {
        validationErrors.add('Total amount must be greater than 0');
      }
    }

    // Check party selection
    if (_selectedParty == null) {
      validationErrors.add('No party selected');
    }

    // Check store selection
    if (_selectedStoreId.isEmpty) {
      validationErrors.add('No store selected');
    }

    if (validationErrors.isNotEmpty) {
      print('DEBUG: Manual validation errors found:');
      for (String error in validationErrors) {
        print('DEBUG: - $error');
      }
    } else {
      print('DEBUG: Manual validation passed for all fields');
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      print(
          'DEBUG: Form validation failed - FormKey.currentState.validate() returned false');
      print(
          'DEBUG: This indicates one or more TextFormField validators are returning error messages');

      // Additional debugging for form validation
      if (_totalController.text.isEmpty) {
        print('DEBUG: Total amount field is empty');
      } else {
        print('DEBUG: Total amount field value: "${_totalController.text}"');
        final amount = double.tryParse(_totalController.text);
        if (amount == null) {
          print('DEBUG: Total amount is not a valid number');
        } else if (amount <= 0) {
          print('DEBUG: Total amount is not positive: $amount');
        }
      }
      return;
    }

    print('DEBUG: Form validation passed successfully');

    // Validate required fields
    if (_selectedParty == null) {
      print('DEBUG: No party selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer/supplier')),
      );
      return;
    }

    if (_selectedStoreId.isEmpty) {
      print('DEBUG: No store selected');
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
        : _items.fold(
            0.0,
            (sum, item) =>
                sum + item.taxAmount); // Ensure we have a non-zero amount
    if (totalAmount <= 0) {
      print('DEBUG: Invalid amount: $totalAmount');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    print('DEBUG: Starting invoice creation with amount: $totalAmount');

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Creating InvoiceRepository instance');
      // Use the repository directly (create instance like other parts of the app)
      final invoiceRepository = InvoiceRepository();

      print(
          'DEBUG: Calling addInvoice with storeId: $_selectedStoreId, partyId: ${_selectedParty!.id}');

      await invoiceRepository.addInvoice(
        storeId: _selectedStoreId,
        partyId: _selectedParty!.id,
        invoiceNumber: _generateInvoiceNumber(),
        invoiceDate: DateTime.now(),
        totalAmount: totalAmount,
        taxAmount: taxAmount,
        notes: _notesController.text.trim(),
        invoiceDirection: _invoiceDirection.toString().split('.').last,
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
      );

      print('DEBUG: Invoice created successfully!');

      // Invoice created successfully
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the invoices list in the background
        context.read<InvoiceBloc>().add(LoadInvoices(_selectedStoreId));

        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('DEBUG: Error creating invoice: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Stack trace: ${StackTrace.current}');

      // Handle any errors
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateInvoiceNumber() {
    // Generate a unique invoice number with prefix based on direction
    final prefix =
        _invoiceDirection == InvoiceDirection.sales ? 'SINV' : 'PINV';
    final timestamp =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return '$prefix-$timestamp';
  }

  void _handleShare() {
    // Create a summary text for sharing
    final total = double.tryParse(_totalController.text) ?? 0.0;
    final received = double.tryParse(_receivedController.text) ?? 0.0;

    final shareText = '''
Invoice Summary
================
Type: ${_invoiceDirection == InvoiceDirection.sales ? 'Sales Invoice' : 'Purchase Invoice'}
${_invoiceDirection == InvoiceDirection.sales ? 'Customer' : 'Supplier'}: ${_selectedParty?.name ?? 'Not selected'}
Items: ${_items.length}
Total Amount: ₹${total.toStringAsFixed(2)}
${received > 0 ? 'Amount Received: ₹${received.toStringAsFixed(2)}\n' : ''}Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}
${_notesController.text.isNotEmpty ? '\nNotes: ${_notesController.text}' : ''}

Generated by GST App V2
''';

    // You can implement actual sharing here using share_plus package
    // For now, copy to clipboard or show share dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice preview ready: ${shareText.length} characters'),
        duration: const Duration(seconds: 2),
      ),
    );

    // TODO: Implement actual sharing with share_plus package
    // Share.share(shareText, subject: 'Invoice Summary');
  }

  void _onDirectionChanged(InvoiceDirection direction) {
    setState(() {
      _invoiceDirection = direction;
      _selectedType = direction == InvoiceDirection.sales
          ? PartyType.buyer
          : PartyType.seller;
      _selectedParty = null; // Reset party selection when changing direction
    });
    _loadParties();
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

  Widget _buildItemsStep() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_items.isNotEmpty) ...[
            Text(
              'Added Items (${_items.length})',
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
                    'Items are optional. You can skip this step and enter the total amount directly.',
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
        border: index < _items.length - 1
            ? Border(bottom: BorderSide(color: Colors.grey[200]!))
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: Colors.blue[700],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate_outlined,
                            color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Text(
                          'Calculated from Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total amount has been calculated from ${_items.length} item(s)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildStyledAmountField('Total Amount *', _totalController,
                prefixIcon: Icons.currency_rupee, isRequired: true),
            const SizedBox(height: 16),
            _buildStyledAmountField('Amount Received', _receivedController,
                prefixIcon: Icons.payment),
            const SizedBox(height: 20),
            _buildBalanceCard(),
            const SizedBox(height: 20),
            _buildNotesField(),
            const SizedBox(height: 20),
            _buildInvoiceSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledAmountField(String label, TextEditingController controller,
      {IconData? prefixIcon, bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey[600])
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: isRequired
              ? (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter the total amount';
                  }
                  final amount = double.tryParse(value!);
                  if (amount == null) {
                    return 'Please enter a valid amount';
                  }
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final total = double.tryParse(_totalController.text) ?? 0.0;
    final received = double.tryParse(_receivedController.text) ?? 0.0;
    final balance = total - received;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: balance > 0 ? Colors.orange[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: balance > 0 ? Colors.orange[200]! : Colors.green[200]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance Due',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                balance > 0 ? 'Amount Pending' : 'Fully Paid',
                style: TextStyle(
                  fontSize: 12,
                  color: balance > 0 ? Colors.orange[700] : Colors.green[700],
                ),
              ),
            ],
          ),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: balance > 0 ? Colors.orange[700] : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional notes for this invoice...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummaryCard() {
    final total = double.tryParse(_totalController.text) ?? 0.0;
    final received = double.tryParse(_receivedController.text) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Text(
                'Invoice Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                  ? (_currentStep == _totalSteps - 1 ? _saveInvoice : _nextStep)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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
                        ? (_isLoading ? 'Creating...' : 'Create Invoice')
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
}
