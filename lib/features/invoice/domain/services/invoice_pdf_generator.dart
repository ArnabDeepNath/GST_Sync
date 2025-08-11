import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:gspappv2/features/invoice/domain/models/document_type.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_with_details.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicePdfGenerator {
  /// Generate a PDF for an invoice
  Future<Uint8List> generatePdf(InvoiceWithDetails invoiceWithDetails) async {
    final pdf = pw.Document();

    // Load fonts
    final font = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    // Format dates and numbers
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header section with invoice details and branding
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        invoiceWithDetails.invoice.documentType.displayName
                            .toUpperCase(),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 40,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Invoice #: ${invoiceWithDetails.invoice.invoiceNumber}',
                        style: pw.TextStyle(font: font),
                      ),
                      pw.Text(
                        'Date: ${dateFormat.format(invoiceWithDetails.invoice.invoiceDate)}',
                        style: pw.TextStyle(font: font),
                      ),
                    ],
                  ),
                  pw.Container(
                    height: 80,
                    width: 80,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: invoiceWithDetails.invoice.id,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Bill from and bill to section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To:',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 16,
                        ),
                      ),
                      pw.Text(invoiceWithDetails.party.name),
                      if (invoiceWithDetails.party.address != null &&
                          invoiceWithDetails.party.address!.isNotEmpty)
                        pw.Text(invoiceWithDetails.party.address!),
                      if (invoiceWithDetails.party.phone != null &&
                          invoiceWithDetails.party.phone!.isNotEmpty)
                        pw.Text('Phone: ${invoiceWithDetails.party.phone!}'),
                      if (invoiceWithDetails.party.gstin != null &&
                          invoiceWithDetails.party.gstin!.isNotEmpty)
                        pw.Text('GSTIN: ${invoiceWithDetails.party.gstin!}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'From:',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 16,
                        ),
                      ),
                      pw.Text(invoiceWithDetails.store.name),
                      pw.Text(invoiceWithDetails.store.address),
                      if (invoiceWithDetails.store.gstin != null &&
                          invoiceWithDetails.store.gstin!.isNotEmpty)
                        pw.Text('GSTIN: ${invoiceWithDetails.store.gstin!}'),
                      if (invoiceWithDetails.store.phone != null &&
                          invoiceWithDetails.store.phone!.isNotEmpty)
                        pw.Text('Phone: ${invoiceWithDetails.store.phone!}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items table
              pw.Table.fromTextArray(
                headers: ['Item', 'HSN/SAC', 'Qty', 'Rate', 'Tax', 'Amount'],
                data: invoiceWithDetails.items.map((item) {
                  return [
                    item.name,
                    item.hsn ?? '',
                    item.quantity.toString(),
                    currencyFormat.format(item.unitPrice),
                    '${item.taxRate}%',
                    currencyFormat.format(item.totalPrice),
                  ];
                }).toList(),
                border: null,
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.blue900,
                ),
                headerDecoration: const pw.BoxDecoration(),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
              ),
              pw.Divider(thickness: 1),

              // Summary section
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 350),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:'),
                        pw.Text(
                            currencyFormat.format(invoiceWithDetails.subtotal)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Tax:'),
                        pw.Text(currencyFormat
                            .format(invoiceWithDetails.invoice.taxAmount)),
                      ],
                    ),
                    pw.Divider(thickness: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total:',
                          style: pw.TextStyle(
                            font: boldFont,
                          ),
                        ),
                        pw.Text(
                          currencyFormat
                              .format(invoiceWithDetails.invoice.totalAmount),
                          style: pw.TextStyle(
                            font: boldFont,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Notes
              if (invoiceWithDetails.invoice.notes != null &&
                  invoiceWithDetails.invoice.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 30),
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 14,
                  ),
                ),
                pw.Text(
                  invoiceWithDetails.invoice.notes!,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                  ),
                ),
              ],

              // Show original document info for returns
              if (invoiceWithDetails.invoice.documentType ==
                      DocumentType.returnInvoice &&
                  invoiceWithDetails.invoice.originalDocumentNumber !=
                      null) ...[
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Return Against:',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 14,
                        ),
                      ),
                      pw.Text(
                        'Original Invoice #: ${invoiceWithDetails.invoice.originalDocumentNumber}',
                        style: pw.TextStyle(font: font),
                      ),
                      if (invoiceWithDetails.invoice.reason != null)
                        pw.Text(
                          'Reason: ${invoiceWithDetails.invoice.reason}',
                          style: pw.TextStyle(font: font),
                        ),
                    ],
                  ),
                ),
              ],

              // Footer
              pw.Spacer(),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
