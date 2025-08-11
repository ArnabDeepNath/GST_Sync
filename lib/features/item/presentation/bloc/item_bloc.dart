import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gspappv2/features/item/data/repositories/item_repository.dart';
import 'package:gspappv2/features/item/domain/models/item.dart';

// Events
abstract class ItemEvent extends Equatable {
  const ItemEvent();

  @override
  List<Object?> get props => [];
}

class LoadItems extends ItemEvent {
  final String storeId;

  const LoadItems(this.storeId);

  @override
  List<Object?> get props => [storeId];
}

class AddItemEvent extends ItemEvent {
  final String storeId;
  final String name;
  final double unitPrice;
  final String? hsn;
  final double taxRate;
  final String uqc;

  const AddItemEvent({
    required this.storeId,
    required this.name,
    required this.unitPrice,
    this.hsn,
    required this.taxRate,
    required this.uqc,
  });

  @override
  List<Object?> get props => [storeId, name, unitPrice, hsn, taxRate, uqc];
}

class UpdateItemEvent extends ItemEvent {
  final Item item;

  const UpdateItemEvent(this.item);

  @override
  List<Object?> get props => [item];
}

class DeleteItemEvent extends ItemEvent {
  final String storeId;
  final String itemId;

  const DeleteItemEvent(this.storeId, this.itemId);

  @override
  List<Object?> get props => [storeId, itemId];
}

// States
abstract class ItemState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ItemInitial extends ItemState {}

class ItemLoading extends ItemState {}

class ItemsLoaded extends ItemState {
  final List<Item> items;

  ItemsLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class ItemError extends ItemState {
  final String message;

  ItemError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class ItemBloc extends Bloc<ItemEvent, ItemState> {
  final ItemRepository _itemRepository;
  ItemBloc({required ItemRepository itemRepository})
      : _itemRepository = itemRepository,
        super(ItemInitial()) {
    on<LoadItems>(_onLoadItems);
    on<AddItemEvent>(_onAddItem);
    on<UpdateItemEvent>(_onUpdateItem);
    on<DeleteItemEvent>(_onDeleteItem);
    on<_LoadedItems>(_onItemsLoaded);
    on<_ErrorItems>(_onItemsError);
  }
  void _onLoadItems(LoadItems event, Emitter<ItemState> emit) async {
    emit(ItemLoading());
    try {
      print('Loading items for store: ${event.storeId}');

      if (event.storeId.isEmpty) {
        print('Store ID is empty, cannot load items');
        emit(ItemError('Store ID is empty'));
        return;
      }

      final stream = _itemRepository.getItems(event.storeId);

      // Ensure we're emitting updates even if the initial state was already loading
      stream.listen(
        (items) {
          print('Items loaded: ${items.length}');
          add(_LoadedItems(items));
        },
        onError: (error) {
          print('Error loading items: ${error.toString()}');
          add(_ErrorItems(error.toString()));
        },
        onDone: () {
          print('Items stream completed');
        },
      );
    } catch (e) {
      print('Exception in _onLoadItems: ${e.toString()}');
      emit(ItemError(e.toString()));
    }
  }

  void _onAddItem(AddItemEvent event, Emitter<ItemState> emit) async {
    emit(ItemLoading());
    try {
      await _itemRepository.addItem(
        storeId: event.storeId,
        name: event.name,
        unitPrice: event.unitPrice,
        hsn: event.hsn,
        taxRate: event.taxRate,
        uqc: event.uqc,
      );
      add(LoadItems(event.storeId));
    } catch (e) {
      emit(ItemError(e.toString()));
    }
  }

  void _onUpdateItem(UpdateItemEvent event, Emitter<ItemState> emit) async {
    emit(ItemLoading());
    try {
      await _itemRepository.updateItem(event.item);
      add(LoadItems(event.item.storeId));
    } catch (e) {
      emit(ItemError(e.toString()));
    }
  }

  void _onDeleteItem(DeleteItemEvent event, Emitter<ItemState> emit) async {
    emit(ItemLoading());
    try {
      await _itemRepository.deleteItem(event.storeId, event.itemId);
      add(LoadItems(event.storeId));
    } catch (e) {
      emit(ItemError(e.toString()));
    }
  }

  void _onItemsLoaded(_LoadedItems event, Emitter<ItemState> emit) {
    print('_onItemsLoaded called with ${event.items.length} items');
    emit(ItemsLoaded(event.items));
  }

  void _onItemsError(_ErrorItems event, Emitter<ItemState> emit) {
    print('_onItemsError called with message: ${event.message}');
    emit(ItemError(event.message));
  }
}

// Private events for internal bloc usage
class _LoadedItems extends ItemEvent {
  final List<Item> items;

  const _LoadedItems(this.items);

  @override
  List<Object?> get props => [items];
}

class _ErrorItems extends ItemEvent {
  final String message;

  const _ErrorItems(this.message);

  @override
  List<Object?> get props => [message];
}
