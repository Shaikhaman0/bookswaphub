import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/models/user.dart';

class ReportPdfGenerator {
  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _formatDateShort(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static Future<Uint8List> buildPdf({
    required String timeframe,
    required Map<String, int> stats,
    required List<Book> recentBooks,
    required List<User> recentUsers,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final totalUsers = stats['users'] ?? recentUsers.length;
    final availableBooks = stats['availableBooks'] ?? 0;
    final swapsPending = stats['swapsPending'] ?? 0;
    final swapsActive = stats['swapsActive'] ?? 0;
    final swapsCompleted = stats['swapsCompleted'] ?? 0;
    final totalSwaps = swapsPending + swapsActive + swapsCompleted;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('1E3A8A'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BookSwapHub',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Executive Administrative Report ($timeframe)',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${_formatDate(now)}',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Period: $timeframe Review',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Section: Executive Summary
            pw.Text(
              '1. Platform Metrics Overview',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('1E293B'),
              ),
            ),
            pw.SizedBox(height: 8),

            // Metrics Cards in Grid
            pw.Row(
              children: [
                _metricCard('Total Users', '$totalUsers', PdfColor.fromHex('2563EB')),
                pw.SizedBox(width: 10),
                _metricCard('Available Books', '$availableBooks', PdfColor.fromHex('059669')),
                pw.SizedBox(width: 10),
                _metricCard('Active Swaps', '$swapsActive', PdfColor.fromHex('D97706')),
                pw.SizedBox(width: 10),
                _metricCard('Completed Swaps', '$swapsCompleted', PdfColor.fromHex('7C3AED')),
              ],
            ),

            pw.SizedBox(height: 20),

            // Section: Detailed Metrics Table
            pw.Text(
              '2. Performance & Volume Breakdown',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('1E293B'),
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('CBD5E1'), width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
                  children: [
                    _tableCell('Metric Indicator', isHeader: true),
                    _tableCell('Scope / Definition', isHeader: true),
                    _tableCell('Total Count', isHeader: true),
                    _tableCell('Status Health', isHeader: true),
                  ],
                ),
                _tableDataRow('Registered Users', 'All verified accounts across platforms', '$totalUsers', 'Active'),
                _tableDataRow('Available Books', 'Books currently listed and ready for swap/sale', '$availableBooks', 'Healthy'),
                _tableDataRow('Pending Swap Requests', 'Awaiting owner review and acceptance', '$swapsPending', 'In Review'),
                _tableDataRow('Active Swaps', 'Accepted swaps currently underway', '$swapsActive', 'In Progress'),
                _tableDataRow('Completed Exchanges', 'Successfully finalized book exchanges', '$swapsCompleted', 'Successful'),
                _tableDataRow('Total Swap Requests', 'Cumulative lifetime platform swaps', '$totalSwaps', 'Tracked'),
              ],
            ),

            pw.SizedBox(height: 24),

            // Section: Recent Books
            pw.Text(
              '3. Recent Book Listings',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('1E293B'),
              ),
            ),
            pw.SizedBox(height: 8),

            if (recentBooks.isEmpty)
              pw.Text('No books listed in this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('CBD5E1'), width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
                    children: [
                      _tableCell('Title', isHeader: true),
                      _tableCell('Author', isHeader: true),
                      _tableCell('Category', isHeader: true),
                      _tableCell('Condition', isHeader: true),
                      _tableCell('Status', isHeader: true),
                      _tableCell('Date Listed', isHeader: true),
                    ],
                  ),
                  ...recentBooks.take(8).map((b) => pw.TableRow(
                    children: [
                      _tableCell(b.title),
                      _tableCell(b.author),
                      _tableCell(b.category.isEmpty ? 'General' : b.category),
                      _tableCell(b.condition),
                      _tableCell(b.status.toUpperCase()),
                      _tableCell(_formatDateShort(b.createdAt)),
                    ],
                  )),
                ],
              ),

            pw.SizedBox(height: 24),

            // Section: Recent Registered Users
            pw.Text(
              '4. Recent Platform Users',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('1E293B'),
              ),
            ),
            pw.SizedBox(height: 8),

            if (recentUsers.isEmpty)
              pw.Text('No user activity recorded in this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('CBD5E1'), width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
                    children: [
                      _tableCell('User Name', isHeader: true),
                      _tableCell('Location', isHeader: true),
                      _tableCell('Total Swaps', isHeader: true),
                      _tableCell('Account Status', isHeader: true),
                      _tableCell('Joined Date', isHeader: true),
                    ],
                  ),
                  ...recentUsers.take(8).map((u) => pw.TableRow(
                    children: [
                      _tableCell(u.name.isEmpty ? 'Reader' : u.name),
                      _tableCell(u.location.isEmpty ? 'Not specified' : u.location),
                      _tableCell('${u.totalSwaps} swaps'),
                      _tableCell(u.disabled ? 'Disabled' : 'Active'),
                      _tableCell(_formatDateShort(u.createdAt)),
                    ],
                  )),
                ],
              ),

            pw.SizedBox(height: 24),

            // Footer note
            pw.Divider(color: PdfColor.fromHex('E2E8F0')),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('BookSwapHub Admin Console - Confidential System Report', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.Text('Report Type: $timeframe Generated Automatically', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _metricCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('E2E8F0'), width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
          color: PdfColor.fromHex('F8FAFC'),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColor.fromHex('1E293B') : PdfColor.fromHex('334155'),
        ),
      ),
    );
  }

  static pw.TableRow _tableDataRow(String col1, String col2, String col3, String col4) {
    return pw.TableRow(
      children: [
        _tableCell(col1),
        _tableCell(col2),
        _tableCell(col3),
        _tableCell(col4),
      ],
    );
  }

  /// Opens native print / preview and save-as-PDF dialog.
  static Future<void> printReport({
    required String timeframe,
    required Map<String, int> stats,
    required List<Book> recentBooks,
    required List<User> recentUsers,
  }) async {
    final bytes = await buildPdf(
      timeframe: timeframe,
      stats: stats,
      recentBooks: recentBooks,
      recentUsers: recentUsers,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'BookSwapHub_${timeframe}_Report.pdf',
    );
  }

  /// Downloads / shares the PDF file.
  static Future<void> downloadReport({
    required String timeframe,
    required Map<String, int> stats,
    required List<Book> recentBooks,
    required List<User> recentUsers,
  }) async {
    final bytes = await buildPdf(
      timeframe: timeframe,
      stats: stats,
      recentBooks: recentBooks,
      recentUsers: recentUsers,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'BookSwapHub_${timeframe}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
