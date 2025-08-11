import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class SettingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

// States
abstract class SettingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsLoaded extends SettingsState {
  final String currentFY;
  final String companyName;
  final String companyGSTIN;

  SettingsLoaded({
    this.currentFY = '2023-2024',
    this.companyName = 'Meritfox Technologies',
    this.companyGSTIN = '10AABCU9603R1Z2',
  });

  @override
  List<Object?> get props => [currentFY, companyName, companyGSTIN];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(SettingsLoaded());
}
