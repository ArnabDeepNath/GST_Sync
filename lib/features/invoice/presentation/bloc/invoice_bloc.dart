import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';

// Events
abstract class InvoiceEvent extends Equatable {
  const InvoiceEvent();

  @override
  List<Object?> get props => [];
}

class LoadInvoices extends InvoiceEvent {
  final String storeId;
  final InvoiceDirection? invoiceDirection;
  final String? partyId;

  const LoadInvoices(this.storeId, {this.invoiceDirection, this.partyId});

  @override
  List<Object?> get props => [storeId, invoiceDirection, partyId];
}

class AddInvoice extends InvoiceEvent {
  final String storeId;
  final String partyId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double totalAmount;
  final double taxAmount;
  final String? notes;
  final List<Map<String, dynamic>> items;
  final InvoiceDirection invoiceDirection;

  const AddInvoice({
    required this.storeId,
    required this.partyId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.totalAmount,
    required this.taxAmount,
    this.notes,
    required this.items,
    this.invoiceDirection = InvoiceDirection.sales,
  });

  @override
  List<Object?> get props => [
        storeId,
        partyId,
        invoiceNumber,
        invoiceDate,
        totalAmount,
        taxAmount,
        notes,
        items,
        invoiceDirection,
      ];
}

class UpdateInvoice extends InvoiceEvent {
  final Invoice invoice;

  UpdateInvoice(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

class DeleteInvoice extends InvoiceEvent {
  final String storeId;
  final String invoiceId;

  DeleteInvoice(this.storeId, this.invoiceId);

  @override
  List<Object?> get props => [storeId, invoiceId];
}

class CreateReturnInvoice extends InvoiceEvent {
  final String storeId;
  final String originalInvoiceId;
  final String invoiceNumber;
  final double totalAmount;
  final double taxAmount;
  final String? reason;

  const CreateReturnInvoice({
    required this.storeId,
    required this.originalInvoiceId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.taxAmount,
    this.reason,
  });

  @override
  List<Object?> get props => [
        storeId,
        originalInvoiceId,
        invoiceNumber,
        totalAmount,
        taxAmount,
        reason,
      ];
}

class ImportInvoices extends InvoiceEvent {
  final String storeId;
  final String csvContent;

  const ImportInvoices({
    required this.storeId,
    required this.csvContent,
  });

  @override
  List<Object?> get props => [storeId, csvContent];
}

// States
abstract class InvoiceState extends Equatable {
  @override
  List<Object?> get props => [];
}

class InvoiceInitial extends InvoiceState {}

class InvoiceLoading extends InvoiceState {}

class InvoicesLoaded extends InvoiceState {
  final List<Invoice> invoices;

  InvoicesLoaded(this.invoices);

  @override
  List<Object?> get props => [invoices];
}

class InvoiceError extends InvoiceState {
  final String message;

  InvoiceError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class InvoiceBloc extends Bloc<InvoiceEvent, InvoiceState> {
  final InvoiceRepository _invoiceRepository;
  InvoiceBloc({required InvoiceRepository invoiceRepository})
      : _invoiceRepository = invoiceRepository,
        super(InvoiceInitial()) {
    on<LoadInvoices>(_onLoadInvoices);
    on<AddInvoice>(_onAddInvoice);
    on<UpdateInvoice>(_onUpdateInvoice);
    on<DeleteInvoice>(_onDeleteInvoice);
    on<CreateReturnInvoice>(_onCreateReturnInvoice);
    on<ImportInvoices>(_onImportInvoices);
  }

  void _onLoadInvoices(LoadInvoices event, Emitter<InvoiceState> emit) async {
    try {
      emit(InvoiceLoading());

      Stream<List<Invoice>> invoicesStream;

      if (event.invoiceDirection != null) {
        // If invoiceDirection is specified, we need to get all invoices and filter them
        invoicesStream = _invoiceRepository
            .getInvoices(event.storeId, partyId: event.partyId)
            .map((invoices) => invoices
                .where((invoice) =>
                    invoice.invoiceDirection == event.invoiceDirection)
                .toList());
      } else {
        invoicesStream = _invoiceRepository.getInvoices(event.storeId,
            partyId: event.partyId);
      }

      await emit.forEach(
        invoicesStream,
        onData: (invoices) => InvoicesLoaded(invoices),
        onError: (error, stackTrace) => InvoiceError(error.toString()),
      );
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  void _onAddInvoice(AddInvoice event, Emitter<InvoiceState> emit) async {
    emit(InvoiceLoading());
    try {
      await _invoiceRepository.addInvoice(
        storeId: event.storeId,
        partyId: event.partyId,
        invoiceNumber: event.invoiceNumber,
        invoiceDate: event.invoiceDate,
        totalAmount: event.totalAmount,
        taxAmount: event.taxAmount,
        notes: event.notes,
        items: event.items,
        invoiceDirection: event.invoiceDirection.toString().split('.').last,
      );
      add(LoadInvoices(event.storeId));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  void _onUpdateInvoice(UpdateInvoice event, Emitter<InvoiceState> emit) async {
    emit(InvoiceLoading());
    try {
      await _invoiceRepository.updateInvoice(event.invoice);
      add(LoadInvoices(event.invoice.storeId));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  void _onDeleteInvoice(DeleteInvoice event, Emitter<InvoiceState> emit) async {
    emit(InvoiceLoading());
    try {
      await _invoiceRepository.deleteInvoice(event.storeId, event.invoiceId);
      add(LoadInvoices(event.storeId));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  void _onCreateReturnInvoice(
      CreateReturnInvoice event, Emitter<InvoiceState> emit) async {
    emit(InvoiceLoading());
    try {
      // First, we need to load the original invoice to get the details for the return
      final originalInvoice = await _invoiceRepository.getInvoiceById(
          event.storeId, event.originalInvoiceId);

      // Create the return invoice based on the original
      final returnInvoice = originalInvoice.createReturnInvoice(
        newId: '', // Will be generated by Firestore
        newInvoiceNumber: event.invoiceNumber,
        newTotalAmount: event.totalAmount,
        newTaxAmount: event.taxAmount,
        newReason: event.reason,
      );
      await _invoiceRepository.updateInvoice(returnInvoice);
      add(LoadInvoices(event.storeId));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  void _onImportInvoices(
      ImportInvoices event, Emitter<InvoiceState> emit) async {
    emit(InvoiceLoading());
    try {
      await _invoiceRepository.importInvoicesFromCsv(
          event.storeId, event.csvContent);
      add(LoadInvoices(event.storeId));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }
}
