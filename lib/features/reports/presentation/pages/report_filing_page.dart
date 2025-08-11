import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/reports/domain/models/report_type.dart';
import 'package:gspappv2/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:gspappv2/features/invoice/presentation/bloc/invoice_bloc.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_with_details.dart';
import 'package:gspappv2/features/invoice/domain/services/gst_filing_service.dart';
import 'package:gspappv2/features/party/data/repositories/party_repository.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReportFilingPage extends StatefulWidget {
  final ReportType type;

  const ReportFilingPage({super.key, required this.type});

  @override
  State<ReportFilingPage> createState() => _ReportFilingPageState();
}

class _ReportFilingPageState extends State<ReportFilingPage> {
  final _otpController = TextEditingController();
  String? _authToken;
  String? _errorMessage;
  bool _isAuthenticating = false;

  // Add business registration status
  bool _isBusinessRegistered = false;
  String? _businessRefId;
  String? _businessRegistrationError;

  // Timer for detecting stuck operations
  Timer? _stuckOperationTimer;

  // Add this field to track the current filing record ID
  String? _currentFilingRecordId;

  @override
  void initState() {
    super.initState();
    // Authenticate with Masters India API when the page loads
    _authenticateWithMastersIndia();
  }

  // Start timer to detect potentially stuck operations
  void _startStuckOperationTimer(String operation) {
    // Cancel any existing timer
    _stuckOperationTimer?.cancel();

    // Set a new timer for 30 seconds
    _stuckOperationTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        print('TIMEOUT WARNING: Operation may be stuck: $operation');
        _showStuckOperationDialog(operation);
      }
    });
  }

  // Stop the stuck operation timer
  void _stopStuckOperationTimer() {
    _stuckOperationTimer?.cancel();
    _stuckOperationTimer = null;
  }

  // Show dialog warning about potentially stuck operation
  void _showStuckOperationDialog(String operation) {
    if (!mounted) return; // Add check at the beginning

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Operation Taking Too Long'),
          content: Text(
            'The operation "$operation" is taking longer than expected. This could be due to:\n\n'
            '• Slow internet connection\n'
            '• Server issues\n'
            '• A large number of invoices being processed\n\n'
            'You can continue waiting or cancel the operation.',
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close this dialog
                // Continue waiting
              },
              child: const Text('Continue Waiting'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close this dialog

                // Try to reset the state and return to previous screen
                try {
                  // Clear any potentially stuck dialogs
                  Navigator.of(context, rootNavigator: true).popUntil((route) =>
                      route.isFirst || route.settings.name == '/reportFiling');

                  // Reset the state
                  if (mounted) {
                    context.read<ReportsBloc>().add(CancelFiling());

                    // Add a record of the canceled operation
                    final storeProvider =
                        Provider.of<StoreProvider>(context, listen: false);
                    final selectedStore = storeProvider.selectedStore;

                    if (selectedStore != null) {
                      context.read<ReportsBloc>().add(
                            RecordFilingAttempt(
                              storeId: selectedStore.id,
                              type: widget.type,
                              period: _getReturnPeriod(),
                              status: 'Error',
                              errorMessage: 'Operation timed out: $operation',
                              directionType: widget.type == ReportType.gstr1
                                  ? 'outward'
                                  : null,
                            ),
                          );
                    }

                    // Navigate back
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  print('Error handling timeout: $e');
                  // Just try to get back to a usable state
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Cancel Operation'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _stuckOperationTimer?.cancel();
    super.dispose();
  }

  Future<void> _authenticateWithMastersIndia() async {
    if (!mounted) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    // Start stuck operation timer
    _startStuckOperationTimer('Authentication');

    try {
      // API endpoint for authentication
      final url =
          Uri.parse('https://prod-api.mastersindia.co/api/v1/token-auth/');

      // Request headers
      final headers = {
        'Connection': 'keep-alive',
        'client_id': 'mUraQiNZMikjBhdB0RDBsAw4uqqCzp0F',
        'client_secret': 'YgQSXrysgIqfqaoIBI8seW5u8O9JsohQ',
        'Content-Type': 'application/json',
      };

      // Request body
      final body = json.encode({
        'username': 'abhishek@meritfox.net',
        'password': 'Merit@123456',
      });

      // Make the POST request
      final response = await http.post(url, headers: headers, body: body);

      // Stop the stuck operation timer since we got a response
      _stopStuckOperationTimer();

      // Check if the request was successful
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Extract the token
        _authToken = responseData['token'];
        print('Auth Token: $_authToken');

        if (!mounted) return;

        setState(() {
          _isAuthenticating = false;
        });

        // After successful authentication, register the business
        if (mounted) {
          await _registerBusinessWithGstService();
        }
      } else {
        throw Exception(
            'Failed to authenticate: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Authentication failed: ${e.toString()}';
      });
      print('Authentication error: $e');
    }
  }

  // Method to register business with GST service
  Future<void> _registerBusinessWithGstService() async {
    if (!mounted) return;

    if (_authToken == null) {
      setState(() {
        _errorMessage =
            'Authentication token required for business registration';
        _businessRegistrationError = 'Authentication token required';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true; // Reuse the loading state
      _businessRegistrationError = null;
    });

    // Start stuck operation timer
    _startStuckOperationTimer('Business Registration');

    try {
      print('========== STARTING BUSINESS REGISTRATION ==========');
      // API endpoint for business registration
      final url = Uri.parse(
          'https://router.mastersindia.co/api/v1/bussiness/gst-svc/add/');

      // Request headers with JWT token prefix
      final headers = {
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Authorization': 'JWT $_authToken',
        // No Content-Type header needed for form data
      };

      // Get the selected store
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;

      // Use the store's GSTIN if available, otherwise use the default
      final gstin = selectedStore?.gstin ?? "20ABQFM3394J1ZY";

      // Create a Map to be used directly as the request body (form data)
      final Map<String, String> formData = {
        'gstin_number': '20ABQFM3394J1ZY',
        'gst_userName': 'meritfox3',
      };

      print('Registering business with GST service...');
      print('URL: $url');
      print('Headers: $headers');
      print('Form data: $formData');

      // Make the POST request with the Map directly as the body parameter
      final response = await http.post(
        url,
        headers: headers,
        body: formData,
      );

      // Stop the stuck operation timer
      _stopStuckOperationTimer();

      print('Business registration response received: ${response.statusCode}');

      // First, make sure to close any loading dialogs
      try {
        if (mounted) {
          // Instead of popUntil, just pop once if there's a dialog showing
          if (ModalRoute.of(context)?.isCurrent == false) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          print('Successfully closed dialog after business registration');
        }
      } catch (e) {
        print('Error closing dialogs: $e');
      }

      if (!mounted) return;

      setState(() {
        _isAuthenticating = false;
      });

      // Check if the request was successful
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Business Registration Response: $responseData');

        if (!mounted) return;

        setState(() {
          _isBusinessRegistered = true;
          _businessRefId = responseData['ref_id'];
          _businessRegistrationError = null;
        });

        // Add a small delay to allow UI to update
        await Future.delayed(const Duration(milliseconds: 300));

        // Show a more prominent success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Business registered successfully: ${responseData['message']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        print('========== BUSINESS REGISTRATION SUCCESSFUL ==========');
        print('Business REF ID: $_businessRefId');
        print('Registration status: $_isBusinessRegistered');
      } else {
        print(
            'Failed to register business: ${response.statusCode} - ${response.body}');

        if (!mounted) return;

        setState(() {
          _isBusinessRegistered = false;
          _businessRegistrationError =
              'Failed to register: ${response.statusCode} - ${response.body}';
        });

        // Show error but don't throw exception as this step is optional
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Business registration warning: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        print('========== BUSINESS REGISTRATION FAILED ==========');
      }
    } catch (e) {
      // Stop the stuck operation timer
      _stopStuckOperationTimer();

      print('========== BUSINESS REGISTRATION ERROR ==========');
      print('Error details: $e');

      if (!mounted) return;

      setState(() {
        _isAuthenticating = false;
        _isBusinessRegistered = false;
        _businessRegistrationError = e.toString();
      });

      print('Business registration error: $e');

      // Show error but don't throw exception as this step is optional
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Business registration warning: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      // Make absolutely sure we update the UI state
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
      print('========== BUSINESS REGISTRATION PROCESS COMPLETE ==========');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File ${widget.type.title}'),
        actions: [
          // Help button to assist users who might be stuck
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Filing Help'),
                    content: const SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Need help with the GST filing process?',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('If you encounter any issues:'),
                          SizedBox(height: 4),
                          Text('• Check your internet connection'),
                          Text('• Make sure you have sales invoices to report'),
                          Text('• Verify your GST registration details'),
                          SizedBox(height: 8),
                          Text('If the screen seems stuck:'),
                          SizedBox(height: 4),
                          Text(
                              '• Use the Cancel button at the bottom of the filing screen'),
                          Text(
                              '• Try restarting the app and the filing process'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ReportsBloc, ReportsState>(
        listener: (context, state) {
          if (state is ReportsError) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'DISMISS',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          } else if (state is FilingRecorded) {
            // Show a snackbar to confirm filing was recorded
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Filing status recorded successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          // Handle various states with appropriate UI
          if (state is ReportFiledSuccess) {
            return _buildSuccessView(state.acknowledgmentNo);
          }

          // If we're in the loading state
          if (state is ReportsLoading) {
            return _buildLoadingState();
          }

          // If OTP verification is needed
          if (state is OTPSent) {
            return _buildOTPVerification();
          }

          // Show debugging information in development mode
          // This will help identify where in the process it's getting stuck
          return Stack(
            children: [
              _buildInitialView(),

              // Show debug overlay in development mode
              if (kDebugMode)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black.withOpacity(0.7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('DEBUG - Current state: ${state.runtimeType}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        Text(
                            'Auth token: ${_authToken?.substring(0, 15) ?? 'null'}...',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        Text('Business registered: $_isBusinessRegistered',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        Text('Business ref ID: ${_businessRefId ?? 'null'}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        Text('Is authenticating: $_isAuthenticating',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        Text(
                            'Current filing ID: ${_currentFilingRecordId ?? 'null'}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                // Force close any dialogs
                                try {
                                  Navigator.of(context, rootNavigator: true)
                                      .popUntil((route) =>
                                          !(route is PopupRoute ||
                                              route is ModalRoute));
                                } catch (e) {
                                  print('Error closing dialogs: $e');
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.all(4),
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Close Dialogs',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 10)),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                // Reset authentication state
                                setState(() {
                                  _isAuthenticating = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.all(4),
                                side: const BorderSide(color: Colors.yellow),
                              ),
                              child: const Text('Reset Auth',
                                  style: TextStyle(
                                      color: Colors.yellow, fontSize: 10)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Show OTP verification dialog and handle OTP submission
  void _showOtpVerificationDialog(Map<String, dynamic> responseData) {
    if (!mounted) return; // Add check at the beginning

    final otpController = TextEditingController();
    final transactionId = responseData['transaction_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('OTP Verification Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'An OTP has been sent to your registered mobile number. Please enter it below to complete the filing.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                ),
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
              onPressed: () {
                Navigator.of(context).pop();
                if (otpController.text.isNotEmpty && mounted) {
                  // Add mounted check
                  _verifyOtpAndCompleteFiling(
                    transactionId,
                    otpController.text,
                  );
                }
              },
              child: const Text('Verify OTP'),
            ),
          ],
        );
      },
    );
  }

  // Verify OTP and complete the filing process
  Future<void> _verifyOtpAndCompleteFiling(
      String transactionId, String otp) async {
    if (!mounted) return; // Add check at the beginning

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying OTP...'),
            ],
          ),
        );
      },
    );

    try {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;

      if (selectedStore == null) {
        throw Exception('No store selected');
      }

      // API endpoint for OTP verification
      final url = Uri.parse(
          'https://prod-api.mastersindia.co/api/v1/returns/otp-verify/');

      // Request headers with JWT token
      final headers = {
        'Connection': 'keep-alive',
        'client_id': 'mUraQiNZMikjBhdB0RDBsAw4uqqCzp0F',
        'client_secret': 'YgQSXrysgIqfqaoIBI8seW5u8O9JsohQ',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      };

      // Request body with transaction ID and OTP
      final body = json.encode({
        "transaction_id": transactionId,
        "otp": otp,
        "ref_id": _businessRefId,
      });

      // Make the POST request
      final response = await http.post(url, headers: headers, body: body);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      } else {
        return; // Exit if not mounted anymore
      }

      // Check if the request was successful
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('OTP Verification Response: $responseData');

        // Show success message
        if (responseData['status'] == 'Success') {
          // Record successful filing with acknowledgment number
          if (mounted) {
            context.read<ReportsBloc>().add(
                  UpdateFilingAttempt(
                    reportId: _currentFilingRecordId,
                    storeId: selectedStore.id,
                    type: widget.type,
                    period: _getReturnPeriod(),
                    status: 'Filed',
                    acknowledgmentNo: responseData['acknowledgment_number'] ??
                        responseData['ack_number'] ??
                        responseData['ack_no'] ??
                        'Confirmed',
                    directionType:
                        widget.type == ReportType.gstr1 ? 'outward' : null,
                  ),
                );
          }

          // Show success dialog with acknowledgment details
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Filing Completed Successfully'),
                  content: Container(
                    width: double.maxFinite,
                    height: 300,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your GST return has been successfully filed!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          const Text('Response Details:'),
                          const SizedBox(height: 8),
                          SelectableText(
                            JsonEncoder.withIndent('  ').convert(responseData),
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // Also pop the filing page
                      },
                      child: const Text('Back to Reports'),
                    ),
                  ],
                );
              },
            );
          }
        } else {
          // Record OTP verification failure
          if (mounted) {
            context.read<ReportsBloc>().add(
                  UpdateFilingAttempt(
                    reportId: _currentFilingRecordId,
                    storeId: selectedStore.id,
                    type: widget.type,
                    period: _getReturnPeriod(),
                    status: 'Error',
                    errorMessage:
                        'OTP Verification failed: ${responseData['message'] ?? "Unknown error"}',
                    directionType:
                        widget.type == ReportType.gstr1 ? 'outward' : null,
                  ),
                );

            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Verification failed: ${responseData['message'] ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Record OTP verification API error
        if (mounted) {
          context.read<ReportsBloc>().add(
                UpdateFilingAttempt(
                  reportId: _currentFilingRecordId,
                  storeId: selectedStore.id,
                  type: widget.type,
                  period: _getReturnPeriod(),
                  status: 'Error',
                  errorMessage:
                      'OTP API Error: ${response.statusCode} - ${response.body}',
                  directionType:
                      widget.type == ReportType.gstr1 ? 'outward' : null,
                ),
              );
        }

        throw Exception(
            'Failed to verify OTP: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Make sure to close the loading dialog if an error occurs
      try {
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (_) {}

      print('OTP verification error: $e');

      // Record OTP verification error
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;

      if (selectedStore != null && _currentFilingRecordId != null && mounted) {
        context.read<ReportsBloc>().add(
              UpdateFilingAttempt(
                reportId: _currentFilingRecordId,
                storeId: selectedStore.id,
                type: widget.type,
                period: _getReturnPeriod(),
                status: 'Error',
                errorMessage: 'OTP Verification error: ${e.toString()}',
                directionType:
                    widget.type == ReportType.gstr1 ? 'outward' : null,
              ),
            );
      }

      // Special handling for validation errors
      if (e.toString().contains('invoice data contains errors') ||
          e.toString().contains('invalid product data')) {
        _showInvoiceValidationErrorDialog(e.toString());
      } else {
        // Regular error handling for other errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filing error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  // Helper method to extract state from address (simplified)
  String? _getStateFromAddress(String? address) {
    if (address == null || address.isEmpty) {
      return null;
    }

    // This is a simplified approach - in a real app, you would need a more robust solution
    // For now, just returning the last part of the address as state
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      final lastPart = parts.last.trim();
      // Return a state code - this needs to be mapped to proper GST state codes
      // For example, you could have a map of state names to GST state codes
      return lastPart;
    }
    return null;
  }

  // Helper method to get the current month's return period in MM-YYYY format
  String _getReturnPeriod() {
    final now = DateTime.now();
    // Get previous month for returns as GST returns are typically filed for the previous month
    final month = now.month > 1 ? now.month - 1 : 12;
    final year = now.month > 1 ? now.year : now.year - 1;
    return "${month.toString().padLeft(2, '0')}-$year";
  }

  Widget _buildSuccessView(String acknowledgmentNo) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'Report Filed Successfully!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Acknowledgment Number:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              acknowledgmentNo,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _downloadAcknowledgment(acknowledgmentNo),
              icon: const Icon(Icons.download),
              label: const Text('Download Acknowledgment'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.read<ReportsBloc>().add(CancelFiling());
                Navigator.pop(context);
              },
              child: const Text('Back to Reports'),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadAcknowledgment(String acknowledgmentNo) {
    // TODO: Implement acknowledgment download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading acknowledgment...')),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Processing your filing...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Please wait while we:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildProcessingStep('Processing invoices'),
            _buildProcessingStep('Uploading documents'),
            _buildProcessingStep('Generating filing'),
            _buildProcessingStep('Requesting OTP'),

            // Add cancel button to help if stuck
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text('Cancel Filing',
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Cancel Filing?'),
                      content: const Text(
                          'Are you sure you want to cancel the filing process? This will return you to the previous screen.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                          },
                          child: const Text('No, Continue'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
                            // Reset state and go back
                            Navigator.of(context).pop(); // Close dialog
                            context.read<ReportsBloc>().add(CancelFiling());
                            Navigator.of(context)
                                .pop(); // Return to previous screen
                          },
                          child: const Text('Yes, Cancel'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.arrow_right),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildOTPVerification() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter OTP',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_otpController.text.length == 6) {
                  context
                      .read<ReportsBloc>()
                      .add(VerifyOTP(_otpController.text));
                }
              },
              child: const Text('Verify & File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Authentication status section
            if (_isAuthenticating) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Authenticating with GST filing system...'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authentication Error',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage!),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _authenticateWithMastersIndia,
                      child: const Text('Retry Authentication'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else if (_authToken != null) ...[
              // Authentication successful
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication Successful',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Successfully authenticated with GST filing system.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Business registration status section
              if (_isBusinessRegistered) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Registration Successful',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'Your business is successfully registered for GST filing.'),
                      const SizedBox(height: 4),
                      if (_businessRefId != null) ...[
                        Text(
                          'Reference ID: $_businessRefId',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else if (_businessRegistrationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Registration Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_businessRegistrationError!),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _registerBusinessWithGstService,
                        child: const Text('Retry Registration'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Original content
            Text(
              'One Click Filing',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'We will automatically:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildStep(1, 'Process all invoices'),
            _buildStep(2, 'Upload required documents'),
            _buildStep(3, 'Generate and verify filing'),
            _buildStep(4, 'Complete filing after OTP verification'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _authToken == null
                  ? null
                  : () {
                      _startGstFiling();
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'Start Filing',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),

            // For debugging - Display token details
            if (_authToken != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'API Token Details (For Development)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Authentication Token:'),
                    const SizedBox(height: 4),
                    SelectableText(
                      _authToken!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // Method to start the GST filing process
  Future<void> _startGstFiling() async {
    if (!mounted) return; // Add check at the beginning

    if (_authToken == null) {
      setState(() {
        _errorMessage = 'Authentication required before filing';
      });
      return;
    }

    if (!_isBusinessRegistered) {
      // Show an alert and offer to register the business
      if (!mounted) return; // Add check before showing dialog

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Business Registration Required'),
            content: const Text(
                'Your business needs to be registered with the GST filing service before proceeding. Would you like to register now?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (mounted) {
                    // Add check before proceeding with registration
                    _registerBusinessWithGstService().then((_) {
                      // After registration, check if successful and continue
                      if (_isBusinessRegistered && mounted) {
                        _proceedWithFiling();
                      }
                    });
                  }
                },
                child: const Text('Register Now'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Business is registered, proceed with filing
    if (mounted) {
      _proceedWithFiling();
    }
  }

  // Helper method to continue with the filing process
  Future<void> _proceedWithFiling() async {
    try {
      print('========== STARTING FILING PROCESS ==========');
      // Notify the user that we're starting the filing process
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting GST filing process...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Record the filing attempt
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;

      if (selectedStore != null && mounted) {
        // Create a record of this filing attempt
        context.read<ReportsBloc>().add(
              RecordFilingAttempt(
                storeId: selectedStore.id,
                type: widget.type,
                period: _getReturnPeriod(),
                status: 'Processing',
                directionType:
                    widget.type == ReportType.gstr1 ? 'outward' : null,
              ),
            );

        // Wait for the record to be created and get its ID
        await for (final state in context.read<ReportsBloc>().stream) {
          if (state is FilingRecorded) {
            _currentFilingRecordId = state.reportId;
            print('Filing record created with ID: $_currentFilingRecordId');
            break;
          } else if (state is ReportsError) {
            throw Exception(
                'Failed to record filing attempt: ${state.message}');
          }
        }
      }

      // File outward supplies if it's a GSTR-1 filing
      if (widget.type == ReportType.gstr1 && mounted) {
        await _fileOutwardSupplies();
      } else {
        // For non-GSTR-1 filings, continue with the generic process
        if (mounted) {
          context.read<ReportsBloc>().add(InitiateReportFiling(widget.type));
        }
      }
    } catch (e) {
      print('========== FILING PROCESS ERROR ==========');
      print('Error details: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error starting GST filing: ${e.toString()}';
      });
      print('GST Filing error: $e');

      // Update the filing record with the error
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;

      if (selectedStore != null && _currentFilingRecordId != null && mounted) {
        context.read<ReportsBloc>().add(
              UpdateFilingAttempt(
                reportId: _currentFilingRecordId,
                storeId: selectedStore.id,
                type: widget.type,
                period: _getReturnPeriod(),
                status: 'Error',
                errorMessage: e.toString(),
                directionType:
                    widget.type == ReportType.gstr1 ? 'outward' : null,
              ),
            );
      }

      // Special handling for validation errors
      if (e.toString().contains('invoice data contains errors') ||
          e.toString().contains('invalid product data')) {
        _showInvoiceValidationErrorDialog(e.toString());
      } else {
        // Regular error handling for other errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filing error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  // Method to handle outward supplies filing (GSTR-1)
  Future<void> _fileOutwardSupplies() async {
    if (!mounted) return;

    // Show a progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Processing Outward Supplies'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Preparing invoice data for filing...'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: null, // Indeterminate progress
                backgroundColor: Colors.grey[200],
              ),
            ],
          ),
        );
      },
    );

    try {
      // Get the selected store
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;

      if (selectedStore == null) {
        throw Exception('No store selected');
      }

      // 1. Load outward invoices for the store
      final invoiceBloc = context.read<InvoiceBloc>();

      // Create repositories directly instead of using Provider
      // This avoids the Provider not found error
      final invoiceRepository = InvoiceRepository();
      final partyRepository = PartyRepository();

      invoiceBloc.add(LoadInvoices(
        selectedStore.id,
        invoiceDirection: InvoiceDirection.sales,
      ));

      List<Invoice> invoices = [];

      // Wait for invoices to load
      await for (final state in invoiceBloc.stream) {
        if (state is InvoicesLoaded) {
          invoices = state.invoices;
          break;
        } else if (state is InvoiceError) {
          throw Exception('Failed to load invoices: ${state.message}');
        }
      }

      if (!mounted) return;

      // Close the progress dialog and update to next stage
      Navigator.of(context).pop();

      if (invoices.isEmpty) {
        // Show warning if no invoices found
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('No Invoices Found'),
              content: const Text(
                  'No outward supply invoices were found for the selected period. Please create invoices before filing.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        throw Exception('No invoices found to file');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Preparing GST Filing'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Processing ${invoices.length} invoices...'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.3, // Show some progress
                  backgroundColor: Colors.grey[200],
                ),
              ],
            ),
          );
        },
      );

      // 2. Fetch additional details for each invoice to create InvoiceWithDetails objects
      List<InvoiceWithDetails> invoicesWithDetails = [];

      for (final invoice in invoices) {
        try {
          // Get invoice items
          final items = await invoiceRepository
              .getInvoiceItems(invoice.storeId, invoice.id)
              .first;

          // Get party details
          final party = await partyRepository.getPartyById(
              selectedStore.id, invoice.partyId);

          if (party != null) {
            // Create InvoiceWithDetails object
            invoicesWithDetails.add(
              InvoiceWithDetails(
                invoice: invoice,
                party: party,
                items: items,
                store: selectedStore,
              ),
            );
          } else {
            print(
                'Warning: Party not found for invoice ${invoice.id}, skipping');
          }
        } catch (e) {
          print('Error loading details for invoice ${invoice.id}: $e');
        }
      }

      if (invoicesWithDetails.isEmpty) {
        throw Exception('Failed to load invoice details');
      }

      // Validate invoice items before proceeding
      _validateInvoiceItemsForGst(invoicesWithDetails);

      // 2. Format invoices for the GST service
      final gstFilingService = GstFilingService();
      // Convert to GST filing format
      final formattedData =
          gstFilingService.convertToGstFilingFormat(invoicesWithDetails);

      if (!mounted) return;

      // Update progress
      Navigator.of(context).pop();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Submitting to GST Portal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Sending data to GST portal...'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.6, // Show more progress
                  backgroundColor: Colors.grey[200],
                ),
              ],
            ),
          );
        },
      );

      // 3. Submit the data to GST portal - using direct HTTP for now
      // Implementation will depend on the actual API for submitting data
      final url = Uri.parse(
          'https://api-platform.mastersindia.co/api/v1/saas-apis/sales/');

      // Request headers with JWT token
      final headers = {
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Authorization': 'JWT $_authToken',
        'Content-Type': 'application/json',
      };

      // Create request body
      final body = json
          .encode({'saleData': json.decode(formattedData)['saleData'] ?? []});

      // Debug logging to inspect what's being sent
      print('==== GST FILING DEBUG INFO ====');
      print('GSTIN: ${selectedStore.gstin}');
      print('Period: ${_getReturnPeriod()}');
      print('Ref ID: $_businessRefId');
      print('Request URL: $url');
      print('Request Headers: $headers');

      // Log the formatted data in a readable format
      try {
        print(
            'Formatted data (abbreviated): ${formattedData.substring(0, 500)}...');
      } catch (e) {
        print('Error printing formatted data: $e');
      }

      // Make POST request
      final response = await http.post(url, headers: headers, body: body);
      final responseData = json.decode(response.body);

      // Log the API response for debugging
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (!mounted) return;

      // Close progress dialog
      Navigator.of(context).pop();

      // 4. Check the response and handle OTP if needed
      if (response.statusCode == 200 && responseData['requires_otp'] == true) {
        // Show OTP verification dialog
        _showOtpVerificationDialog(responseData);

        // Update the filing record with processing status
        if (_currentFilingRecordId != null && mounted) {
          context.read<ReportsBloc>().add(
                UpdateFilingAttempt(
                  reportId: _currentFilingRecordId,
                  storeId: selectedStore.id,
                  type: widget.type,
                  period: _getReturnPeriod(),
                  status: 'Awaiting OTP',
                  directionType: 'outward',
                ),
              );
        }
      } else if (response.statusCode == 200) {
        // Handle successful filing without OTP
        final acknowledgmentNo = responseData['acknowledgment_number'] ??
            responseData['ack_number'] ??
            responseData['ack_no'] ??
            'Confirmed';

        // Update the filing record as completed
        if (_currentFilingRecordId != null && mounted) {
          context.read<ReportsBloc>().add(
                UpdateFilingAttempt(
                  reportId: _currentFilingRecordId,
                  storeId: selectedStore.id,
                  type: widget.type,
                  period: _getReturnPeriod(),
                  status: 'Filed',
                  acknowledgmentNo: acknowledgmentNo,
                  directionType: 'outward',
                ),
              );
        }

        // Show success message using the ReportsBloc
        if (mounted) {
          context
              .read<ReportsBloc>()
              .add(VerifyOTP('success')); // This will trigger a success state
        }
      } else {
        // Handle error
        // Check for "Invalid Product" error specifically
        final errorMessage = responseData['message'] ?? "Unknown error";
        if (errorMessage.contains("Invalid Product")) {
          print('GST API returned Invalid Product error: $errorMessage');

          // Extract any error details provided by the API
          final errorDetails = responseData['error_details'] ??
              responseData['details'] ??
              responseData['errors'] ??
              (responseData['data'] != null
                  ? responseData['data']['errors']
                  : null) ??
              [];

          // Try to find any nested error information
          Map<String, dynamic> allErrorInfo = {};
          responseData.forEach((key, value) {
            if (key != 'message' && key != 'status') {
              allErrorInfo[key] = value;
            }
          });

          print('All error information from API: $allErrorInfo');

          // Build helpful message for the user
          String detailedMessage =
              'GST Portal rejected your filing due to invalid product data.\n\n';

          if (errorDetails is List && errorDetails.isNotEmpty) {
            detailedMessage += 'Issues reported:\n';
            for (final detail in errorDetails) {
              detailedMessage += '• ${detail.toString()}\n';
            }
          } else if (allErrorInfo.isNotEmpty) {
            detailedMessage += 'API error information:\n';
            allErrorInfo.forEach((key, value) {
              detailedMessage += '• $key: $value\n';
            });
          } else {
            // Since we're passing local validation but the GST API still rejects,
            // provide more specialized guidance based on common issues
            detailedMessage += 'Since your data passed local validation but was rejected by the GST API, the issue might be:\n\n' +
                '1. HSN codes may be valid in format but not recognized by the GST system\n' +
                '2. The tax rate for a particular HSN code may not match GST requirements\n' +
                '3. The GSTIN may be valid in format but not active or recognized\n' +
                '4. The GST filing period might not be open for the selected month\n\n' +
                'Recommended action: Check that your HSN codes are officially recognized by the GST system and that your GSTIN is active.';
          }

          // Save the error details for debugging
          _addDebugLogsToFile(
              'gst_error_log.txt',
              'Time: ${DateTime.now()}\n' +
                  'Error Type: Invalid Product\n' +
                  'API Response: ${response.body}\n' +
                  'Formatted Data Sample: ${formattedData.substring(0, min(500, formattedData.length))}\n\n');

          throw Exception(detailedMessage);
        } else {
          throw Exception('Filing failed: $errorMessage');
        }
      }
    } catch (e) {
      // Make sure to close any open dialogs
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      print('Outward supplies filing error: $e');

      // Update the filing record with the error
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final selectedStore = storeProvider.selectedStore;

      if (selectedStore != null && _currentFilingRecordId != null && mounted) {
        context.read<ReportsBloc>().add(
              UpdateFilingAttempt(
                reportId: _currentFilingRecordId,
                storeId: selectedStore.id,
                type: widget.type,
                period: _getReturnPeriod(),
                status: 'Error',
                errorMessage: 'Outward supplies filing error: ${e.toString()}',
                directionType: 'outward',
              ),
            );
      }

      // Rethrow to be caught by the parent method
      throw e;
    }
  }

  // Method to validate invoice items for GST filing
  void _validateInvoiceItemsForGst(
      List<InvoiceWithDetails> invoicesWithDetails) {
    // Keep track of issues found
    List<String> invalidItems = [];
    List<String> missingHsn = [];
    List<String> zeroValueItems = [];

    for (final invoice in invoicesWithDetails) {
      for (final item in invoice.items) {
        // Check for missing HSN code (critical for GST filing)
        if (item.hsn == null || item.hsn!.trim().isEmpty) {
          missingHsn
              .add('${item.name} in invoice ${invoice.invoice.invoiceNumber}');
        }

        // Check for zero or negative values
        if (item.quantity <= 0) {
          zeroValueItems.add(
              '${item.name} has quantity ${item.quantity} in invoice ${invoice.invoice.invoiceNumber}');
        }

        if (item.unitPrice <= 0) {
          zeroValueItems.add(
              '${item.name} has unit price ${item.unitPrice} in invoice ${invoice.invoice.invoiceNumber}');
        }

        if (item.totalPrice <= 0) {
          zeroValueItems.add(
              '${item.name} has total price ${item.totalPrice} in invoice ${invoice.invoice.invoiceNumber}');
        }

        // Check for invalid tax rates (GST commonly accepts 0%, 5%, 12%, 18%, and 28%)
        final validGstRates = [0, 5, 12, 18, 28];
        if (!validGstRates.contains(item.taxRate.round())) {
          invalidItems.add(
              '${item.name} has tax rate ${item.taxRate}% in invoice ${invoice.invoice.invoiceNumber}');
        }
      }

      // Also check if any party has missing GST number
      if (invoice.party.gstin == null || invoice.party.gstin!.trim().isEmpty) {
        invalidItems.add(
            'Party ${invoice.party.name} is missing GSTIN in invoice ${invoice.invoice.invoiceNumber}');
      }
    }

    // If we found any issues, log them and throw an exception with details
    if (missingHsn.isNotEmpty ||
        zeroValueItems.isNotEmpty ||
        invalidItems.isNotEmpty) {
      String errorMessage = 'GST filing validation failed:\n';

      if (missingHsn.isNotEmpty) {
        errorMessage += '\nItems missing HSN code (required for GST):\n- ' +
            missingHsn.join('\n- ');
      }

      if (zeroValueItems.isNotEmpty) {
        errorMessage += '\n\nItems with zero or negative values:\n- ' +
            zeroValueItems.join('\n- ');
      }

      if (invalidItems.isNotEmpty) {
        errorMessage +=
            '\n\nItems with invalid values:\n- ' + invalidItems.join('\n- ');
      }

      // Log the detailed validation errors
      print(errorMessage);

      // For the user, provide a more helpful but concise error
      final userErrorMessage =
          'Your invoice data contains errors that prevent GST filing:\n' +
              (missingHsn.isNotEmpty
                  ? '• Some products are missing HSN codes\n'
                  : '') +
              (zeroValueItems.isNotEmpty
                  ? '• Some products have zero or negative values\n'
                  : '') +
              (invalidItems.isNotEmpty
                  ? '• Some products have invalid tax rates\n'
                  : '') +
              '\nPlease correct these issues before filing.';

      throw Exception(userErrorMessage);
    }

    print('All invoice items validated successfully for GST filing');
  }

  void _showInvoiceValidationErrorDialog(String errorMessage) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invoice Validation Error'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                const Text(
                  'You need to fix these issues in your invoices before filing.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();

                // Navigate to invoice list page to allow user to fix issues
                Navigator.of(context).pushNamed('/invoices');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text('Go to Invoices'),
            ),
          ],
        );
      },
    );
  }

  void _addDebugLogsToFile(String filename, String content) async {
    try {
      // Get the app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$filename';
      final file = File(path);

      // Append to the file (or create it if it doesn't exist)
      await file.writeAsString(content, mode: FileMode.append);
      print('Debug logs written to: $path');
    } catch (e) {
      print('Error writing debug logs: $e');
    }
  }
}
