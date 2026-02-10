import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

class FinancialSummarySheet extends StatefulWidget {
  final String userName;
  final String userId;

  /// Report period (selected month)
  final DateTime periodMonth;

  /// Totals from Analytics DB
  final double totalIncome;
  final double totalExpenses;

  /// Breakdowns from Analytics DB
  final Map<String, double> incomeBySource;
  final Map<String, double> expenseByCategory;

  /// Optional: category-wise transaction counts (if you have it)
  final Map<String, int>? expenseTxnCountByCategory;

  const FinancialSummarySheet({
    super.key,
    required this.userName,
    required this.userId,
    required this.periodMonth,
    required this.totalIncome,
    required this.totalExpenses,
    required this.incomeBySource,
    required this.expenseByCategory,
    this.expenseTxnCountByCategory,
  });

  @override
  State<FinancialSummarySheet> createState() => _FinancialSummarySheetState();
}

class _FinancialSummarySheetState extends State<FinancialSummarySheet> {
  // ✅ Your premium blue
  static const Color kPremiumBlue = Color(0xFF0F12AF);
  static const PdfColor kPremiumBluePdf = PdfColor.fromInt(0xFF0F12AF);

  // ✅ Light theme colors for PDF tables/cards
  static final PdfColor kLightBluePdf = PdfColor.fromInt(0xFFE8EDFF);
  static final PdfColor kVeryLightPdf = PdfColor.fromInt(0xFFF6F7FB);
  static final PdfColor kBorderGreyPdf = PdfColor.fromInt(0xFFD7DAE3);

  late final DateTime generatedDateTime;

  @override
  void initState() {
    super.initState();
    generatedDateTime = DateTime.now();
  }

  double get _balance => widget.totalIncome - widget.totalExpenses;

  bool get _isNoData => widget.totalIncome == 0 && widget.totalExpenses == 0;

  // ===================== ✅ NEW: Dynamic Insight Logic =====================

  /// Income level classification (you can adjust thresholds if needed)
  String get _incomeLevelLabel {
    final inc = widget.totalIncome;

    if (inc <= 0) return "No Income Data";
    if (inc < 20000) return "Low Income";
    if (inc <= 30000) return "Moderate Income";
    return "High Income";
  }

  /// Spending behaviour based on expense/income ratio
  String get _spenderTypeLabel {
    if (_isNoData) return "No Data";

    final income = widget.totalIncome;
    final expense = widget.totalExpenses;

    if (income <= 0 && expense > 0) {
      return "High-Risk Spender";
    }
    if (income <= 0 && expense == 0) {
      return "No Data";
    }

    final ratio = expense / income; // safe because income > 0 here

    if (ratio <= 0.80) return "Saver";
    if (ratio <= 1.00) return "Balanced Spender";
    if (ratio <= 1.20) return "Impulsive Spender";
    return "High-Risk Spender";
  }

  /// Keep your old getter names for compatibility (UI/PDF already uses these)
  //String get _personalityLabel => _spenderTypeLabel;

  String get _statusLabel {
    if (_isNoData) return "No Data";
    if (_balance > 0) return "Surplus";
    if (_balance < 0) return "Deficit";
    return "Break-even";
  }

  /// One line message (dynamic)
  String get _personalityMessage {
    if (_isNoData) return "No report message for this month.";

    final income = widget.totalIncome;
    final expense = widget.totalExpenses;
    final net = _balance;

    if (income <= 0 && expense > 0) {
      return "You have expenses but no recorded income. Please review income entries.";
    }

    final ratio = (income <= 0) ? 0 : (expense / income);

    // Surplus / savings messages
    if (net > 0) {
      if (ratio <= 0.80) {
        return "Great control! You saved a good portion of your income this month.";
      }
      if (ratio <= 1.00) {
        return "Good balance. Try reducing small unnecessary expenses to increase savings.";
      }
      return "You still saved, but spending is high. Monitor non-essential expenses.";
    }

    // Break-even messages
    if (net == 0) {
      return "Your income and expenses are equal. Aim to save even a small amount next month.";
    }

    // Deficit messages
    if (ratio <= 1.20) {
      return "Your expenses exceeded your income. Try reducing unnecessary spending.";
    }
    return "Spending is far above income. Consider urgent budget adjustments and prioritizing essentials.";
  }

