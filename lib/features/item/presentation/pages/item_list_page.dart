import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/item/domain/models/item.dart';
import 'package:gspappv2/features/item/presentation/bloc/item_bloc.dart';
import 'package:gspappv2/features/item/presentation/pages/add_edit_item_page.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:provider/provider.dart';

class ItemListPage extends StatefulWidget {
  const ItemListPage({super.key});

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  bool isMultiSelectMode = false;
  final Set<String> selectedItems = {};
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  String? _previousStoreId;

  @override
  void initState() {
    super.initState();

    // Add post-frame callback to ensure the widget tree is built before accessing context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItems();
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      _previousStoreId = storeProvider.selectedStore?.id;

      // Listen to state changes for debugging
      final itemBloc = BlocProvider.of<ItemBloc>(context);
      itemBloc.stream.listen((state) {
        print('ItemBloc state: $state');
        if (state is ItemsLoaded) {
          print('Items count: ${state.items.length}');
        } else if (state is ItemError) {
          print('Item error: ${state.message}');
        } else if (state is ItemLoading) {
          print('Items are currently loading...');
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeProvider = Provider.of<StoreProvider>(context);
    final currentStoreId = storeProvider.selectedStore?.id;

    // Reload if store changed
    if (_previousStoreId != currentStoreId) {
      _loadItems();
      _previousStoreId = currentStoreId;
      // Clear selections when store changes
      setState(() {
        selectedItems.clear();
        isMultiSelectMode = false;
      });
    }
  }

  void _loadItems() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;
    if (selectedStore != null) {
      print('Requesting to load items for store: ${selectedStore.id}');
      final itemBloc = context.read<ItemBloc>();
      print('Current state before loading: ${itemBloc.state}');
      itemBloc.add(LoadItems(selectedStore.id));
    } else {
      print('No store selected, cannot load items');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _deleteSelectedItems(BuildContext context, String storeId) async {
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

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;

    return Scaffold(
      // appBar: isMultiSelectMode
      //     ? AppBar(
      //         backgroundColor: Colors.blue,
      //         title: Text('${selectedItems.length} Selected'),
      //         leading: IconButton(
      //           icon: const Icon(Icons.close),
      //           onPressed: () {
      //             setState(() {
      //               isMultiSelectMode = false;
      //               selectedItems.clear();
      //             });
      //           },
      //         ),
      //         actions: [
      //           TextButton.icon(
      //             onPressed: selectedItems.isEmpty
      //                 ? null
      //                 : () => _deleteSelectedItems(
      //                     context, selectedStore?.id ?? ''),
      //             icon: const Icon(Icons.delete, color: Colors.white),
      //             label: Text(
      //               '${selectedItems.length}',
      //               style: const TextStyle(color: Colors.white),
      //             ),
      //           ),
      //           PopupMenuButton<String>(
      //             onSelected: (value) {
      //               if (value == 'selectAll' && selectedStore != null) {
      //                 if (context.read<ItemBloc>().state is ItemsLoaded) {
      //                   final items =
      //                       (context.read<ItemBloc>().state as ItemsLoaded)
      //                           .items;
      //                   setState(() {
      //                     selectedItems.addAll(items.map((item) => item.id));
      //                   });
      //                 }
      //               } else if (value == 'deselectAll') {
      //                 setState(() {
      //                   selectedItems.clear();
      //                 });
      //               }
      //             },
      //             itemBuilder: (context) => [
      //               const PopupMenuItem(
      //                 value: 'selectAll',
      //                 child: Text('Select All'),
      //               ),
      //               const PopupMenuItem(
      //                 value: 'deselectAll',
      //                 child: Text('Deselect All'),
      //               ),
      //             ],
      //           ),
      //         ],
      //       )
      //     : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<ItemBloc, ItemState>(
              builder: (context, state) {
                if (state is ItemLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ItemError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${state.message}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Force reload items when retry is pressed
                            final storeProvider = Provider.of<StoreProvider>(
                                context,
                                listen: false);
                            final selectedStore = storeProvider.selectedStore;
                            if (selectedStore != null) {
                              print(
                                  'Manually reloading items for store: ${selectedStore.id}');
                              context
                                  .read<ItemBloc>()
                                  .add(LoadItems(selectedStore.id));
                            }
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is ItemsLoaded) {
                  final items = state.items;
                  final filteredItems = items
                      .where((item) =>
                          item.name.toLowerCase().contains(searchQuery) ||
                          (item.hsn?.toLowerCase() ?? '').contains(searchQuery))
                      .toList();

                  if (filteredItems.isEmpty) {
                    return const Center(
                      child: Text('No items found'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      // Pull to refresh functionality
                      final storeProvider =
                          Provider.of<StoreProvider>(context, listen: false);
                      final selectedStore = storeProvider.selectedStore;
                      if (selectedStore != null) {
                        print(
                            'Refreshing items for store: ${selectedStore.id}');
                        context
                            .read<ItemBloc>()
                            .add(LoadItems(selectedStore.id));
                      }
                    },
                    child: ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = selectedItems.contains(item.id);
                        return Dismissible(
                            key: Key(item.id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Item'),
                                      content: Text(
                                          'Are you sure you want to delete "${item.name}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (direction) {
                              if (selectedStore != null) {
                                context.read<ItemBloc>().add(
                                    DeleteItemEvent(selectedStore.id, item.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${item.name} deleted'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () {
                                        // Cannot actually undo as we'd need to store the full item
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Undo not available')),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              elevation: 2,
                              child: ListTile(
                                onTap: () {
                                  if (isMultiSelectMode) {
                                    setState(() {
                                      if (isSelected) {
                                        selectedItems.remove(item.id);
                                      } else {
                                        selectedItems.add(item.id);
                                      }
                                    });
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddEditItemPage(
                                          item: item,
                                          storeId: selectedStore?.id ?? '',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                onLongPress: () {
                                  if (!isMultiSelectMode) {
                                    setState(() {
                                      isMultiSelectMode = true;
                                      selectedItems.add(item.id);
                                    });
                                  }
                                },
                                leading: isMultiSelectMode
                                    ? Checkbox(
                                        value: isSelected,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              selectedItems.add(item.id);
                                            } else {
                                              selectedItems.remove(item.id);
                                            }
                                          });
                                        },
                                      )
                                    : const CircleAvatar(
                                        child: Icon(Icons.inventory_2),
                                      ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.hsn != null &&
                                        item.hsn!.isNotEmpty)
                                      Text('HSN: ${item.hsn}'),
                                    Text(
                                      'Price: ₹${item.unitPrice.toStringAsFixed(2)} | Tax: ${item.taxRate}%',
                                    ),
                                    Text(
                                        'UQC: ${UQCCodes.getUQCName(item.uqc)}'),
                                  ],
                                ),
                                trailing: isMultiSelectMode
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AddEditItemPage(
                                                    item: item,
                                                    storeId:
                                                        selectedStore?.id ?? '',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () async {
                                              final confirmed =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title:
                                                      const Text('Delete Item'),
                                                  content: Text(
                                                      'Are you sure you want to delete "${item.name}"?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(false),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(true),
                                                      child: const Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                            color: Colors.red),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirmed == true &&
                                                  selectedStore != null) {
                                                context.read<ItemBloc>().add(
                                                    DeleteItemEvent(
                                                        selectedStore.id,
                                                        item.id));
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          '${item.name} deleted')),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                              ),
                            ));
                      },
                    ),
                  );
                }

                return const Center(
                  child: Text('No items found'),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedStore != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditItemPage(
                  storeId: selectedStore.id,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a store first')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
