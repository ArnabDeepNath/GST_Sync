import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:gspappv2/features/party/presentation/bloc/party_bloc.dart';
import 'package:gspappv2/features/party/presentation/pages/add_edit_party_page.dart';
import 'package:gspappv2/features/party/presentation/pages/party_details_page.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:provider/provider.dart';
import 'package:gspappv2/features/home/presentation/pages/home_page.dart';

class PartyListPage extends StatefulWidget {
  const PartyListPage({super.key});

  @override
  State<PartyListPage> createState() => _PartyListPageState();
}

class _PartyListPageState extends State<PartyListPage> {
  PartyType? _previousPartyType;
  String? _previousStoreId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadParties();
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      _previousPartyType = storeProvider.selectedPartyType;
      _previousStoreId = storeProvider.selectedStore?.id;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeProvider = Provider.of<StoreProvider>(context);
    final currentPartyType = storeProvider.selectedPartyType;
    final currentStoreId = storeProvider.selectedStore?.id;

    // Reload if party type or store changed
    if (_previousPartyType != currentPartyType ||
        _previousStoreId != currentStoreId) {
      _loadParties();
      _previousPartyType = currentPartyType;
      _previousStoreId = currentStoreId;
    }
  }

  void _loadParties() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;

    if (selectedStore != null) {
      context.read<PartyBloc>().add(LoadParties(
            selectedStore.id,
            type: storeProvider.selectedPartyType,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;
    final isCustomerView = storeProvider.selectedPartyType == PartyType.buyer;
    final homePageState = context.findAncestorStateOfType<HomePageState>();
    final isMultiSelectMode = homePageState?.isMultiSelectMode ?? false;
    final selectedParties = homePageState?.selectedParties ?? {};

    return selectedStore == null
        ? const Center(
            child: Text('Please select a store from the menu'),
          )
        : BlocBuilder<PartyBloc, PartyState>(
            builder: (context, state) {
              if (state is PartyInitial) {
                _loadParties();
                return const Center(child: CircularProgressIndicator());
              }

              if (state is PartyLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is PartiesLoaded) {
                final parties = state.parties
                    .where((party) =>
                        party.type == storeProvider.selectedPartyType)
                    .toList();

                if (parties.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCustomerView ? Icons.people : Icons.business,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isCustomerView
                              ? 'No customers added yet'
                              : 'No suppliers added yet',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isCustomerView
                              ? 'Add your first customer to get started'
                              : 'Add your first supplier to get started',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _openAddPartyPage(context),
                          icon: const Icon(Icons.add),
                          label: Text(
                              isCustomerView ? 'Add Customer' : 'Add Supplier'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: parties.length,
                  itemBuilder: (context, index) {
                    final party = parties[index];
                    return _buildPartyCard(context, party, isMultiSelectMode,
                        selectedParties, homePageState);
                  },
                );
              }

              return const Center(child: Text('No parties found'));
            },
          );
  }

  Widget _buildPartyCard(
    BuildContext context,
    Party party,
    bool isMultiSelectMode,
    Set<String> selectedParties,
    HomePageState? homePageState,
  ) {
    final isCustomer = party.type == PartyType.buyer;
    final hasGSTIN = party.gstin != null && party.gstin!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isMultiSelectMode
            ? Checkbox(
                value: selectedParties.contains(party.id),
                onChanged: (_) {
                  homePageState?.setState(() {
                    if (selectedParties.contains(party.id)) {
                      selectedParties.remove(party.id);
                    } else {
                      selectedParties.add(party.id);
                    }
                  });
                },
              )
            : CircleAvatar(
                backgroundColor:
                    isCustomer ? Colors.blue[100] : Colors.green[100],
                child: Icon(
                  isCustomer ? Icons.person : Icons.business,
                  color: isCustomer ? Colors.blue : Colors.green,
                ),
              ),
        title: Text(
          party.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasGSTIN)
              Text('GSTIN: ${party.gstin}',
                  style: TextStyle(color: Colors.grey[600])),
            if (party.phone != null && party.phone!.isNotEmpty)
              Text('📞 ${party.phone}'),
          ],
        ),
        trailing: isMultiSelectMode ? null : const Icon(Icons.chevron_right),
        onTap: isMultiSelectMode
            ? () {
                homePageState?.setState(() {
                  if (selectedParties.contains(party.id)) {
                    selectedParties.remove(party.id);
                  } else {
                    selectedParties.add(party.id);
                  }
                });
              }
            : () => _openPartyDetailsPage(context, party),
        onLongPress: () {
          if (!isMultiSelectMode && homePageState != null) {
            homePageState.setState(() {
              homePageState.isMultiSelectMode = true;
              homePageState.selectedParties.add(party.id);
            });
          }
        },
        isThreeLine: hasGSTIN && party.phone != null && party.phone!.isNotEmpty,
      ),
    );
  }

  void _openPartyDetailsPage(BuildContext context, Party party) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyDetailsPage(party: party),
      ),
    );
  }

  void _openAddPartyPage(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final selectedStore = storeProvider.selectedStore;
    if (selectedStore == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPartyPage(
          storeId: selectedStore.id,
          partyType: storeProvider.selectedPartyType,
        ),
      ),
    ).then((_) => _loadParties());
  }
}
