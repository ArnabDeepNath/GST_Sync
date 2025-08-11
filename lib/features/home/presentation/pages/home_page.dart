import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/item/presentation/bloc/item_bloc.dart';
import 'package:gspappv2/features/item/presentation/pages/item_list_page_updated.dart';
import 'package:gspappv2/features/party/presentation/bloc/party_bloc.dart';
import 'package:gspappv2/features/party/presentation/pages/party_list_page.dart';
import 'package:gspappv2/features/invoice/presentation/pages/invoice_list_page.dart';
import 'package:gspappv2/features/party/presentation/pages/add_edit_party_page.dart';
import 'package:gspappv2/features/invoice/presentation/pages/add_edit_invoice_page.dart';
import 'package:gspappv2/features/invoice/presentation/pages/create_invoice_page.dart';
import 'package:gspappv2/features/profile/presentation/pages/profile_page.dart';
import 'package:gspappv2/features/reports/presentation/pages/reports_page.dart';
import 'package:gspappv2/features/item/presentation/pages/add_edit_item_page.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:gspappv2/features/store/presentation/widgets/drawer_store_selector.dart';
import 'package:gspappv2/features/business_tools/presentation/widgets/business_tools_widget.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:gspappv2/features/invoice/presentation/bloc/invoice_bloc.dart';
import 'package:intl/intl.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../party/domain/models/party.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool isMultiSelectMode = false; // Made public
  final Set<String> selectedParties = {}; // Made public
  final Set<String> selectedItems = {}; // For multi-selecting items
  String? _previousStoreId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      _previousStoreId = storeProvider.selectedStore?.id;

      // Initialize store provider if no stores are loaded and no error
      if (storeProvider.stores.isEmpty &&
          storeProvider.error == null &&
          !storeProvider.isLoading) {
        print('HomePage: Initializing StoreProvider as backup');
        storeProvider.initialize();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeProvider = Provider.of<StoreProvider>(context);
    final currentStoreId = storeProvider.selectedStore?.id;

    // Clear multi-select state when store changes
    if (_previousStoreId != currentStoreId) {
      setState(() {
        isMultiSelectMode = false;
        selectedParties.clear();
        selectedItems.clear();
      });
      _previousStoreId = currentStoreId;
    }
  }

  void deleteSelectedParties(BuildContext context, String storeId) async {
    // Made public
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Parties'),
        content: Text(
            'Are you sure you want to delete ${selectedParties.length} parties?'),
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
      ),
    );

    if (confirmed == true) {
      // Get the PartyBloc
      final partyBloc = BlocProvider.of<PartyBloc>(context);

      // Delete the selected parties one by one
      for (final partyId in selectedParties) {
        partyBloc.add(DeleteParty(storeId, partyId));
      }

      // Wait a bit to allow the bloc to process the deletions
      await Future.delayed(const Duration(milliseconds: 300));

      // Clear selection and exit multi-select mode
      setState(() {
        selectedParties.clear();
        isMultiSelectMode = false;
      });

      // Reload the parties list to reflect the changes
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      partyBloc.add(LoadParties(
        storeId,
        type: storeProvider.selectedPartyType,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected parties deleted')),
        );
      }
    }
  }

  // Add method for deleting selected items
  void deleteSelectedItems(BuildContext context, String storeId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text(
            'Are you sure you want to delete ${selectedItems.length} items?'),
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
      ),
    );

    if (confirmed == true) {
      // Delete the selected items
      for (final itemId in selectedItems) {
        context.read<ItemBloc>().add(DeleteItemEvent(storeId, itemId));
      }

      setState(() {
        selectedItems.clear();
        isMultiSelectMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected items deleted')),
        );
      }
    }
  }

  // Add CSV import/export functionality
  Future<void> importCsv() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;
    if (selectedStore == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final input = await file.readAsString();
        final rows = const CsvToListConverter().convert(input);

        // Skip header row
        for (var row in rows.skip(1)) {
          if (row.length >= 4) {
            // Ensure row has minimum required fields
            context.read<PartyBloc>().add(AddParty(
                  storeId: selectedStore.id,
                  name: row[0].toString(),
                  type: storeProvider.selectedPartyType,
                  gstin:
                      row[1].toString().isNotEmpty ? row[1].toString() : null,
                  address: row[2].toString(),
                  phone: row[3].toString(),
                  email: row.length > 4 ? row[4].toString() : null,
                ));
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parties imported successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing CSV: ${e.toString()}')),
      );
    }
  } // Add method for requesting storage permission

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Check Android version
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ uses scoped storage, no permission needed for app-specific directories
        // But we still need permission for accessing external storage
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        // Android 10 and below
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    // For iOS and other platforms, return true as they handle permissions differently
    return true;
  }

  Future<void> downloadSampleCsv() async {
    try {
      // Request storage permission
      final permissionStatus = await _requestStoragePermission();
      if (!permissionStatus) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to save files'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final header = ['Name', 'GSTIN', 'Address', 'Phone', 'Email'];
      final sampleData = [
        [
          'ABC Company',
          '27AABCU9603R1ZN',
          '123 Street, City',
          '9876543210',
          'abc@example.com'
        ],
        [
          'XYZ Corp',
          '29AABCU9603R1ZN',
          '456 Avenue, Town',
          '8765432109',
          'xyz@example.com'
        ],
      ];

      final csvData =
          const ListToCsvConverter().convert([header, ...sampleData]);

      // Always use file picker for better permission handling
      final directory = await FilePicker.platform.getDirectoryPath();
      if (directory != null) {
        final file =
            File('$directory${Platform.pathSeparator}sample_parties.csv');
        await file.writeAsString(csvData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample CSV saved to: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () async {
                // Open the folder containing the file
                if (Platform.isWindows) {
                  try {
                    await Process.run('explorer', ['/select,', file.path]);
                  } catch (e) {
                    print('Error opening folder: $e');
                    // Fallback: just open the directory
                    try {
                      await Process.run('explorer', [directory]);
                    } catch (e2) {
                      print('Error opening directory: $e2');
                    }
                  }
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File save cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating sample CSV: ${e.toString()}')),
      );
    }
  }

  // Add CSV import/export functionality for invoices
  Future<void> importInvoiceCsv() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;
    if (selectedStore == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final input = await file.readAsString();

        context.read<InvoiceBloc>().add(ImportInvoices(
              storeId: selectedStore.id,
              csvContent: input,
            ));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoices imported successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing CSV: ${e.toString()}')),
      );
    }
  }

  Future<void> downloadInvoiceSampleCsv() async {
    try {
      // Request storage permission
      final permissionStatus = await _requestStoragePermission();
      if (!permissionStatus) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to save files'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final header = [
        'Invoice Number',
        'Invoice Date (DD/MM/YYYY)',
        'Party ID',
        'Total Amount',
        'Tax Amount',
        'Notes',
        'Invoice Direction (sales/purchase)'
      ];
      final sampleData = [
        [
          'INV001',
          '15/06/2025',
          'PARTY001',
          '1000.00',
          '180.00',
          'Sample invoice 1',
          'sales'
        ],
        [
          'INV002',
          '16/06/2025',
          'PARTY002',
          '2000.00',
          '360.00',
          'Sample invoice 2',
          'purchase'
        ],
      ];

      final csvData =
          const ListToCsvConverter().convert([header, ...sampleData]);

      // Always use file picker for better permission handling
      final directory = await FilePicker.platform.getDirectoryPath();
      if (directory != null) {
        final file =
            File('$directory${Platform.pathSeparator}sample_invoices.csv');
        await file.writeAsString(csvData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample CSV saved to: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () async {
                // Open the folder containing the file
                if (Platform.isWindows) {
                  try {
                    await Process.run('explorer', ['/select,', file.path]);
                  } catch (e) {
                    print('Error opening folder: $e');
                    // Fallback: just open the directory
                    try {
                      await Process.run('explorer', [directory]);
                    } catch (e2) {
                      print('Error opening directory: $e2');
                    }
                  }
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File save cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating sample CSV: ${e.toString()}')),
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Load items when navigating to Items tab (index 3)
    if (index == 3) {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;
      if (selectedStore != null) {
        print(
            'Loading items from _onPageChanged for store: ${selectedStore.id}');

        try {
          // Force load items when navigating to the Items tab
          final itemBloc = BlocProvider.of<ItemBloc>(context);
          itemBloc.add(LoadItems(selectedStore.id));

          // Debug the current state of the ItemBloc
          print('Current ItemBloc state: ${itemBloc.state}');
        } catch (e) {
          print('Error loading items in HomePage: $e');
        }
      } else {
        print('No store selected, cannot load items');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;
    final isCustomerView = storeProvider.selectedPartyType == PartyType.buyer;

    return Scaffold(
      appBar: _currentIndex == 1
          ? // Party List Page App Bar
          AppBar(
              title: Text(
                isCustomerView ? 'My Customers' : 'My Suppliers',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                if (isMultiSelectMode && selectedStore != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedParties.clear();
                        isMultiSelectMode = false;
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  TextButton.icon(
                    onPressed: selectedParties.isNotEmpty
                        ? () => deleteSelectedParties(context, selectedStore.id)
                        : null,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: Text(
                      '${selectedParties.length}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ] else ...[
                  IconButton(
                    onPressed: () {
                      setState(() {
                        isMultiSelectMode = true;
                      });
                    },
                    icon: const Icon(Icons.select_all),
                    tooltip: 'Select Multiple',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'import':
                          await importCsv();
                          break;
                        case 'sample':
                          await downloadSampleCsv();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'import',
                        child: ListTile(
                          leading: Icon(Icons.upload_file),
                          title: Text('Import from CSV'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sample',
                        child: ListTile(
                          leading: Icon(Icons.download),
                          title: Text('Download Sample CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          : _currentIndex == 2
              ? // Invoice List Page App Bar
              AppBar(
                  title: Text(
                    isCustomerView ? 'Sales Invoices' : 'Purchase Invoices',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'import':
                            await importInvoiceCsv();
                            break;
                          case 'sample':
                            await downloadInvoiceSampleCsv();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'import',
                          child: ListTile(
                            leading: Icon(Icons.upload_file),
                            title: Text('Import from CSV'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'sample',
                          child: ListTile(
                            leading: Icon(Icons.download),
                            title: Text('Download Sample CSV'),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : _currentIndex == 3
                  ? // Item List Page App Bar
                  AppBar(
                      title: const Text(
                        'My Items',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      actions: [
                        if (isMultiSelectMode && selectedStore != null) ...[
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                selectedItems.clear();
                                isMultiSelectMode = false;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                          ),
                          TextButton.icon(
                            onPressed: selectedItems.isNotEmpty
                                ? () => deleteSelectedItems(
                                    context, selectedStore.id)
                                : null,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: Text(
                              '${selectedItems.length}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ] else ...[
                          IconButton(
                            onPressed: () {
                              setState(() {
                                isMultiSelectMode = true;
                              });
                            },
                            icon: const Icon(Icons.select_all),
                            tooltip: 'Select Multiple',
                          ),
                        ],
                      ],
                    )
                  : // Default App Bar for other pages
                  AppBar(
                      title: Text(selectedStore != null
                          ? 'GST App - ${selectedStore.name}'
                          : 'GST App'),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () => _showSignOutDialog(context),
                        ),
                      ],
                    ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? 'User'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user?.displayName?.isNotEmpty == true
                      ? user!.displayName![0].toUpperCase()
                      : 'U',
                  style: const TextStyle(fontSize: 24.0),
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),

            // Add the DrawerStoreSelector
            const DrawerStoreSelector(),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Parties'),
              onTap: () {
                Navigator.pop(context);
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Invoices'),
              onTap: () {
                Navigator.pop(context);
                _pageController.animateToPage(
                  2,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                _pageController.animateToPage(
                  3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings page
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to help page
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // _buildHeader(context),
            // const SizedBox(height: 16),
            if (_currentIndex == 0) _buildSearchBar(),
            const SizedBox(height: 16),
            // _buildTabBar(context),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildHomeContent(),
                  const PartyListPage(),
                  const InvoiceListPage(),
                  const ItemListPage(), // This uses the ItemListPage class that handles its own multi-select
                  const ReportsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceSection(),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildTransactionSection(context),
            const SizedBox(height: 24),
            _buildAnalyticsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => ProfilePage()));
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage('assets/images/profile.jpg'),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Home',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // Row(
        //   children: [
        //     IconButton(
        //       icon: const Icon(Icons.analytics_outlined),
        //       onPressed: () {},
        //     ),
        //     IconButton(
        //       icon: const Icon(Icons.notifications_outlined),
        //       onPressed: () {},
        //     ),
        //   ],
        // ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 4,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const TextField(
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: Icon(Icons.search),
            hintText: 'Search',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTab('Home', _currentIndex == 0, () {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }),
          _buildTab('Parties', _currentIndex == 1, () {
            _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }),
          _buildTab('Invoices', _currentIndex == 2, () {
            _pageController.animateToPage(
              2,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }),
          _buildTab('Filing', _currentIndex == 3, () {
            _pageController.animateToPage(
              3,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSection() {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    // Load invoices for the selected store if not already loaded
    if (selectedStore == null) {
      return const Center(
        child: Text('Please select a store to view balance'),
      );
    }

    // Load invoices directly since we know selectedStore is not null
    final invoiceState = context.read<InvoiceBloc>().state;
    if (invoiceState is! InvoicesLoaded) {
      context.read<InvoiceBloc>().add(LoadInvoices(selectedStore.id));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<InvoiceBloc, InvoiceState>(
            builder: (context, state) {
              if (state is InvoiceLoading || state is InvoiceInitial) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading invoice data...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                );
              }

              if (state is InvoiceError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹0.00',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Error loading invoices',
                      style: TextStyle(
                        color: Colors.red[400],
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        context
                            .read<InvoiceBloc>()
                            .add(LoadInvoices(selectedStore.id));
                      },
                    ),
                  ],
                );
              }

              double totalAmount = 0.0;
              int invoiceCount = 0;

              if (state is InvoicesLoaded) {
                invoiceCount = state.invoices.length;
                totalAmount = state.invoices
                    .fold(0.0, (sum, invoice) => sum + invoice.financialImpact);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  Text(
                    'Total from $invoiceCount invoices',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (selectedStore == null)
          const Center(
            child: Text('Please select a store to access quick actions'),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(context, 'Add Party', Icons.person_add, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditPartyPage(
                      storeId: selectedStore.id,
                      partyType: PartyType.buyer,
                    ),
                  ),
                );
              }),
              _buildActionButton(context, 'Add Invoice', Icons.receipt_long,
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditInvoicePage(
                      storeId: selectedStore.id,
                      invoiceDirection:
                          storeProvider.selectedPartyType == PartyType.buyer
                              ? InvoiceDirection.sales
                              : InvoiceDirection.purchase,
                    ),
                  ),
                );
              }),
              _buildActionButton(context, 'Reports', Icons.assessment, () {
                _pageController.animateToPage(
                  3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }),
              _buildActionButton(context, 'More', Icons.more_horiz, () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => _buildMoreOptions(context),
                );
              }),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 80,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSection(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Invoices',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (selectedStore == null)
          const Center(
            child: Text('Please select a store to view invoices'),
          )
        else
          BlocBuilder<InvoiceBloc, InvoiceState>(
            builder: (context, state) {
              if (state is InvoiceLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is InvoicesLoaded) {
                if (state.invoices.isEmpty) {
                  return const Center(
                    child:
                        Text('No invoices found. Create your first invoice!'),
                  );
                }

                // Sort invoices by date, newest first
                final sortedInvoices = List<Invoice>.from(state.invoices)
                  ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

                // Take only the 5 most recent invoices
                final recentInvoices = sortedInvoices.take(5).toList();

                return Column(
                  children: recentInvoices.map((invoice) {
                    return _buildInvoiceItem(
                      invoice.invoiceNumber,
                      invoice.financialImpact.toStringAsFixed(2),
                      invoice.invoiceDate,
                    );
                  }).toList(),
                );
              } else if (state is InvoiceError) {
                return Center(
                  child: Text(
                    'Error loading invoices: ${state.message}',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
      ],
    );
  }

  Widget _buildInvoiceItem(String number, String amount, DateTime date) {
    // Parse amount to determine if it's positive or negative
    double amountValue = double.tryParse(amount) ?? 0.0;
    bool isPositive = amountValue >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice #$number',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}₹${amountValue.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isPositive ? Colors.green[700] : Colors.red[700],
                ),
              ),
              Text(
                isPositive ? 'Income' : 'Expense',
                style: TextStyle(
                  fontSize: 12,
                  color: isPositive ? Colors.green[600] : Colors.red[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invoice Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (selectedStore == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('Please select a store to view analytics'),
            ),
          )
        else
          BlocBuilder<InvoiceBloc, InvoiceState>(
            builder: (context, state) {
              if (state is InvoiceLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is InvoicesLoaded) {
                // Get invoices from last 30 days
                final now = DateTime.now();
                final thirtyDaysAgo = now.subtract(const Duration(days: 30));

                final recentInvoices = state.invoices
                    .where(
                        (invoice) => invoice.invoiceDate.isAfter(thirtyDaysAgo))
                    .toList();

                // Calculate total amount for last 30 days
                final totalAmount = recentInvoices.fold(
                    0.0, (sum, invoice) => sum + invoice.financialImpact);

                // Calculate average invoice value
                final avgInvoiceValue = recentInvoices.isNotEmpty
                    ? totalAmount / recentInvoices.length
                    : 0.0;

                return Column(
                  children: [
                    // Basic Analytics
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last 30 Days',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAnalyticsTile(
                            'Invoices',
                            recentInvoices.length.toString(),
                            Icons.receipt,
                            Colors.blue,
                          ),
                          const Divider(),
                          _buildAnalyticsTile(
                            'Total Value',
                            '₹${totalAmount.toStringAsFixed(2)}',
                            Icons.payments,
                            Colors.green,
                          ),
                          const Divider(),
                          _buildAnalyticsTile(
                            'Avg Invoice Value',
                            '₹${avgInvoiceValue.toStringAsFixed(2)}',
                            Icons.trending_up,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Business Tools Section
                    BlocBuilder<InvoiceBloc, InvoiceState>(
                      builder: (context, invoiceState) {
                        return FutureBuilder<List<InvoiceItem>>(
                          future: _loadAllInvoiceItems(
                              state.invoices, selectedStore.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final invoiceItems = snapshot.data ?? [];
                            return BusinessToolsWidget(
                              invoices: state.invoices,
                              invoiceItems: invoiceItems,
                            );
                          },
                        );
                      },
                    ),
                  ],
                );
              }
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Text('No data available'),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAnalyticsTile(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Parties'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Invoices'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Items'),
        BottomNavigationBarItem(icon: Icon(Icons.file_copy), label: 'Filing'),
      ],
      currentIndex: _currentIndex,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Widget _buildMoreOptions(BuildContext context) {
    // Implementation of _buildMoreOptions method
    return Container(); // Placeholder return, actual implementation needed
  }

  Future<List<InvoiceItem>> _loadAllInvoiceItems(
      List<Invoice> invoices, String storeId) async {
    final List<InvoiceItem> allItems = [];
    final InvoiceRepository repository = InvoiceRepository();

    for (var invoice in invoices) {
      final items = await repository.getInvoiceItems(storeId, invoice.id).first;
      allItems.addAll(items);
    }

    return allItems;
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    if (_currentIndex != 1 && _currentIndex != 2 && _currentIndex != 3)
      return null;

    return FloatingActionButton(
      onPressed: () {
        if (selectedStore == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a store first')),
          );
          return;
        }

        if (_currentIndex == 1) {
          // Add Party
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditPartyPage(
                storeId: selectedStore.id,
                partyType: storeProvider.selectedPartyType,
              ),
            ),
          );
        } else if (_currentIndex == 2) {
          // Add Invoice based on party type
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateInvoicePage(
                initialDirection:
                    storeProvider.selectedPartyType == PartyType.buyer
                        ? InvoiceDirection.sales
                        : InvoiceDirection.purchase,
              ),
            ),
          );
        } else if (_currentIndex == 3) {
          // Add Item
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditItemPage(
                storeId: selectedStore.id,
              ),
            ),
          );
        }
      },
      child: const Icon(Icons.add),
    );
  }
}
