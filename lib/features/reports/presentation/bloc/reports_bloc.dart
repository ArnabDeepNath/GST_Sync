import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gspappv2/features/reports/data/repositories/report_repository.dart';
import 'package:gspappv2/features/reports/domain/models/filed_report.dart';
import 'package:gspappv2/features/reports/domain/models/report_type.dart';

// Events
abstract class ReportsEvent extends Equatable {
  const ReportsEvent();
  @override
  List<Object?> get props => [];
}

class InitiateReportFiling extends ReportsEvent {
  final ReportType type;
  const InitiateReportFiling(this.type);

  @override
  List<Object?> get props => [type];
}

class VerifyOTP extends ReportsEvent {
  final String otp;
  const VerifyOTP(this.otp);

  @override
  List<Object?> get props => [otp];
}

class CancelFiling extends ReportsEvent {}

class LoadFiledReports extends ReportsEvent {
  final String storeId;
  const LoadFiledReports(this.storeId);

  @override
  List<Object?> get props => [storeId];
}

class DeleteFiledReport extends ReportsEvent {
  final String storeId;
  final String reportId;
  const DeleteFiledReport(this.storeId, this.reportId);

  @override
  List<Object?> get props => [storeId, reportId];
}

class RecordFilingAttempt extends ReportsEvent {
  final String storeId;
  final ReportType type;
  final String period;
  final String status;
  final String? acknowledgmentNo;
  final String? errorMessage;
  final String? directionType;

  const RecordFilingAttempt({
    required this.storeId,
    required this.type,
    required this.period,
    required this.status,
    this.acknowledgmentNo,
    this.errorMessage,
    this.directionType,
  });

  @override
  List<Object?> get props => [
        storeId,
        type,
        period,
        status,
        acknowledgmentNo,
        errorMessage,
        directionType
      ];
}

class UpdateFilingAttempt extends ReportsEvent {
  final String? reportId;
  final String storeId;
  final ReportType type;
  final String period;
  final String status;
  final String? acknowledgmentNo;
  final String? errorMessage;
  final String? directionType;

  const UpdateFilingAttempt({
    this.reportId,
    required this.storeId,
    required this.type,
    required this.period,
    required this.status,
    this.acknowledgmentNo,
    this.errorMessage,
    this.directionType,
  });

  @override
  List<Object?> get props => [
        reportId,
        storeId,
        type,
        period,
        status,
        acknowledgmentNo,
        errorMessage,
        directionType
      ];
}

// States
abstract class ReportsState extends Equatable {
  const ReportsState();
  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class OTPSent extends ReportsState {}

class ReportFiled extends ReportsState {}

class ReportFiledSuccess extends ReportsState {
  final String acknowledgmentNo;
  const ReportFiledSuccess(this.acknowledgmentNo);

  @override
  List<Object?> get props => [acknowledgmentNo];
}

class ReportsError extends ReportsState {
  final String message;
  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}

class FiledReportsLoaded extends ReportsState {
  final List<FiledReport> reports;
  final ReportType selectedType;

  const FiledReportsLoaded(this.reports, {required this.selectedType});

  @override
  List<Object?> get props => [reports, selectedType];
}

class FilingRecorded extends ReportsState {
  final String reportId;
  const FilingRecorded(this.reportId);

  @override
  List<Object?> get props => [reportId];
}

class ReportDeleteSuccess extends ReportsState {}

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final ReportRepository _reportRepository;
  StreamSubscription? _reportsSubscription;

  ReportsBloc({ReportRepository? reportRepository})
      : _reportRepository = reportRepository ?? ReportRepository(),
        super(ReportsInitial()) {
    on<InitiateReportFiling>(_onInitiateReportFiling);
    on<VerifyOTP>(_onVerifyOTP);
    on<CancelFiling>((event, emit) => emit(ReportsInitial()));
    on<LoadFiledReports>(_onLoadFiledReports);
    on<DeleteFiledReport>(_onDeleteFiledReport);
    on<RecordFilingAttempt>(_onRecordFilingAttempt);
    on<UpdateFilingAttempt>(_onUpdateFilingAttempt);
    on<_UpdateFiledReports>(_onUpdateFiledReports);
  }

  @override
  Future<void> close() {
    _reportsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onInitiateReportFiling(
    InitiateReportFiling event,
    Emitter<ReportsState> emit,
  ) async {
    emit(ReportsLoading());
    try {
      // TODO: Implement your API calls here
      await Future.delayed(const Duration(seconds: 2)); // Simulating API call

      // 1. Process all invoices
      // await _processInvoices();

      // 2. Upload required documents
      // await _uploadDocuments();

      // 3. Generate filing
      // await _generateFiling();

      // 4. Request OTP
      // await _requestOTP();

      emit(OTPSent());
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onVerifyOTP(
    VerifyOTP event,
    Emitter<ReportsState> emit,
  ) async {
    emit(ReportsLoading());
    try {
      await Future.delayed(const Duration(seconds: 1));
      emit(const ReportFiledSuccess('AA240330001')); // Example acknowledgment
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onLoadFiledReports(
    LoadFiledReports event,
    Emitter<ReportsState> emit,
  ) async {
    emit(ReportsLoading());
    try {
      // Cancel any existing subscription
      await _reportsSubscription?.cancel();

      // Subscribe to reports stream
      _reportsSubscription =
          _reportRepository.getFiledReports(event.storeId).listen((reports) {
        // Default to showing GSTR-1 reports initially
        add(_UpdateFiledReports(reports, selectedType: ReportType.gstr1));
      });
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onUpdateFiledReports(
    _UpdateFiledReports event,
    Emitter<ReportsState> emit,
  ) async {
    emit(FiledReportsLoaded(
      event.reports,
      selectedType: event.selectedType,
    ));
  }

  Future<void> _onDeleteFiledReport(
    DeleteFiledReport event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      await _reportRepository.deleteFiledReport(
        event.storeId,
        event.reportId,
      );
      emit(ReportDeleteSuccess());
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onRecordFilingAttempt(
    RecordFilingAttempt event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      final reportId = await _reportRepository.addFiledReport(
        storeId: event.storeId,
        type: event.type,
        period: event.period,
        status: event.status,
        acknowledgmentNo: event.acknowledgmentNo,
        errorMessage: event.errorMessage,
        directionType: event.directionType,
      );
      emit(FilingRecorded(reportId));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onUpdateFilingAttempt(
    UpdateFilingAttempt event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      await _reportRepository.updateFiledReport(
        event.reportId,
        storeId: event.storeId,
        type: event.type,
        period: event.period,
        status: event.status,
        acknowledgmentNo: event.acknowledgmentNo,
        errorMessage: event.errorMessage,
        directionType: event.directionType,
      );
      emit(FilingRecorded(event.reportId!));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }
}

// Private events for internal bloc use
class _UpdateFiledReports extends ReportsEvent {
  final List<FiledReport> reports;
  final ReportType selectedType;

  const _UpdateFiledReports(this.reports, {required this.selectedType});

  @override
  List<Object?> get props => [reports, selectedType];
}
