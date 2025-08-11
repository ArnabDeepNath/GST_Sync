import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:gspappv2/features/invoice/domain/models/document_type.dart';
import 'package:gspappv2/features/invoice/presentation/bloc/invoice_bloc.dart';
import 'package:gspappv2/features/invoice/presentation/pages/edit_invoice_page.dart';
import 'package:gspappv2/features/invoice/presentation/pages/create_invoice_page.dart';
import 'package:gspappv2/features/invoice/presentation/pages/invoice_preview_page.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:gspappv2/features/party/data/repositories/party_repository.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_with_details.dart';
import 'package:gspappv2/features/invoice/domain/services/invoice_pdf_generator.dart';
import 'package:gspappv2/features/invoice/domain/services/gst_filing_service.dart';

class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  String? _previousStoreId;
  PartyType? _previousPartyType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      _previousStoreId = storeProvider.selectedStore?.id;
      _previousPartyType = storeProvider.selectedPartyType;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeProvider = Provider.of<StoreProvider>(context);
    final currentStoreId = storeProvider.selectedStore?.id;
    final currentPartyType = storeProvider.selectedPartyType;

    // Reload if store or party type changed
    if (_previousStoreId != currentStoreId ||
        _previousPartyType != currentPartyType) {
      _loadInvoices();
      _previousStoreId = currentStoreId;
      _previousPartyType = currentPartyType;
    }
  }

  void _loadInvoices() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore != null) {
      context.read<InvoiceBloc>().add(LoadInvoices(selectedStore.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    return selectedStore == null
        ? const Center(
            child: Text('Please select a store from the menu'),
          )
        : BlocBuilder<InvoiceBloc, InvoiceState>(
            builder: (context, state) {
              if (state is InvoiceInitial) {
                _loadInvoices();
                return const Center(child: CircularProgressIndicator());
              }

              if (state is InvoiceLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is InvoicesLoaded) {
                // Filter invoices based on the current party type
                final filteredInvoices = state.invoices.where((invoice) {
                  final partyType = storeProvider.selectedPartyType;
                  return partyType == PartyType.buyer
                      ? invoice.invoiceDirection == InvoiceDirection.sales
                      : invoice.invoiceDirection == InvoiceDirection.purchase;
                }).toList();

                if (filteredInvoices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          storeProvider.selectedPartyType == PartyType.buyer
                              ? Icons.receipt_long
                              : Icons.shopping_bag,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${storeProvider.selectedPartyType == PartyType.buyer ? "sales" : "purchase"} invoices found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToCreateInvoice(context),
                          icon: const Icon(Icons.add),
                          label: Text(
                              'Create ${storeProvider.selectedPartyType == PartyType.buyer ? "Sales" : "Purchase"} Invoice'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = filteredInvoices[index];
                    return _buildInvoiceCard(context, invoice, index + 1);
                  },
                );
              }
              return const Center(child: Text('No invoices found'));
            },
          );
  }

  void _navigateToCreateInvoice(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInvoicePage(
          initialDirection: storeProvider.selectedPartyType == PartyType.buyer
              ? InvoiceDirection.sales
              : InvoiceDirection.purchase,
        ),
      ),
    ).then((_) => _loadInvoices());
  }

  Widget _buildInvoiceCard(BuildContext context, Invoice invoice, int index) {
    // Calculate financial impact
    final financialImpact = invoice.financialImpact;
    final isPositive = financialImpact > 0;

    return Dismissible(
      key: Key(invoice.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Invoice'),
              content:
                  const Text('Are you sure you want to delete this invoice?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        final storeProvider =
            Provider.of<StoreProvider>(context, listen: false);
        final selectedStore = storeProvider.selectedStore;

        if (selectedStore != null) {
          context
              .read<InvoiceBloc>()
              .add(DeleteInvoice(selectedStore.id, invoice.id));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      invoice.displayTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(invoice.invoiceDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDocumentTypeColor(invoice.documentType),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      invoice.documentType.displayName.toUpperCase(),
                      style: TextStyle(
                        color: _getDocumentTypeTextColor(invoice.documentType),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (invoice.originalDocumentNumber != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'REF: ${invoice.originalDocumentNumber}',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAmountSection(
                      'Total', invoice.totalAmount.abs(), isPositive),
                  _buildAmountSection(
                      'Tax', invoice.taxAmount.abs(), isPositive),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<Party?>(
                future:
                    _getPartyDetailsForDebug(invoice.storeId, invoice.partyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2));
                  }

                  final party = snapshot.data;
                  return Row(
                    children: [
                      Icon(
                        invoice.invoiceDirection == InvoiceDirection.sales
                            ? Icons.person
                            : Icons.store,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          party?.name ?? 'Unknown Party',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPositive ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPositive ? 'INCOME' : 'EXPENSE',
                          style: TextStyle(
                            color: isPositive
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue[400]),
                    onPressed: () => _editInvoice(context, invoice),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: Icon(Icons.picture_as_pdf, color: Colors.red[400]),
                    onPressed: () => _showInvoicePreview(context, invoice),
                    tooltip: 'Preview',
                  ),
                  IconButton(
                    icon: Icon(Icons.share, color: Colors.green[600]),
                    onPressed: () => _shareInvoice(context, invoice),
                    tooltip: 'Share',
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                    onSelected: (value) {
                      switch (value) {
                        case 'amend':
                          _createAmendedInvoice(context, invoice);
                          break;
                        case 'credit_note':
                          _createCreditNote(context, invoice);
                          break;
                        case 'debit_note':
                          _createDebitNote(context, invoice);
                          break;
                        case 'create_quotation':
                          _createQuotationFromInvoice(context, invoice);
                          break;
                        case 'delete':
                          _confirmDelete(context, invoice);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      // Only show these options for original invoices (not amended ones)
                      if (invoice.documentType == DocumentType.invoice &&
                          invoice.originalDocumentId == null)
                        const PopupMenuItem<String>(
                          value: 'amend',
                          child: Row(
                            children: [
                              Icon(Icons.edit_document, size: 18),
                              SizedBox(width: 8),
                              Text('Create Amendment'),
                            ],
                          ),
                        ),
                      if (invoice.documentType == DocumentType.invoice &&
                          invoice.originalDocumentId == null)
                        const PopupMenuItem<String>(
                          value: 'credit_note',
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long, size: 18),
                              SizedBox(width: 8),
                              Text('Create Credit Note'),
                            ],
                          ),
                        ),
                      if (invoice.documentType == DocumentType.invoice &&
                          invoice.originalDocumentId == null)
                        const PopupMenuItem<String>(
                          value: 'debit_note',
                          child: Row(
                            children: [
                              Icon(Icons.description, size: 18),
                              SizedBox(width: 8),
                              Text('Create Debit Note'),
                            ],
                          ),
                        ),
                      if (invoice.documentType == DocumentType.invoice &&
                          invoice.originalDocumentId == null)
                        const PopupMenuItem<String>(
                          value: 'create_quotation',
                          child: Row(
                            children: [
                              Icon(Icons.request_quote, size: 18),
                              SizedBox(width: 8),
                              Text('Create Quotation'),
                            ],
                          ),
                        ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return Colors.green[50]!;
      case DocumentType.returnInvoice:
        return Colors.blue[50]!;
      case DocumentType.creditNote:
        return Colors.red[50]!;
      case DocumentType.debitNote:
        return Colors.orange[50]!;
      case DocumentType.quotation:
        return Colors.purple[50]!;
    }
  }

  Color _getDocumentTypeTextColor(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return Colors.green[700]!;
      case DocumentType.returnInvoice:
        return Colors.blue[700]!;
      case DocumentType.creditNote:
        return Colors.red[700]!;
      case DocumentType.debitNote:
        return Colors.orange[700]!;
      case DocumentType.quotation:
        return Colors.purple[700]!;
    }
  }

  void _editInvoice(BuildContext context, Invoice invoice) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditInvoicePage(
          invoice: invoice,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadInvoices();
      }
    });
  }

  Widget _buildAmountSection(String label, double amount, bool isPositive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Row(
          children: [
            Text(
              isPositive ? '+' : '-',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isPositive ? Colors.green[700] : Colors.red[700],
              ),
            ),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isPositive ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<Party?> _getPartyDetailsForDebug(
      String storeId, String partyId) async {
    try {
      // Try the direct approach first
      final partyRepository = PartyRepository();
      final party = await partyRepository.getPartyById(storeId, partyId);
      return party;
    } catch (e) {
      print('Debug: Failed to get party details: $e');

      // Create a dummy party if all else fails
      return Party(
        id: partyId,
        name: 'Unknown Party',
        type: PartyType.buyer,
        storeId: storeId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  void _showInvoicePreview(BuildContext context, Invoice invoice) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    // First need to get the party details and invoice items
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Create a repository instance
      final invoiceRepository = InvoiceRepository();

      // Use a different approach for getting the party
      Future.wait([
        _getPartyDetailsForDebug(invoice.storeId, invoice.partyId),
        invoiceRepository.getInvoiceItems(invoice.storeId, invoice.id).first,
      ]).then((results) {
        // Pop the loading dialog
        Navigator.pop(context);

        final party = results[0] as Party;
        final items = results[1] as List<InvoiceItem>;

        // Create a complete invoice model for the preview
        final completeInvoice = InvoiceWithDetails(
          invoice: invoice,
          party: party,
          items: items,
          store: selectedStore,
        );

        // Navigate to preview page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoicePreviewPage(
              invoiceWithDetails: completeInvoice,
            ),
          ),
        );
      }).catchError((error) {
        // Pop the loading dialog
        Navigator.pop(context);

        // Show detailed error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invoice details: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        print('Error in _showInvoicePreview: $error');
      });
    } catch (e) {
      // Handle any synchronous errors
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Synchronous error in _showInvoicePreview: $e');
    }
  }

  Future<void> _shareInvoice(BuildContext context, Invoice invoice) async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Create repository instance
      final invoiceRepository = InvoiceRepository();

      print(
          'Debug: Getting party for storeId: ${invoice.storeId}, partyId: ${invoice.partyId}');

      // Load party and invoice items in parallel
      final results = await Future.wait([
        _getPartyDetailsForDebug(invoice.storeId, invoice.partyId),
        invoiceRepository.getInvoiceItems(invoice.storeId, invoice.id).first,
      ]);

      final party = results[0] as Party;
      final items = results[1] as List<InvoiceItem>;

      print('Debug: Party loaded: ${party.name}, Items count: ${items.length}');

      // Create a complete invoice model for the PDF generation
      final completeInvoice = InvoiceWithDetails(
        invoice: invoice,
        party: party,
        items: items,
        store: selectedStore,
      );

      // Generate PDF
      final pdfGenerator = InvoicePdfGenerator();
      final pdfBytes = await pdfGenerator.generatePdf(completeInvoice);

      // Pop loading dialog
      Navigator.pop(context);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/invoice_${invoice.invoiceNumber}.pdf';

      // Write PDF to file
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Share the file
      await Share.shareFiles(
        [filePath],
        text: 'Invoice #${invoice.invoiceNumber}',
        subject: 'Invoice #${invoice.invoiceNumber} - ${party.name}',
      );
    } catch (e) {
      // Pop loading dialog
      Navigator.pop(context);

      // Show detailed error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing invoice: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      print('Error in _shareInvoice: $e');
    }
  }

  void _confirmDelete(BuildContext context, Invoice invoice) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Invoice'),
          content: const Text('Are you sure you want to delete this invoice?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context
                    .read<InvoiceBloc>()
                    .add(DeleteInvoice(selectedStore.id, invoice.id));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice deleted')),
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _prepareGstFiling(BuildContext context) async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a store first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final invoiceState = context.read<InvoiceBloc>().state;
      if (invoiceState is! InvoicesLoaded) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No invoices available for GST filing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final invoices = invoiceState.invoices;
      final invoiceRepository = InvoiceRepository();
      final invoicesWithDetails = <InvoiceWithDetails>[];

      // Process each invoice to get the complete details
      for (final invoice in invoices) {
        try {
          final results = await Future.wait([
            _getPartyDetailsForDebug(invoice.storeId, invoice.partyId),
            invoiceRepository
                .getInvoiceItems(invoice.storeId, invoice.id)
                .first,
          ]);

          final party = results[0] as Party;
          final items = results[1] as List<InvoiceItem>;

          invoicesWithDetails.add(InvoiceWithDetails(
            invoice: invoice,
            party: party,
            items: items,
            store: selectedStore,
          ));
        } catch (e) {
          print('Error loading details for invoice ${invoice.id}: $e');
          // Continue with next invoice
        }
      }

      // Close the loading dialog
      Navigator.pop(context);

      if (invoicesWithDetails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid invoices for GST filing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Generate the GST filing data
      final gstFilingService = GstFilingService();
      final gstFilingData =
          gstFilingService.convertToGstFilingFormat(invoicesWithDetails);

      // Show the filing data in a dialog
      _showGstFilingDialog(context, gstFilingData);
    } catch (e) {
      // Close the loading dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparing GST filing: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error in _prepareGstFiling: $e');
    }
  }

  void _showGstFilingDialog(BuildContext context, String gstFilingData) {
    // Parse the JSON to extract sales and purchase data
    Map<String, dynamic> filingDataMap = {};
    try {
      filingDataMap = json.decode(gstFilingData) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing GST filing data: $e');
    }

    // Create pretty-printed individual data sections
    final salesDataJson = filingDataMap.containsKey('saleData')
        ? JsonEncoder.withIndent('  ')
            .convert({'saleData': filingDataMap['saleData']})
        : '{"saleData": []}';

    final purchaseDataJson = filingDataMap.containsKey('purchaseData')
        ? JsonEncoder.withIndent('  ')
            .convert({'purchaseData': filingDataMap['purchaseData']})
        : '{"purchaseData": []}';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DefaultTabController(
          length: 3, // All data, Sales data, Purchase data
          child: Dialog(
            child: Container(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GST Filing Data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    tabs: const [
                      Tab(text: 'All Data'),
                      Tab(text: 'Sales'),
                      Tab(text: 'Purchases'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // All data tab
                        _buildJsonDataView(gstFilingData),

                        // Sales data tab
                        _buildJsonDataView(salesDataJson),

                        // Purchase data tab
                        _buildJsonDataView(purchaseDataJson),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Get the currently selected tab index
                          final tabController =
                              DefaultTabController.of(context);
                          final selectedTab = tabController.index;

                          // Copy the appropriate data based on selected tab
                          String dataToCopy = gstFilingData;
                          if (selectedTab == 1) {
                            dataToCopy = salesDataJson;
                          } else if (selectedTab == 2) {
                            dataToCopy = purchaseDataJson;
                          }

                          Clipboard.setData(ClipboardData(text: dataToCopy));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text('Copy to Clipboard'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            // Get the currently selected tab index
                            final tabController =
                                DefaultTabController.of(context);
                            final selectedTab = tabController.index;

                            // Save the appropriate data based on selected tab
                            String dataToShare = gstFilingData;
                            String fileName = 'gst_filing_data.json';

                            if (selectedTab == 1) {
                              dataToShare = salesDataJson;
                              fileName = 'gst_sales_data.json';
                            } else if (selectedTab == 2) {
                              dataToShare = purchaseDataJson;
                              fileName = 'gst_purchase_data.json';
                            }

                            final directory = await getTemporaryDirectory();
                            final file = File('${directory.path}/$fileName');
                            await file.writeAsBytes(utf8.encode(dataToShare));

                            await Share.shareFiles(
                              [file.path],
                              text: 'GST Filing Data',
                              subject:
                                  'GST Filing Data for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Error sharing file: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build JSON data view with consistent styling
  Widget _buildJsonDataView(String jsonData) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: SelectableText(
          jsonData,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }

  // Creates a new amended invoice based on the selected invoice
  void _createAmendedInvoice(BuildContext context, Invoice invoice) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    // Show a dialog to get amendment reason
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String reason = 'Amendment to original invoice';
        final reasonController = TextEditingController(text: reason);

        return AlertDialog(
          title: const Text('Create Amended Invoice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Creating an amended version of Invoice #${invoice.invoiceNumber}'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Amendment',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) {
                  reason = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                try {
                  final invoiceRepository = InvoiceRepository();

                  // Generate a new invoice number with AMD prefix
                  final newInvoiceNumber = 'AMD-${invoice.invoiceNumber}';

                  // Create the amended invoice
                  final amendedInvoice = invoice.createAmendedInvoice(
                    newId: DateTime.now().millisecondsSinceEpoch.toString(),
                    newInvoiceNumber: newInvoiceNumber,
                    newReason: reason,
                  );

                  // Save to Firestore with the correct method signature
                  final createdInvoice = await invoiceRepository.addInvoice(
                    storeId: selectedStore.id,
                    partyId: amendedInvoice.partyId,
                    invoiceNumber: amendedInvoice.invoiceNumber,
                    invoiceDate: amendedInvoice.invoiceDate,
                    totalAmount: amendedInvoice.totalAmount,
                    taxAmount: amendedInvoice.taxAmount,
                    notes: amendedInvoice.notes,
                    invoiceDirection: amendedInvoice.invoiceDirection
                        .toString()
                        .split('.')
                        .last,
                    documentType:
                        amendedInvoice.documentType.toString().split('.').last,
                    originalDocumentId: amendedInvoice.originalDocumentId,
                    originalDocumentNumber:
                        amendedInvoice.originalDocumentNumber,
                    reason: amendedInvoice.reason,
                  );

                  // Get items from original invoice
                  final originalItems = await invoiceRepository
                      .getInvoiceItems(invoice.storeId, invoice.id)
                      .first;

                  // Convert items to format accepted by addItemsToInvoice
                  final itemMaps = originalItems
                      .map((item) => {
                            'name': item.name,
                            'quantity': item.quantity,
                            'unitPrice': item.unitPrice,
                            'taxRate': item.taxRate,
                            'totalPrice': item.totalPrice,
                            'hsn': item.hsn,
                            'invoiceId': createdInvoice.id,
                          })
                      .toList();

                  // Add items to the amended invoice
                  await invoiceRepository.addItemsToInvoice(
                    selectedStore.id,
                    createdInvoice.id,
                    itemMaps,
                  );

                  // Reload the invoice list
                  _loadInvoices();

                  // Check if we need to switch tabs to show the amended invoice
                  final currentPartyType = storeProvider.selectedPartyType;
                  final shouldSwitchTab = (amendedInvoice.invoiceDirection ==
                              InvoiceDirection.sales &&
                          currentPartyType != PartyType.buyer) ||
                      (amendedInvoice.invoiceDirection ==
                              InvoiceDirection.purchase &&
                          currentPartyType != PartyType.seller);

                  if (shouldSwitchTab) {
                    // Switch to the appropriate tab
                    final newPartyType = amendedInvoice.invoiceDirection ==
                            InvoiceDirection.sales
                        ? PartyType.buyer
                        : PartyType.seller;
                    await storeProvider.togglePartyType(newPartyType);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Amended invoice ${amendedInvoice.invoiceNumber} created and switched to ${amendedInvoice.invoiceDirection == InvoiceDirection.sales ? "Customers" : "Suppliers"} tab'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Amended invoice ${amendedInvoice.invoiceNumber} created'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Error creating amended invoice: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Create Amended Invoice'),
            ),
          ],
        );
      },
    );
  }

  // Creates a credit note based on the selected invoice
  void _createCreditNote(BuildContext context, Invoice invoice) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    // Show a dialog to get credit note details
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String reason = 'Return of goods';
        final reasonController = TextEditingController(text: reason);
        bool fullCredit = true;
        double creditAmount = invoice.totalAmount;
        double creditTax = invoice.taxAmount;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Credit Note'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Creating credit note for Invoice #${invoice.invoiceNumber}'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Full Credit'),
                  subtitle: const Text('Credit the entire invoice amount'),
                  value: fullCredit,
                  onChanged: (value) {
                    setState(() {
                      fullCredit = value ?? true;
                    });
                  },
                ),
                if (!fullCredit) ...[
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Credit Amount',
                      border: OutlineInputBorder(),
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      creditAmount =
                          double.tryParse(value) ?? invoice.totalAmount;
                      // Estimate the tax amount proportionally
                      creditTax = (creditAmount * invoice.taxAmount) /
                          invoice.totalAmount;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Credit Note',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    reason = value;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    final invoiceRepository = InvoiceRepository();

                    // Generate a new invoice number with CRN prefix
                    final newInvoiceNumber = 'CRN-${invoice.invoiceNumber}';

                    // Create the credit note
                    final creditNote = invoice.createCreditNote(
                      newId: DateTime.now().millisecondsSinceEpoch.toString(),
                      newInvoiceNumber: newInvoiceNumber,
                      newTotalAmount: fullCredit ? null : creditAmount,
                      newTaxAmount: fullCredit ? null : creditTax,
                      newReason: reason,
                    );

                    // Save to Firestore with the correct method signature
                    final createdInvoice = await invoiceRepository.addInvoice(
                      storeId: selectedStore.id,
                      partyId: creditNote.partyId,
                      invoiceNumber: creditNote.invoiceNumber,
                      invoiceDate: creditNote.invoiceDate,
                      totalAmount: creditNote.totalAmount,
                      taxAmount: creditNote.taxAmount,
                      notes: creditNote.notes,
                      invoiceDirection: creditNote.invoiceDirection
                          .toString()
                          .split('.')
                          .last,
                      documentType:
                          creditNote.documentType.toString().split('.').last,
                      originalDocumentId: creditNote.originalDocumentId,
                      originalDocumentNumber: creditNote.originalDocumentNumber,
                      reason: creditNote.reason,
                    );

                    // Get items from original invoice
                    final originalItems = await invoiceRepository
                        .getInvoiceItems(invoice.storeId, invoice.id)
                        .first;

                    // If partial credit, adjust item amounts proportionally
                    final scaleFactor =
                        fullCredit ? 1.0 : (creditAmount / invoice.totalAmount);

                    // Convert to format accepted by addItemsToInvoice
                    final itemMaps = originalItems
                        .map((item) => {
                              'name': item.name,
                              'quantity': fullCredit
                                  ? item.quantity
                                  : item.quantity * scaleFactor,
                              'unitPrice': item.unitPrice,
                              'taxRate': item.taxRate,
                              'totalPrice': fullCredit
                                  ? -item.totalPrice
                                  : -(item.totalPrice * scaleFactor),
                              'hsn': item.hsn,
                              'invoiceId': createdInvoice.id,
                            })
                        .toList();

                    // Add items to the credit note
                    await invoiceRepository.addItemsToInvoice(
                      selectedStore.id,
                      createdInvoice.id,
                      itemMaps,
                    );

                    // Reload the invoice list
                    _loadInvoices();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Credit Note ${creditNote.invoiceNumber} created'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Error creating credit note: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Create Credit Note'),
              ),
            ],
          );
        });
      },
    );
  }

  // Creates a debit note based on the selected invoice
  void _createDebitNote(BuildContext context, Invoice invoice) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    // Show a dialog to get debit note details
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String reason = 'Additional charges';
        final reasonController = TextEditingController(text: reason);
        final amountController = TextEditingController();
        double debitAmount = 0.0;
        double debitTax = 0.0;
        final taxRate = invoice.taxAmount /
            (invoice.totalAmount - invoice.taxAmount) *
            100; // Estimate tax rate

        return StatefulBuilder(builder: (context, setState) {
          // Recalculate tax whenever amount changes
          void updateTax() {
            final baseAmount = debitAmount / (1 + (taxRate / 100));
            debitTax = debitAmount - baseAmount;
          }

          return AlertDialog(
            title: const Text('Create Debit Note'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Creating debit note for Invoice #${invoice.invoiceNumber}'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Amount',
                    border: OutlineInputBorder(),
                    prefixText: '₹',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      debitAmount = double.tryParse(value) ?? 0.0;
                      updateTax();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text('Estimated Tax: ₹${debitTax.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Debit Note',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    reason = value;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: debitAmount <= 0
                    ? null
                    : () async {
                        Navigator.of(context).pop();

                        try {
                          final invoiceRepository = InvoiceRepository();

                          // Generate a new invoice number with DBN prefix
                          final newInvoiceNumber =
                              'DBN-${invoice.invoiceNumber}';

                          // Create the debit note
                          final debitNote = invoice.createDebitNote(
                            newId: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            newInvoiceNumber: newInvoiceNumber,
                            newTotalAmount: debitAmount,
                            newTaxAmount: debitTax,
                            newReason: reason,
                          );

                          // Save to Firestore with the correct method signature
                          final createdInvoice =
                              await invoiceRepository.addInvoice(
                            storeId: selectedStore.id,
                            partyId: debitNote.partyId,
                            invoiceNumber: debitNote.invoiceNumber,
                            invoiceDate: debitNote.invoiceDate,
                            totalAmount: debitNote.totalAmount,
                            taxAmount: debitNote.taxAmount,
                            notes: debitNote.notes,
                            invoiceDirection: debitNote.invoiceDirection
                                .toString()
                                .split('.')
                                .last,
                            documentType: debitNote.documentType
                                .toString()
                                .split('.')
                                .last,
                            originalDocumentId: debitNote.originalDocumentId,
                            originalDocumentNumber:
                                debitNote.originalDocumentNumber,
                            reason: debitNote.reason,
                          );

                          // Create a new item for the debit note
                          final debitItemMap = {
                            'name': 'Additional Charges',
                            'quantity': 1.0,
                            'unitPrice': debitAmount - debitTax, // Base price
                            'taxRate': taxRate,
                            'totalPrice': debitAmount,
                            'hsn': '9997', // Service HSN code
                            'invoiceId': createdInvoice.id,
                          };

                          // Add item to the debit note
                          await invoiceRepository.addItemsToInvoice(
                            selectedStore.id,
                            createdInvoice.id,
                            [debitItemMap],
                          );

                          // Reload the invoice list
                          _loadInvoices();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Debit Note ${debitNote.invoiceNumber} created'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Error creating debit note: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('Create Debit Note'),
              ),
            ],
          );
        });
      },
    );
  }

  // Creates a quotation based on the selected invoice
  void _createQuotationFromInvoice(BuildContext context, Invoice invoice) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore == null) return;

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Quotation'),
          content: Text(
              'Create a quotation based on Invoice #${invoice.invoiceNumber}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                try {
                  final invoiceRepository = InvoiceRepository();

                  // Generate a new quotation number with QOT prefix
                  final newQuotationNumber = 'QOT-${invoice.invoiceNumber}';

                  // Create the quotation
                  final quotation = invoice.createQuotationFromInvoice(
                    newId: DateTime.now().millisecondsSinceEpoch.toString(),
                    newQuotationNumber: newQuotationNumber,
                  );

                  // Save to Firestore with the correct method signature
                  final createdInvoice = await invoiceRepository.addInvoice(
                    storeId: selectedStore.id,
                    partyId: quotation.partyId,
                    invoiceNumber: quotation.invoiceNumber,
                    invoiceDate: quotation.invoiceDate,
                    totalAmount: quotation.totalAmount,
                    taxAmount: quotation.taxAmount,
                    notes: quotation.notes,
                    invoiceDirection:
                        quotation.invoiceDirection.toString().split('.').last,
                    documentType:
                        quotation.documentType.toString().split('.').last,
                  );

                  // Get items from original invoice
                  final originalItems = await invoiceRepository
                      .getInvoiceItems(invoice.storeId, invoice.id)
                      .first;

                  // Convert to format accepted by addItemsToInvoice
                  final itemMaps = originalItems
                      .map((item) => {
                            'name': item.name,
                            'quantity': item.quantity,
                            'unitPrice': item.unitPrice,
                            'taxRate': item.taxRate,
                            'totalPrice': item.totalPrice,
                            'hsn': item.hsn,
                            'invoiceId': createdInvoice.id,
                          })
                      .toList();

                  // Add items to the quotation
                  await invoiceRepository.addItemsToInvoice(
                    selectedStore.id,
                    createdInvoice.id,
                    itemMaps,
                  );

                  // Reload the invoice list
                  _loadInvoices();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Quotation ${quotation.invoiceNumber} created'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Error creating quotation: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Create Quotation'),
            ),
          ],
        );
      },
    );
  }
}
