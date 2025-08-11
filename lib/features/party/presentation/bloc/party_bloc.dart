import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gspappv2/features/party/data/repositories/party_repository.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';

// Events
abstract class PartyEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadParties extends PartyEvent {
  final String storeId;
  final PartyType? type;

  LoadParties(this.storeId, {this.type});

  @override
  List<Object?> get props => [storeId, type];
}

class AddParty extends PartyEvent {
  final String storeId;
  final String name;
  final PartyType type;
  final String? gstin;
  final String? address;
  final String? phone;
  final String? email;

  AddParty({
    required this.storeId,
    required this.name,
    required this.type,
    this.gstin,
    this.address,
    this.phone,
    this.email,
  });

  @override
  List<Object?> get props =>
      [storeId, name, type, gstin, address, phone, email];
}

class UpdateParty extends PartyEvent {
  final Party party;

  UpdateParty(this.party);

  @override
  List<Object?> get props => [party];
}

class DeleteParty extends PartyEvent {
  final String storeId;
  final String partyId;

  DeleteParty(this.storeId, this.partyId);

  @override
  List<Object?> get props => [storeId, partyId];
}

// States
abstract class PartyState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PartyInitial extends PartyState {}

class PartyLoading extends PartyState {}

class PartiesLoaded extends PartyState {
  final List<Party> parties;

  // Add computed properties with safe calculations
  int get totalSuppliers =>
      parties.where((p) => p.type == PartyType.seller).length;

  double get totalTaxableValue =>
      0.0; // This would need to be calculated differently with the new model

  int get totalInvoices =>
      0; // This would need to be calculated differently with the new model

  int get totalCDNs =>
      0; // This would need to be calculated differently with the new model

  // Calculate monthly averages safely
  double get avgSuppliers => _calculateMonthlyAverage(totalSuppliers);
  double get avgTaxableValue => _calculateMonthlyAverage(totalTaxableValue);
  double get avgInvoices => _calculateMonthlyAverage(totalInvoices);
  double get avgCDNs => _calculateMonthlyAverage(totalCDNs);

  // Calculate changes safely
  String get suppliersChange =>
      _calculateChange(totalSuppliers, totalSuppliers - 3);
  String get taxableValueChange =>
      _calculateChange(totalTaxableValue, totalTaxableValue * 0.9);
  String get invoicesChange =>
      _calculateChange(totalInvoices, totalInvoices - 3);
  String get cdnsChange =>
      _calculatePercentageChange(totalCDNs, totalCDNs * 0.7);

  PartiesLoaded(this.parties);

  double _calculateMonthlyAverage(num total) {
    try {
      return (total / 12).isFinite ? total / 12 : 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  String _calculateChange(num current, num previous) {
    try {
      if (!current.isFinite || !previous.isFinite) return '+0';
      final diff = current - previous;
      return diff >= 0
          ? '+${diff.toStringAsFixed(0)}'
          : diff.toStringAsFixed(0);
    } catch (_) {
      return '+0';
    }
  }

  String _calculatePercentageChange(num current, num previous) {
    try {
      if (previous == 0 || !current.isFinite || !previous.isFinite)
        return '+0%';
      final percentChange = ((current - previous) / previous * 100).round();
      return '${percentChange >= 0 ? '+' : ''}$percentChange%';
    } catch (_) {
      return '+0%';
    }
  }

  @override
  List<Object?> get props => [parties];
}

class PartyError extends PartyState {
  final String message;
  PartyError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class PartyBloc extends Bloc<PartyEvent, PartyState> {
  final PartyRepository _repository;
  PartyType? _currentType;

  PartyBloc(this._repository) : super(PartyInitial()) {
    on<LoadParties>(_onLoadParties);
    on<AddParty>(_onAddParty);
    on<UpdateParty>(_onUpdateParty);
    on<DeleteParty>(_onDeleteParty);
  }

  Future<void> _onLoadParties(
      LoadParties event, Emitter<PartyState> emit) async {
    emit(PartyLoading());
    try {
      _currentType = event.type;
      final partiesStream =
          _repository.getParties(event.storeId, type: event.type);
      await emit.forEach(
        partiesStream,
        onData: (List<Party> parties) => PartiesLoaded(parties),
        onError: (error, _) => PartyError(error.toString()),
      );
    } catch (e) {
      emit(PartyError(e.toString()));
    }
  }

  Future<void> _onAddParty(AddParty event, Emitter<PartyState> emit) async {
    emit(PartyLoading());
    try {
      await _repository.addParty(
        storeId: event.storeId,
        name: event.name,
        type: event.type,
        gstin: event.gstin,
        address: event.address,
        phone: event.phone,
        email: event.email,
      );
      add(LoadParties(event.storeId, type: event.type));
    } catch (e) {
      emit(PartyError(e.toString()));
    }
  }

  Future<void> _onUpdateParty(
      UpdateParty event, Emitter<PartyState> emit) async {
    emit(PartyLoading());
    try {
      await _repository.updateParty(event.party);
      add(LoadParties(event.party.storeId, type: _currentType));
    } catch (e) {
      emit(PartyError(e.toString()));
    }
  }

  Future<void> _onDeleteParty(
      DeleteParty event, Emitter<PartyState> emit) async {
    emit(PartyLoading());
    try {
      await _repository.deleteParty(event.storeId, event.partyId);
      add(LoadParties(event.storeId, type: _currentType));
    } catch (e) {
      emit(PartyError(e.toString()));
    }
  }

  @override
  void onTransition(Transition<PartyEvent, PartyState> transition) {
    super.onTransition(transition);
    print(transition); // For debugging purposes
  }
}
