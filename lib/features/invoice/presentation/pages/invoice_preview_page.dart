import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
// import 'package:gspappv2/core/constants/app_colors.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_with_details.dart';
import 'package:gspappv2/features/invoice/domain/services/invoice_pdf_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

// Define AppColors class since it doesn't exist
class AppColors {
  static const Color background = Color(0xFFF5F5F5);
}

class InvoicePreviewPage extends StatefulWidget {
  final InvoiceWithDetails invoiceWithDetails;

  const InvoicePreviewPage({
    Key? key,
    required this.invoiceWithDetails,
  }) : super(key: key);

  @override
  State<InvoicePreviewPage> createState() => _InvoicePreviewPageState();
}

class _InvoicePreviewPageState extends State<InvoicePreviewPage> {
  late Future<Uint8List> _pdfFuture;
  final InvoicePdfGenerator _pdfGenerator = InvoicePdfGenerator();

  @override
  void initState() {
    super.initState();
    _pdfFuture = _pdfGenerator.generatePdf(widget.invoiceWithDetails);
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoiceWithDetails.invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Preview'),
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _printPdf,
            tooltip: 'Print',
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _sharePdf,
            tooltip: 'Share',
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _savePdf,
            tooltip: 'Save',
          ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to generate invoice preview',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge, // Updated from headline6
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          // Updated from bodyText2
                          color: Colors.red,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _pdfFuture = _pdfGenerator
                            .generatePdf(widget.invoiceWithDetails);
                      });
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No preview available'),
            );
          }

          return PdfPreview(
            build: (format) => snapshot.data!,
            pdfFileName: 'invoice_${invoice.invoiceNumber}.pdf',
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            initialPageFormat: PdfPageFormat.a4,
            scrollViewDecoration: BoxDecoration(
              color: AppColors.background,
            ),
          );
        },
      ),
    );
  }

  Future<void> _printPdf() async {
    try {
      final pdfData = await _pdfFuture;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfData,
        name: 'invoice_${widget.invoiceWithDetails.invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to print invoice: ${e.toString()}');
    }
  }

  Future<void> _sharePdf() async {
    try {
      final pdfData = await _pdfFuture;
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/invoice_${widget.invoiceWithDetails.invoice.invoiceNumber}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      await Share.shareFiles(
        [filePath],
        text: 'Invoice ${widget.invoiceWithDetails.invoice.invoiceNumber}',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to share invoice: ${e.toString()}');
    }
  }

  Future<void> _savePdf() async {
    try {
      final pdfData = await _pdfFuture;
      final result = await Printing.sharePdf(
        bytes: pdfData,
        filename:
            'invoice_${widget.invoiceWithDetails.invoice.invoiceNumber}.pdf',
      );

      if (result) {
        _showSuccessSnackBar('Invoice saved successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save invoice: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