  /// Combined tagline for UI/PDF
  String get _overviewTagline {
    if (_isNoData) return "No Data";
    final incLevel = _incomeLevelLabel;
    final spender = _spenderTypeLabel;
    final status = _statusLabel;

    // show all three (nice for your app)
    return "$status  •  $spender  •  $incLevel";
  }

  // ---------- Currency ----------
  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00');
    return formatter.format(amount.abs());
  }

  // ---------- Build lists from maps ----------
  List<MapEntry<String, double>> get _incomeEntries {
    final list = widget.incomeBySource.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<MapEntry<String, double>> get _expenseEntries {
    final list = widget.expenseByCategory.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  int _getTxnCountForCategory(String category) {
    return widget.expenseTxnCountByCategory?[category] ?? 0;
  }

  // ---------- PDF (Download as Save-As dialog) ----------
  Future<void> _generatePDF() async {
    if (_isNoData) return;

    final pdf = pw.Document();

    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final formattedDate = dateFormat.format(generatedDateTime);
    final formattedTime = timeFormat.format(generatedDateTime);

    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/Intellects_Logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPDFHeader(
                date: formattedDate,
                time: formattedTime,
                logo: logoImage,
              ),
              pw.SizedBox(height: 14),
              _buildPDFUserInfo(),
              pw.SizedBox(height: 12),

              _buildPDFTopSummaryCards(),
              pw.SizedBox(height: 18),

              _buildPDFSectionTitle('INCOME SUMMARY'),
              pw.SizedBox(height: 10),
              _buildPDFIncomeTable(),
              pw.SizedBox(height: 16),

              _buildPDFSectionTitle('EXPENSE SUMMARY'),
              pw.SizedBox(height: 10),
              _buildPDFExpenseTable(),
              pw.SizedBox(height: 16),

              _buildPDFFinancialOverview(),
              pw.Spacer(),
              _buildPDFFooter(),
            ],
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();

    final String fileName =
        'Monthly_Summary_${DateFormat('yyyy-MM-dd_HH.mm').format(generatedDateTime)}.pdf';

    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );

    if (location == null) return;

    String savePath = location.path;
    if (!savePath.toLowerCase().endsWith('.pdf')) {
      savePath = '$savePath.pdf';
    }

    final XFile xfile = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: fileName,
    );

    // ✅ Save first
    await xfile.saveTo(savePath);

    if (!mounted) return;

    // ✅ 1) First confirm message
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report downloaded successfully'),
        duration: Duration(seconds: 2),
      ),
    );

    // ✅ 2) Then show the path after a short delay
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved Path:\n$savePath'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ---------------- PDF WIDGETS ----------------

  pw.Widget _buildPDFHeader({
    required String date,
    required String time,
    required pw.MemoryImage? logo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: kPremiumBluePdf, width: 2.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 26,
                    height: 26,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6),
                      ),
                      border: pw.Border.all(color: kBorderGreyPdf, width: 1),
                    ),
                    child: logo == null
                        ? pw.Center(
                            child: pw.Text(
                              'B',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: kPremiumBluePdf,
                              ),
                            ),
                          )
                        : pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Image(logo, fit: pw.BoxFit.contain),
                          ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'BudgetEase',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: kPremiumBluePdf,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'MONTHLY SUMMARY REPORT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: kPremiumBluePdf,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: kPremiumBluePdf, thickness: 1.4),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: $date at $time',
                style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
              ),
              pw.Text(
                'Period: ${DateFormat('MMMM yyyy').format(widget.periodMonth)}',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: kPremiumBluePdf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFUserInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: kVeryLightPdf,
        border: pw.Border.all(color: kBorderGreyPdf),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'User Name',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                widget.userName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'User ID',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                widget.userId,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFTopSummaryCards() {
    final sign = _balance >= 0 ? '+' : '-';

    pw.Widget card(String title, String value, {bool highlight = false}) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: highlight ? kLightBluePdf : PdfColors.white,
            border: pw.Border.all(color: kBorderGreyPdf),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 12.5,
                  fontWeight: pw.FontWeight.bold,
                  color: highlight ? kPremiumBluePdf : PdfColors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        card('Total Income', 'Rs. ${_formatCurrency(widget.totalIncome)}'),
        pw.SizedBox(width: 10),
        card('Total Expenses', 'Rs. ${_formatCurrency(widget.totalExpenses)}'),
        pw.SizedBox(width: 10),
        card(
          'Net Balance',
          '$sign Rs. ${_formatCurrency(_balance)}',
          highlight: true,
        ),
      ],
    );
  }

  pw.Widget _buildPDFSectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 6,
          height: 16,
          decoration: pw.BoxDecoration(
            color: kPremiumBluePdf,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
            color: kPremiumBluePdf,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFIncomeTable() {
    final rows = _incomeEntries;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: kBorderGreyPdf),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          verticalInside: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          top: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          bottom: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          left: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          right: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
        ),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: kLightBluePdf),
            children: [
              _pdfCell('Source', isHeader: true),
              _pdfCell(
                'Amount (Rs.)',
                isHeader: true,
                align: pw.TextAlign.right,
              ),
            ],
          ),
          ...rows.map(
            (e) => pw.TableRow(
              children: [
                _pdfCell(e.key),
                _pdfCell(_formatCurrency(e.value), align: pw.TextAlign.right),
              ],
            ),
          ),
          pw.TableRow(
            decoration: pw.BoxDecoration(color: kVeryLightPdf),
            children: [
              _pdfCell('TOTAL', isHeader: true, headerColor: kPremiumBluePdf),
              _pdfCell(
                _formatCurrency(widget.totalIncome),
                isHeader: true,
                headerColor: kPremiumBluePdf,
                align: pw.TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFExpenseTable() {
    final rows = _expenseEntries;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: kBorderGreyPdf),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          verticalInside: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          top: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          bottom: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          left: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
          right: pw.BorderSide(color: kBorderGreyPdf, width: 0.8),
        ),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: kLightBluePdf),
            children: [
              _pdfCell('Category', isHeader: true),
              _pdfCell('Transactions', isHeader: true),
              _pdfCell(
                'Amount (Rs.)',
                isHeader: true,
                align: pw.TextAlign.right,
              ),
            ],
          ),
          ...rows.map(
            (e) => pw.TableRow(
              children: [
                _pdfCell(e.key),
                _pdfCell(_getTxnCountForCategory(e.key).toString()),
                _pdfCell(_formatCurrency(e.value), align: pw.TextAlign.right),
              ],
            ),
          ),
          pw.TableRow(
            decoration: pw.BoxDecoration(color: kVeryLightPdf),
            children: [
              _pdfCell('TOTAL', isHeader: true, headerColor: kPremiumBluePdf),
              _pdfCell(''),
              _pdfCell(
                _formatCurrency(widget.totalExpenses),
                isHeader: true,
                headerColor: kPremiumBluePdf,
                align: pw.TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFFinancialOverview() {
    final sign = _balance >= 0 ? '+' : '-';

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: kPremiumBluePdf, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'FINANCIAL OVERVIEW',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: kPremiumBluePdf,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: kPremiumBluePdf, thickness: 1),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: kBorderGreyPdf, width: 0.8),
            children: [
              pw.TableRow(
                children: [
                  _pdfCell('Total Income'),
                  _pdfCell(
                    'Rs. ${_formatCurrency(widget.totalIncome)}',
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell('Total Expenses'),
                  _pdfCell(
                    'Rs. ${_formatCurrency(widget.totalExpenses)}',
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: kLightBluePdf),
                children: [
                  _pdfCell(
                    'Net Balance',
                    isHeader: true,
                    headerColor: kPremiumBluePdf,
                  ),
                  _pdfCell(
                    '$sign Rs. ${_formatCurrency(_balance)}',
                    isHeader: true,
                    headerColor: kPremiumBluePdf,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // ✅ Dynamic tagline (Status + Spender + Income Level)
          pw.Text(
            'Overview: $_overviewTagline',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: kPremiumBluePdf,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _personalityMessage,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? headerColor,
  }) {
    final PdfColor useColor = headerColor ?? PdfColors.black;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 10.2 : 9.8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? useColor : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildPDFFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: kBorderGreyPdf, thickness: 1),
          pw.SizedBox(height: 6),
          pw.Text(
            'This is a computer-generated report from BudgetEase. No signature required.',
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by BudgetEase',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page 1 of 1',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final headerDate = dateFormat.format(generatedDateTime);
    final headerTime = timeFormat.format(generatedDateTime);
    final periodText = DateFormat('MMMM yyyy').format(widget.periodMonth);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kPremiumBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Monthly Summary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(headerDate, headerTime, periodText),

            if (_isNoData) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No data available for this month.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _topSummaryCardsUI(),
              ),

              const SizedBox(height: 22),

              // Income Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      'Income Summary',
                      Icons.account_balance_wallet,
                    ),
                    const SizedBox(height: 12),
                    _incomeCards(),
                    const SizedBox(height: 10),
                    _totalCard('Total Income', widget.totalIncome),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Expense Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Expense Summary', Icons.receipt_long),
                    const SizedBox(height: 12),
                    _expenseCards(),
                    const SizedBox(height: 10),
                    _totalCard('Total Expenses', widget.totalExpenses),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Financial Overview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _financialOverview(),
              ),
            ],

            const SizedBox(height: 24),

            // Download Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Opacity(
                opacity: _isNoData ? 0.4 : 1.0,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isNoData ? null : _generatePDF,
                    icon: const Icon(Icons.download, size: 22),
                    label: const Text(
                      'Download PDF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPremiumBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(String date, String time, String periodText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/Intellects_Logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance_wallet,
                        color: kPremiumBlue,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'BudgetEase',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kPremiumBlue,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              Text(
                'MONTHLY SUMMARY REPORT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: kPremiumBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade300, thickness: 1.2),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _miniInfo('Date', date)),
              Expanded(child: _miniInfo('Time', time)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: kPremiumBlue, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, size: 26, color: kPremiumBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Name',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'User ID: ${widget.userId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Period: $periodText',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kPremiumBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  // ✅ 3 cards row (UI arrows ok)
  Widget _topSummaryCardsUI() {
    final isPositive = _balance >= 0;

    Widget card({
      required String title,
      required String value,
      required Color valueColor,
      IconData? icon,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          title: 'Total Income',
          value: 'Rs. ${_formatCurrency(widget.totalIncome)}',
          valueColor: kPremiumBlue,
          icon: Icons.trending_up,
        ),
        const SizedBox(width: 10),
        card(
          title: 'Total Expenses',
          value: 'Rs. ${_formatCurrency(widget.totalExpenses)}',
          valueColor: Colors.grey.shade800,
          icon: Icons.trending_down,
        ),
        const SizedBox(width: 10),
        card(
          title: 'Net Balance',
          value: '${isPositive ? '▲' : '▼'} Rs. ${_formatCurrency(_balance)}',
          valueColor: isPositive ? Colors.green.shade700 : Colors.red.shade700,
          icon: Icons.account_balance,
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPremiumBlue, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: kPremiumBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomeCards() {
    final items = _incomeEntries;
    if (items.isEmpty) {
      return Text(
        'No income records.',
        style: TextStyle(color: Colors.grey.shade700),
      );
    }
    return Column(
      children: items
          .map((e) => _rowCard(title: e.key, subtitle: null, amount: e.value))
          .toList(),
    );
  }

  Widget _expenseCards() {
    final items = _expenseEntries;
    if (items.isEmpty) {
      return Text(
        'No expense records.',
        style: TextStyle(color: Colors.grey.shade700),
      );
    }
    return Column(
      children: items.map((e) {
        final txn = _getTxnCountForCategory(e.key);
        final subtitle = txn > 0 ? '$txn transactions' : null;
        return _rowCard(title: e.key, subtitle: subtitle, amount: e.value);
      }).toList(),
    );
  }

  Widget _rowCard({
    required String title,
    required String? subtitle,
    required double amount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'Rs. ${_formatCurrency(amount)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _totalCard(String label, double amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: kPremiumBlue, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: kPremiumBlue,
            ),
          ),
          Text(
            'Rs. ${_formatCurrency(amount)}',
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: Financial Overview (dynamic)
  Widget _financialOverview() {
    final isPositive = _balance >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: kPremiumBlue, width: 2),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINANCIAL OVERVIEW',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: kPremiumBlue,
            ),
          ),
          const SizedBox(height: 6),
          Divider(color: kPremiumBlue, thickness: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Balance',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Text(
                    isPositive ? '▲' : '▼',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kPremiumBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs. ${_formatCurrency(_balance)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ✅ Dynamic tagline here
          Text(
            _overviewTagline,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kPremiumBlue,
            ),
          ),

          const SizedBox(height: 6),
          Text(
            _personalityMessage,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
