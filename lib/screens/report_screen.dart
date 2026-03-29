import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Url, Blob;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

// ─── Timeline Filter ──────────────────────────────────────────────────────────
enum ReportTimeline {
  all('All Time'),
  today('Today'),
  week('This Week'),
  month('This Month'),
  quarter('This Quarter'),
  halfYear('Last 6 Months'),
  year('This Year');

  final String label;
  const ReportTimeline(this.label);

  DateTime? get fromDate {
    final now = DateTime.now();
    switch (this) {
      case ReportTimeline.today:
        return DateTime(now.year, now.month, now.day);
      case ReportTimeline.week:
        return now.subtract(Duration(days: now.weekday - 1));
      case ReportTimeline.month:
        return DateTime(now.year, now.month, 1);
      case ReportTimeline.quarter:
        final q = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, q, 1);
      case ReportTimeline.halfYear:
        return now.subtract(const Duration(days: 180));
      case ReportTimeline.year:
        return DateTime(now.year, 1, 1);
      case ReportTimeline.all:
        return null;
    }
  }

  String get dateRangeLabel {
    final now = DateTime.now();
    final from = fromDate;
    if (from == null) return 'All records';
    final d = from.day.toString().padLeft(2, '0');
    final m = from.month.toString().padLeft(2, '0');
    final nd = now.day.toString().padLeft(2, '0');
    final nm = now.month.toString().padLeft(2, '0');
    return '$d/$m/${from.year} – $nd/$nm/${now.year}';
  }
}

// ─── Shared Revenue Formatter (used by all report screens) ───────────────────
String _fmtRevReport(double v) {
  if (v >= 10000000) return '\u20b9${(v / 10000000).toStringAsFixed(2)}Cr';
  if (v >= 100000)   return '\u20b9${(v / 100000).toStringAsFixed(2)}L';
  return '\u20b9${v.toStringAsFixed(0)}';
}

// ─── Shared PDF Builder ───────────────────────────────────────────────────────
Future<Uint8List> buildReportPdf({
  required RealEstateProject project,
  required List<Lead> leads,
  required List<AppUser> salesTeam,
  required ReportTimeline timeline,
  required List<LeadActivity> activities,
  bool isMasterAdmin = false,
}) async {
  final pdf = pw.Document();
  final now = DateTime.now();
  final dateStr =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  final timeStr =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  final closedLeads = leads.where((l) => l.status == LeadStatus.closed).length;
  final siteVisits =
      leads.where((l) => l.status == LeadStatus.siteVisit).length;
  final newLeads = leads.where((l) => l.status == LeadStatus.newLead).length;
  final convRate =
      leads.isEmpty ? 0.0 : (closedLeads / leads.length) * 100;

  // ── Helpers ──
  pw.Widget _pdfSectionTitle(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(children: [
      pw.Container(
        width: 3,
        height: 14,
        color: PdfColor.fromHex('#C9B8FF'),
      ),
      pw.SizedBox(width: 8),
      pw.Text(t,
          style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1A1A2E'))),
    ]),
  );

  pw.Widget _infoRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#B0B0C0')))),
        pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1A1A2E')))),
      ],
    ),
  );

  pw.Widget _kpiBox(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor(
                color.red, color.green, color.blue, 0.15),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
                color: PdfColor(
                    color.red, color.green, color.blue, 0.4)),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1A1A2E'))),
              pw.SizedBox(height: 2),
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromHex('#B0B0C0'))),
            ],
          ),
        ),
      );

  // Status colors for PDF
  PdfColor _statusColor(LeadStatus s) {
    switch (s) {
      case LeadStatus.newLead:
        return PdfColor.fromHex('#C9B8FF');
      case LeadStatus.contacted:
        return PdfColor.fromHex('#B8EEFF');
      case LeadStatus.siteVisit:
        return PdfColor.fromHex('#FFD4A8');
      case LeadStatus.negotiation:
        return PdfColor.fromHex('#FFB8D9');
      case LeadStatus.closed:
        return PdfColor.fromHex('#B8EEFF');
      case LeadStatus.lost:
        return PdfColor.fromHex('#FFB347');
    }
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(children: [
        // ── RLA Header Banner ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#C9B8FF'),
                PdfColor.fromHex('#FFB8D9'),
              ],
            ),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(children: [
            pw.Container(
              width: 40,
              height: 40,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Center(
                child: pw.Text('R',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#C9B8FF'))),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RLA CRM',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 1.0)),
                    pw.Text('Real Estate · Leads · Growth',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white)),
                  ]),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(
                isMasterAdmin ? 'MASTER ADMIN REPORT' : 'PROJECT REPORT',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1.2),
              ),
              pw.Text('$dateStr  $timeStr',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColors.white)),
              pw.Text(timeline.label,
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColors.white)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 16),
      ]),
      footer: (ctx) => pw.Column(children: [
        pw.Divider(color: PdfColor.fromHex('#EAEAF0')),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Private & Confidential — RLA CRM',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColor.fromHex('#B0B0C0'))),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColor.fromHex('#B0B0C0'))),
            pw.Text('Generated: $dateStr',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColor.fromHex('#B0B0C0'))),
          ],
        ),
      ]),
      build: (ctx) => [
        // ── Project Information ──
        _pdfSectionTitle('Project Information'),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8F8FA'),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromHex('#EAEAF0')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoRow('Project Name', project.name),
              _infoRow('Location', project.location.isNotEmpty ? project.location : '—'),
              if (project.developerName.isNotEmpty)
                _infoRow('Developer', project.developerName),
              if (project.reraNumber != null &&
                  project.reraNumber!.isNotEmpty)
                _infoRow('RERA No.', project.reraNumber!),
              _infoRow('Property Type', project.propertyType.label),
              _infoRow('Status', project.status.label),
              if (project.priceDisplay.isNotEmpty)
                _infoRow('Price Range', project.priceDisplay),
              _infoRow('Report Period', timeline.dateRangeLabel),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // ── Performance Summary ──
        _pdfSectionTitle('Performance Summary'),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _kpiBox('Total Leads', '${leads.length}',
              PdfColor.fromHex('#C9B8FF')),
          pw.SizedBox(width: 8),
          _kpiBox('New', '$newLeads', PdfColor.fromHex('#B8EEFF')),
          pw.SizedBox(width: 8),
          _kpiBox('Site Visits', '$siteVisits',
              PdfColor.fromHex('#FFD4A8')),
          pw.SizedBox(width: 8),
          _kpiBox('Closed', '$closedLeads',
              PdfColor.fromHex('#B8EEFF')),
          pw.SizedBox(width: 8),
          _kpiBox('Conv.%',
              '${convRate.toStringAsFixed(1)}%',
              PdfColor.fromHex('#FFB8D9')),
        ]),
        pw.SizedBox(height: 18),

        // ── Lead Status Breakdown ──
        _pdfSectionTitle('Lead Status Breakdown'),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8F8FA'),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromHex('#EAEAF0')),
          ),
          child: pw.Column(
            children: LeadStatus.values.map((s) {
              final cnt = leads.where((l) => l.status == s).length;
              final frac =
                  leads.isEmpty ? 0.0 : (cnt / leads.length).clamp(0.0, 1.0);
              final statusColor = _statusColor(s);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(children: [
                  pw.Container(
                      width: 8,
                      height: 8,
                      decoration: pw.BoxDecoration(
                          color: statusColor,
                          borderRadius: pw.BorderRadius.circular(4))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 100,
                    child: pw.Text(s.label,
                        style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('#6B6B80'))),
                  ),
                  pw.Expanded(
                    child: pw.ClipRRect(
                      verticalRadius: 4,
                      horizontalRadius: 4,
                      child: pw.Stack(children: [
                        pw.Container(
                          height: 8,
                          color: PdfColor.fromHex('#EAEAF0'),
                        ),
                        pw.Row(children: [
                          pw.Flexible(
                            flex: (frac * 100).round().clamp(0, 100),
                            child: pw.Container(
                              height: 8,
                              color: statusColor,
                            ),
                          ),
                          if (frac < 1.0)
                            pw.Flexible(
                              flex: ((1 - frac) * 100).round().clamp(0, 100),
                              child: pw.Container(height: 8),
                            ),
                        ]),
                      ]),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text('$cnt',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1A1A2E'))),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
        pw.SizedBox(height: 18),

        // ── Sales Team Performance ──
        _pdfSectionTitle('Sales Team Performance'),
        pw.SizedBox(height: 8),
        if (salesTeam.isEmpty)
          pw.Text('No sales team assigned.',
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromHex('#B0B0C0')))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Name', 'Email', 'Leads', 'Closed', 'Visits', 'Conv.%'],
            data: salesTeam.map((u) {
              final uLeads = leads.where((l) => l.assignedToId == u.id).length;
              final uClosed = leads
                  .where((l) =>
                      l.assignedToId == u.id && l.status == LeadStatus.closed)
                  .length;
              final uVisits = leads
                  .where((l) =>
                      l.assignedToId == u.id &&
                      l.status == LeadStatus.siteVisit)
                  .length;
              final uConv =
                  uLeads == 0 ? '0.0%' : '${(uClosed / uLeads * 100).toStringAsFixed(1)}%';
              return [u.name, u.email, '$uLeads', '$uClosed', '$uVisits', uConv];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#C9B8FF'),
            ),
            cellStyle: pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#EAEAF0'), width: 0.5),
              ),
            ),
            oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8F8FA')),
          ),
        pw.SizedBox(height: 18),

        // ── All Leads ──
        _pdfSectionTitle('All Leads (${leads.length})'),
        pw.SizedBox(height: 8),
        if (leads.isEmpty)
          pw.Text('No leads in this period.',
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromHex('#B0B0C0')))
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Name',
              'Phone',
              'Source',
              'Status',
              'Assigned To',
              'Date'
            ],
            data: leads.map((lead) {
              final d =
                  '${lead.createdAt.day.toString().padLeft(2, '0')}/${lead.createdAt.month.toString().padLeft(2, '0')}/${lead.createdAt.year}';
              return [
                lead.name,
                lead.phone,
                lead.source.label,
                lead.status.label,
                lead.assignedToName,
                d,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#C9B8FF'),
            ),
            cellStyle: pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.center,
            },
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#EAEAF0'), width: 0.5),
              ),
            ),
            oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8F8FA')),
          ),
        pw.SizedBox(height: 18),

        // ── Activity Log ──
        _pdfSectionTitle(
            'Sales Activity Log (${activities.length})'),
        pw.SizedBox(height: 8),
        if (activities.isEmpty)
          pw.Text('No activity recorded.',
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromHex('#B0B0C0')))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Action', 'Lead', 'By', 'Note', 'Date/Time'],
            data: activities.take(80).map((act) {
              String leadName = '';
              try {
                leadName = leads.firstWhere((l) => l.id == act.leadId).name;
              } catch (_) {}
              final dt =
                  '${act.timestamp.day.toString().padLeft(2, '0')}/${act.timestamp.month.toString().padLeft(2, '0')} ${act.timestamp.hour.toString().padLeft(2, '0')}:${act.timestamp.minute.toString().padLeft(2, '0')}';
              return [
                act.action,
                leadName,
                act.userName,
                act.note ?? '',
                dt,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#C9B8FF'),
            ),
            cellStyle: pw.TextStyle(fontSize: 8),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#EAEAF0'), width: 0.5),
              ),
            ),
            oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8F8FA')),
          ),
        pw.SizedBox(height: 24),

        // ── Confidentiality Footer ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8F8FA'),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromHex('#EAEAF0')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('⚠  PRIVATE & CONFIDENTIAL',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#6B6B80'),
                      letterSpacing: 0.8)),
              pw.SizedBox(height: 4),
              pw.Text(
                  'This report is intended solely for authorised personnel of RLA CRM.',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColor.fromHex('#B0B0C0')),
                  textAlign: pw.TextAlign.center),
              pw.Text(
                  'Unauthorised use, disclosure or distribution is strictly prohibited.',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColor.fromHex('#B0B0C0')),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('Generated by RLA CRM  ·  $dateStr  $timeStr',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColor.fromHex('#B0B0C0')),
                  textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

// ─── Report Preview & Download Sheet (shared by both Admin types) ─────────────
class ReportPreviewSheet extends StatefulWidget {
  final RealEstateProject project;
  final List<Lead> leads;
  final List<AppUser> salesTeam;
  final ReportTimeline timeline;
  final List<LeadActivity> activities;
  final bool isMasterAdmin;

  const ReportPreviewSheet({
    super.key,
    required this.project,
    required this.leads,
    required this.salesTeam,
    required this.timeline,
    required this.activities,
    this.isMasterAdmin = false,
  });

  @override
  State<ReportPreviewSheet> createState() => _ReportPreviewSheetState();
}

class _ReportPreviewSheetState extends State<ReportPreviewSheet> {
  bool _generating = false;

  Future<void> _downloadPdf() async {
    setState(() => _generating = true);
    try {
      final bytes = await buildReportPdf(
        project: widget.project,
        leads: widget.leads,
        salesTeam: widget.salesTeam,
        timeline: widget.timeline,
        activities: widget.activities,
        isMasterAdmin: widget.isMasterAdmin,
      );
      final now = DateTime.now();
      final fname =
          'RLA_Report_${widget.project.name.replaceAll(' ', '_')}_${now.day}-${now.month}-${now.year}.pdf';

      if (kIsWeb) {
        // ── Web: use dart:html blob anchor download ──────────────────────
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        (html.AnchorElement(href: url)
              ..setAttribute('download', fname)
              ..click())
            .remove();
        html.Url.revokeObjectUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF downloaded: $fname'),
              backgroundColor: const Color(0xFF7FD9F0),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // ── Mobile/Desktop: use the printing package share sheet ──────────
        await Printing.sharePdf(bytes: bytes, filename: fname);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final leads = widget.leads;
    final salesTeam = widget.salesTeam;
    final activities = widget.activities;

    final closedLeadsList = leads.where((l) => l.status == LeadStatus.closed).toList();
    final closedLeads = closedLeadsList.length;
    final siteVisits =
        leads.where((l) => l.status == LeadStatus.siteVisit).length;
    final newLeads =
        leads.where((l) => l.status == LeadStatus.newLead).length;
    final convRate =
        leads.isEmpty ? 0.0 : (closedLeads / leads.length) * 100;

    // Revenue calculations
    final totalRevenue = closedLeadsList
        .where((l) => l.closedValue != null)
        .fold<double>(0, (sum, l) => sum + l.closedValue!);
    final saleRevenue = closedLeadsList
        .where((l) => l.closedValue != null && l.leadType == LeadType.sale)
        .fold<double>(0, (sum, l) => sum + l.closedValue!);
    final leaseRevenue = closedLeadsList
        .where((l) => l.closedValue != null && l.leadType == LeadType.lease)
        .fold<double>(0, (sum, l) => sum + l.closedValue!);

    // Star performers: sales team sorted by revenue then by closed count
    final teamPerformance = salesTeam.map((u) {
      final uLeads = leads.where((l) => l.assignedToId == u.id).length;
      final uClosed = leads.where((l) => l.assignedToId == u.id && l.status == LeadStatus.closed).length;
      final uRevenue = leads
          .where((l) => l.assignedToId == u.id && l.status == LeadStatus.closed && l.closedValue != null)
          .fold<double>(0, (sum, l) => sum + l.closedValue!);
      final uVisits = leads.where((l) => l.assignedToId == u.id && l.status == LeadStatus.siteVisit).length;
      return {'user': u, 'leads': uLeads, 'closed': uClosed, 'revenue': uRevenue, 'visits': uVisits};
    }).toList()
      ..sort((a, b) {
        final revCmp = (b['revenue'] as double).compareTo(a['revenue'] as double);
        if (revCmp != 0) return revCmp;
        return (b['closed'] as int).compareTo(a['closed'] as int);
      });

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(children: [
              Text('Report Preview',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(widget.timeline.label,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lavender)),
              ),
              const Spacer(),
              // ── Download PDF button ──
              GestureDetector(
                onTap: _generating ? null : _downloadPdf,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: _generating ? null : AppColors.gradientCTA,
                    color: _generating ? AppColors.border : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_generating)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.textMuted))
                    else
                      const Icon(Icons.download_rounded,
                          size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _generating ? 'Generating…' : 'Download PDF',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              _generating ? AppColors.textMuted : Colors.white),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 20)),
            ]),
          ),
          const Divider(height: 1),

          // ── Scrollable report body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // RLA Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(11)),
                          child: Center(
                              child: Text('R',
                                  style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('RLA CRM',
                                    style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1.0)),
                                Text('Real Estate · Leads · Growth',
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.white
                                            .withValues(alpha: 0.8))),
                              ]),
                        ),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.isMasterAdmin
                                    ? 'MASTER ADMIN REPORT'
                                    : 'PROJECT REPORT',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 1.2),
                              ),
                              Text('$dateStr  $timeStr',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color:
                                          Colors.white.withValues(alpha: 0.7))),
                              Text(widget.timeline.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color:
                                          Colors.white.withValues(alpha: 0.7))),
                            ]),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Project Info
                    _sectionTitle('Project Information'),
                    const SizedBox(height: 10),
                    _infoCard([
                      _infoRow('Project Name', project.name),
                      _infoRow('Location',
                          project.location.isNotEmpty ? project.location : '—'),
                      if (project.developerName.isNotEmpty)
                        _infoRow('Developer', project.developerName),
                      if (project.reraNumber != null &&
                          project.reraNumber!.isNotEmpty)
                        _infoRow('RERA No.', project.reraNumber!),
                      _infoRow('Property Type', project.propertyType.label),
                      _infoRow('Status', project.status.label),
                      if (project.priceDisplay.isNotEmpty)
                        _infoRow('Price Range', project.priceDisplay),
                      _infoRow('Report Period', widget.timeline.dateRangeLabel),
                    ]),
                    const SizedBox(height: 16),

                    // Performance KPIs
                    _sectionTitle('Performance Summary'),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (ctx, c) => GridView.count(
                        crossAxisCount: c.maxWidth > 400 ? 5 : 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.5,
                        children: [
                          _kpiTile('Total', '${leads.length}',
                              AppColors.gradientPrimary),
                          _kpiTile('New', '$newLeads',
                              AppColors.gradientTertiary),
                          _kpiTile('Visits', '$siteVisits',
                              LinearGradient(colors: [
                                AppColors.peach,
                                AppColors.orange
                              ])),
                          _kpiTile('Closed', '$closedLeads',
                              AppColors.gradientSuccess),
                          _kpiTile('Conv.%',
                              '${convRate.toStringAsFixed(1)}%',
                              AppColors.gradientCTA),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lead Status Breakdown
                    _sectionTitle('Lead Status Breakdown'),
                    const SizedBox(height: 10),
                    _infoCard(
                      LeadStatus.values.map((s) {
                        final cnt =
                            leads.where((l) => l.status == s).length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: s.color,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: Text(s.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ),
                            Expanded(
                              child: Stack(children: [
                                Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: AppColors.border,
                                        borderRadius:
                                            BorderRadius.circular(4))),
                                FractionallySizedBox(
                                  widthFactor: leads.isEmpty
                                      ? 0.0
                                      : (cnt / leads.length)
                                          .clamp(0.0, 1.0),
                                  child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: s.color,
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 28,
                              child: Text('$cnt',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                  textAlign: TextAlign.right),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // ── Closed Revenue Section ──────────────────────
                    if (totalRevenue > 0) ...[
                      _sectionTitle('Closed Deal Revenue'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF7C6FFF).withValues(alpha: 0.12),
                              const Color(0xFFFF9F7C).withValues(alpha: 0.07),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7C6FFF).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradientPrimary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.currency_rupee_rounded, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Closed Revenue', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                      Text(_fmtRevReport(totalRevenue), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.sky.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text('$closedLeads deals', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.cyan)),
                                ),
                              ],
                            ),
                            if (saleRevenue > 0 || leaseRevenue > 0) ...[
                              const SizedBox(height: 12),
                              Container(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (saleRevenue > 0)
                                    Expanded(child: _revChip('Sale Revenue', _fmtRevReport(saleRevenue), AppColors.lavender, Icons.home_outlined)),
                                  if (saleRevenue > 0 && leaseRevenue > 0) const SizedBox(width: 10),
                                  if (leaseRevenue > 0)
                                    Expanded(child: _revChip('Annual Lease', _fmtRevReport(leaseRevenue), AppColors.peach, Icons.vpn_key_outlined)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Star Performers ────────────────────────────
                    if (teamPerformance.isNotEmpty && teamPerformance.any((m) => (m['closed'] as int) > 0)) ...[
                      _sectionTitle('⭐ Star Performers'),
                      const SizedBox(height: 10),
                      ...teamPerformance.asMap().entries.where((e) => (e.value['closed'] as int) > 0).map((entry) {
                        final rank = entry.key + 1;
                        final m = entry.value;
                        final u = m['user'] as AppUser;
                        final uLeads = m['leads'] as int;
                        final uClosed = m['closed'] as int;
                        final uRevenue = m['revenue'] as double;
                        final uVisits = m['visits'] as int;
                        final uConv = uLeads == 0 ? '0%' : '${(uClosed / uLeads * 100).toStringAsFixed(0)}%';
                        final isTopPerformer = rank == 1;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isTopPerformer
                                ? const Color(0xFFFFF8E6)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isTopPerformer
                                  ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Rank badge
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: isTopPerformer
                                      ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                                      : rank == 2
                                          ? const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFF909090)])
                                          : rank == 3
                                              ? const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFF8B4513)])
                                              : AppColors.gradientTertiary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
                                    style: GoogleFonts.inter(fontSize: rank <= 3 ? 13 : 10, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              AvatarWidget(
                                initials: u.initials,
                                size: 32,
                                gradient: isTopPerformer
                                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                                    : AppColors.gradientTertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(u.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                        if (isTopPerformer)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                                            ),
                                            child: Text('Top Performer', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFFB8860B))),
                                          ),
                                      ],
                                    ),
                                    Text('$uLeads leads · $uClosed closed · $uVisits visits · $uConv conv.',
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                    if (uRevenue > 0)
                                      Text(_fmtRevReport(uRevenue), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF7C6FFF))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── Sales Team Performance (all members) ───────
                    _sectionTitle('Sales Team Performance'),
                    const SizedBox(height: 10),
                    if (teamPerformance.isEmpty)
                      Text('No sales team assigned.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
                    else
                      ...teamPerformance.map((m) {
                        final u = m['user'] as AppUser;
                        final uLeads = m['leads'] as int;
                        final uClosed = m['closed'] as int;
                        final uRevenue = m['revenue'] as double;
                        final uVisits = m['visits'] as int;
                        final uConv = uLeads == 0 ? '0.0%' : '${(uClosed / uLeads * 100).toStringAsFixed(1)}%';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            AvatarWidget(initials: u.initials, size: 32, gradient: AppColors.gradientTertiary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Text(u.email, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                  if (uRevenue > 0)
                                    Text(_fmtRevReport(uRevenue), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF7C6FFF))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$uLeads leads · $uClosed closed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                Text('$uVisits visits · $uConv', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                          ]),
                        );
                      }),
                    const SizedBox(height: 16),

                    // All Leads
                    _sectionTitle('All Leads (${leads.length})'),
                    const SizedBox(height: 10),
                    if (leads.isEmpty)
                      Text('No leads in this period.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted))
                    else
                      ...leads.map((lead) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AppColors.border)),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(lead.name,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary)),
                                      Text(
                                          '${lead.phone}${lead.email.isNotEmpty ? "  ·  ${lead.email}" : ""}',
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.textMuted)),
                                      Text(
                                          'Assigned: ${lead.assignedToName}  ·  ${_fmtDate(lead.createdAt)}',
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.textMuted)),
                                      Text('Source: ${lead.source.label}',
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.textMuted)),
                                    ]),
                              ),
                              StatusPill(
                                  label: lead.status.label,
                                  color: lead.status.color,
                                  isSmall: true),
                            ]),
                          )),
                    const SizedBox(height: 16),

                    // Activity Log
                    _sectionTitle(
                        'Sales Activity Log (${activities.length})'),
                    const SizedBox(height: 10),
                    if (activities.isEmpty)
                      Text('No activity recorded.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted))
                    else
                      Container(
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border)),
                        child: Column(
                          children: activities
                              .take(100)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            final idx = entry.key;
                            final act = entry.value;
                            String leadName = '';
                            try {
                              leadName = leads
                                  .firstWhere((l) => l.id == act.leadId)
                                  .name;
                            } catch (_) {}
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: idx == 0
                                          ? Colors.transparent
                                          : AppColors.border),
                                ),
                              ),
                              child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: 6,
                                        height: 6,
                                        margin:
                                            const EdgeInsets.only(top: 5),
                                        decoration: BoxDecoration(
                                            color: AppColors.lavender,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(act.action,
                                                style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: AppColors
                                                        .textPrimary)),
                                            if (leadName.isNotEmpty)
                                              Text('Lead: $leadName',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textSecondary)),
                                            Text('By: ${act.userName}',
                                                style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    color:
                                                        AppColors.textMuted)),
                                            if (act.note != null &&
                                                act.note!.isNotEmpty)
                                              Text('Note: ${act.note}',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textMuted,
                                                      fontStyle:
                                                          FontStyle.italic)),
                                          ]),
                                    ),
                                    Text(_fmtDateTime(act.timestamp),
                                        style: GoogleFonts.inter(
                                            fontSize: 9,
                                            color: AppColors.textMuted)),
                                  ]),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // P&C Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border)),
                      child: Column(children: [
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_outline_rounded,
                                  size: 12,
                                  color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text('Private & Confidential',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                      letterSpacing: 0.5)),
                              const SizedBox(width: 6),
                              const Icon(Icons.lock_outline_rounded,
                                  size: 12,
                                  color: AppColors.textMuted),
                            ]),
                        const SizedBox(height: 4),
                        Text(
                            'This report is intended solely for authorised personnel of RLA CRM.',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.7)),
                            textAlign: TextAlign.center),
                        Text(
                            'Unauthorised use, disclosure or distribution is strictly prohibited.',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.7)),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text('Generated by RLA CRM  ·  $dateStr  $timeStr',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.5))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──
  Widget _sectionTitle(String title) => Row(children: [
        Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ]);

  Widget _infoCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );

  Widget _infoRow(String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted))),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary))),
        ]),
      );

  Widget _kpiTile(String label, String value, LinearGradient grad) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              grad.colors.first.withValues(alpha: 0.12),
              grad.colors.last.withValues(alpha: 0.07),
            ]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: grad.colors.first.withValues(alpha: 0.25))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9, color: AppColors.textSecondary)),
          ],
        ),
      );

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  String _fmtDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';


  Widget _revChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
            Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        )),
      ]),
    );
  }
}

// ─── Admin Report Screen (for project admins) ─────────────────────────────────
class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  String? _selectedProjectId;
  ReportTimeline _timeline = ReportTimeline.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedProjectId == null) {
      final projects = context.read<AppState>().companyProjects;
      if (projects.length == 1) {
        _selectedProjectId = projects.first.id;
      }
    }
  }

  List<Lead> _filterLeads(List<Lead> all) {
    final from = _timeline.fromDate;
    if (from == null) return all;
    return all.where((l) => l.createdAt.isAfter(from)).toList();
  }

  void _openReportSheet(BuildContext context, AppState state, RealEstateProject project) {
    final allLeads = state.leads.where((l) => l.projectId == project.id).toList();
    final leads = _filterLeads(allLeads);
    final salesTeam = state.users
        .where((u) => project.assignedSalesIds.contains(u.id))
        .toList();
    final activities = <LeadActivity>[];
    for (final l in leads) {
      activities.addAll(l.activities);
    }
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportPreviewSheet(
        project: project,
        leads: leads,
        salesTeam: salesTeam,
        timeline: _timeline,
        activities: activities,
        isMasterAdmin: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final projects = state.companyProjects;
    final selectedProject = _selectedProjectId != null
        ? projects.firstWhere((p) => p.id == _selectedProjectId,
            orElse: () => projects.first)
        : null;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reports',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text('Generate & download project reports as PDF',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                    ]),
              ),
              if (selectedProject != null)
                GradientButton(
                  label: 'Generate Report',
                  icon: Icons.picture_as_pdf_rounded,
                  height: 38,
                  onTap: () =>
                      _openReportSheet(context, state, selectedProject),
                  gradient: AppColors.gradientCTA,
                )
              else
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        size: 14,
                        color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text('Generate Report',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted
                                .withValues(alpha: 0.5))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Filters ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project selector
                  Text('Select Project',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _selectedProjectId == null
                              ? AppColors.border
                              : AppColors.lavender,
                          width: _selectedProjectId == null ? 1 : 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedProjectId,
                        hint: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('— Select a project —',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted)),
                        ),
                        isExpanded: true,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        borderRadius: BorderRadius.circular(14),
                        items: projects.map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Row(children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                        gradient: AppColors.gradientPrimary,
                                        borderRadius:
                                            BorderRadius.circular(7)),
                                    child: Center(
                                        child: Text(
                                            p.name.isNotEmpty
                                                ? p.name[0].toUpperCase()
                                                : 'P',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(p.name,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.textPrimary),
                                          overflow:
                                              TextOverflow.ellipsis)),
                                ]),
                              ),
                            )).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedProjectId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Timeline filter
                  Text('Timeline',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ReportTimeline.values.map((t) {
                        final sel = _timeline == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _timeline = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: sel
                                    ? AppColors.gradientPrimary
                                    : null,
                                color: sel ? null : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel
                                        ? Colors.transparent
                                        : AppColors.border),
                              ),
                              child: Text(t.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: sel
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
          ),
          const SizedBox(height: 20),

          // ── Preview / Empty state ──
          Expanded(
            child: _selectedProjectId == null
                ? Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded,
                              size: 56,
                              color:
                                  AppColors.textMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 14),
                          Text('Select a project above',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          Text(
                              'to preview report and download as PDF',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.7))),
                        ]))
                : _buildProjectPreview(context, state, selectedProject!),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectPreview(
      BuildContext context, AppState state, RealEstateProject project) {
    final allLeads =
        state.leads.where((l) => l.projectId == project.id).toList();
    final leads = _filterLeads(allLeads);
    final closedLeads =
        leads.where((l) => l.status == LeadStatus.closed).length;
    final siteVisits =
        leads.where((l) => l.status == LeadStatus.siteVisit).length;
    final newLeads =
        leads.where((l) => l.status == LeadStatus.newLead).length;
    final convRate =
        leads.isEmpty ? 0.0 : (closedLeads / leads.length) * 100;
    // Revenue
    final closedWithValue = leads.where(
        (l) => l.status == LeadStatus.closed && l.closedValue != null).toList();
    final totalRevenue =
        closedWithValue.fold<double>(0, (s, l) => s + l.closedValue!);
    final saleRevenue = closedWithValue
        .where((l) => l.leadType == LeadType.sale)
        .fold<double>(0, (s, l) => s + l.closedValue!);
    final leaseRevenue = closedWithValue
        .where((l) => l.leadType == LeadType.lease)
        .fold<double>(0, (s, l) => s + l.closedValue!);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.lavender.withValues(alpha: 0.15),
                  AppColors.pink.withValues(alpha: 0.08)
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.lavender.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(11)),
                  child: Center(
                      child: Text(
                          project.name.isNotEmpty
                              ? project.name[0].toUpperCase()
                              : 'P',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        if (project.location.isNotEmpty)
                          Text(project.location,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
                        StatusPill(
                            label: project.status.label,
                            color: project.status.color,
                            isSmall: true),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Timeline badge
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 11, color: AppColors.lavender),
                  const SizedBox(width: 5),
                  Text(_timeline.label,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lavender)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(_timeline.dateRangeLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 12),

            // KPI grid
            LayoutBuilder(
              builder: (ctx, c) => GridView.count(
                crossAxisCount: c.maxWidth > 400 ? 5 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: [
                  _kpiTile('Total', '${leads.length}',
                      AppColors.gradientPrimary),
                  _kpiTile('New', '$newLeads',
                      AppColors.gradientTertiary),
                  _kpiTile('Visits', '$siteVisits',
                      LinearGradient(
                          colors: [AppColors.peach, AppColors.orange])),
                  _kpiTile('Closed', '$closedLeads',
                      AppColors.gradientSuccess),
                  _kpiTile('Conv.%', '${convRate.toStringAsFixed(1)}%',
                      AppColors.gradientCTA),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Revenue Banner ────────────────────────────────────────────
            if (totalRevenue > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF7C6FFF).withValues(alpha: 0.10),
                    const Color(0xFFFF9F7C).withValues(alpha: 0.06),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF7C6FFF).withValues(alpha: 0.28)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.currency_rupee_rounded,
                        size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Closed Revenue',
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: AppColors.textMuted)),
                          Text(_fmtRevReport(totalRevenue),
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF7C6FFF),
                                  height: 1.1)),
                        ]),
                  ),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.sky.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('$closedLeads deals',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cyan)),
                        ),
                        const SizedBox(height: 6),
                        if (saleRevenue > 0)
                          Text(
                              'Sale: ${_fmtRevReport(saleRevenue)}',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lavender)),
                        if (leaseRevenue > 0)
                          Text(
                              'Lease/yr: ${_fmtRevReport(leaseRevenue)}',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.peach)),
                      ]),
                ]),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.currency_rupee_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text('No closed revenue recorded yet',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted)),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // CTA button
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'Preview & Download PDF Report',
                icon: Icons.download_rounded,
                height: 46,
                onTap: () => _openReportSheet(context, state, project),
                gradient: AppColors.gradientCTA,
              ),
            ),
            const SizedBox(height: 30),
          ]),
    );
  }

  Widget _kpiTile(String label, String value, LinearGradient grad) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              grad.colors.first.withValues(alpha: 0.12),
              grad.colors.last.withValues(alpha: 0.07),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: grad.colors.first.withValues(alpha: 0.25))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      );
}

// ─── Master Admin Report Screen ───────────────────────────────────────────────
class MasterAdminReportScreen extends StatefulWidget {
  const MasterAdminReportScreen({super.key});

  @override
  State<MasterAdminReportScreen> createState() =>
      _MasterAdminReportScreenState();
}

class _MasterAdminReportScreenState extends State<MasterAdminReportScreen> {
  String? _selectedProjectId; // null = All Projects
  ReportTimeline _timeline = ReportTimeline.all;

  List<Lead> _filterLeads(List<Lead> all) {
    final from = _timeline.fromDate;
    if (from == null) return all;
    return all.where((l) => l.createdAt.isAfter(from)).toList();
  }

  void _openReportSheet(
      BuildContext context, AppState state, RealEstateProject project) {
    final allLeads =
        state.leads.where((l) => l.projectId == project.id).toList();
    final leads = _filterLeads(allLeads);
    final salesTeam = state.users
        .where((u) =>
            project.assignedSalesIds.contains(u.id) ||
            (u.companyId == project.id && u.role == UserRole.sales))
        .toSet()
        .toList();
    final activities = <LeadActivity>[];
    for (final l in leads) {
      activities.addAll(l.activities);
    }
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportPreviewSheet(
        project: project,
        leads: leads,
        salesTeam: salesTeam,
        timeline: _timeline,
        activities: activities,
        isMasterAdmin: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allProjects = state.projects;
    final displayProjects = _selectedProjectId == null
        ? allProjects
        : allProjects
            .where((p) => p.id == _selectedProjectId)
            .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reports',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('Project-wise analytics · Generate & download PDF',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted)),
                ]),
          ),
          const SizedBox(height: 16),

          // ── Filters ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project dropdown
                  Text('Filter by Project',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _selectedProjectId != null
                              ? AppColors.lavender
                              : AppColors.border,
                          width: _selectedProjectId != null ? 1.5 : 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedProjectId,
                        isExpanded: true,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: BorderRadius.circular(14),
                        hint: Text('All Projects',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted)),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Row(children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                    color: AppColors.lavender
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(6)),
                                child: const Icon(Icons.apps_rounded,
                                    size: 14,
                                    color: AppColors.lavender),
                              ),
                              const SizedBox(width: 10),
                              Text('All Projects',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                            ]),
                          ),
                          ...allProjects.map((p) =>
                              DropdownMenuItem<String?>(
                                value: p.id,
                                child: Row(children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                        gradient:
                                            AppColors.gradientPrimary,
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    child: Center(
                                        child: Text(
                                            p.name.isNotEmpty
                                                ? p.name[0].toUpperCase()
                                                : 'P',
                                            style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(p.name,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.textPrimary),
                                          overflow:
                                              TextOverflow.ellipsis)),
                                ]),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedProjectId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Timeline
                  Text('Timeline',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ReportTimeline.values.map((t) {
                        final sel = _timeline == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _timeline = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: sel
                                    ? AppColors.gradientSecondary
                                    : null,
                                color: sel ? null : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel
                                        ? Colors.transparent
                                        : AppColors.border),
                              ),
                              child: Text(t.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: sel
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
          ),
          const SizedBox(height: 16),

          // ── Project Cards ──
          Expanded(
            child: displayProjects.isEmpty
                ? Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.apartment_outlined,
                              size: 56,
                              color: AppColors.textMuted
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 14),
                          Text('No projects available',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textMuted)),
                        ]))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: displayProjects.length,
                    itemBuilder: (ctx, idx) {
                      final project = displayProjects[idx];
                      return _buildProjectCard(
                          context, state, project);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(
      BuildContext context, AppState state, RealEstateProject project) {
    final allLeads =
        state.leads.where((l) => l.projectId == project.id).toList();
    final leads = _filterLeads(allLeads);
    final closedLeads =
        leads.where((l) => l.status == LeadStatus.closed).length;
    final siteVisits =
        leads.where((l) => l.status == LeadStatus.siteVisit).length;
    final newLeads =
        leads.where((l) => l.status == LeadStatus.newLead).length;
    final convRate =
        leads.isEmpty ? 0.0 : (closedLeads / leads.length) * 100;
    final salesTeam = state.users
        .where((u) =>
            project.assignedSalesIds.contains(u.id) ||
            (u.companyId == project.id && u.role == UserRole.sales))
        .toSet()
        .length;
    // Revenue from closed leads with a recorded closedValue
    final closedWithValue = leads.where(
        (l) => l.status == LeadStatus.closed && l.closedValue != null).toList();
    final totalRevenue = closedWithValue.fold<double>(
        0, (s, l) => s + l.closedValue!);
    final saleRevenue = closedWithValue
        .where((l) => l.leadType == LeadType.sale)
        .fold<double>(0, (s, l) => s + l.closedValue!);
    final leaseRevenue = closedWithValue
        .where((l) => l.leadType == LeadType.lease)
        .fold<double>(0, (s, l) => s + l.closedValue!);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(
                          project.name.isNotEmpty
                              ? project.name[0].toUpperCase()
                              : 'P',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        if (project.location.isNotEmpty)
                          Text(project.location,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
                      ]),
                ),
                StatusPill(
                    label: project.status.label,
                    color: project.status.color,
                    isSmall: true),
              ]),
            ),

            // Stats grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                _statPill('Leads', '${leads.length}',
                    AppColors.lavender),
                const SizedBox(width: 6),
                _statPill('New', '$newLeads',
                    AppColors.sky),
                const SizedBox(width: 6),
                _statPill('Visits', '$siteVisits',
                    AppColors.peach),
                const SizedBox(width: 6),
                _statPill('Closed', '$closedLeads',
                    AppColors.sky),
                const SizedBox(width: 6),
                _statPill('Team', '$salesTeam',
                    AppColors.pink),
              ]),
            ),

            // ── Revenue Banner (shown only when revenue > 0) ──────────────
            if (totalRevenue > 0) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF7C6FFF).withValues(alpha: 0.10),
                      const Color(0xFFFF9F7C).withValues(alpha: 0.06),
                    ]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF7C6FFF)
                            .withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.currency_rupee_rounded,
                          size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Closed Revenue',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: AppColors.textMuted)),
                            Text(_fmtRevReport(totalRevenue),
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF7C6FFF))),
                          ]),
                    ),
                    // Sale / Lease chips
                    if (saleRevenue > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.lavender
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Sale',
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      color: AppColors.textMuted)),
                              Text(_fmtRevReport(saleRevenue),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.lavender)),
                            ]),
                      ),
                    ],
                    if (leaseRevenue > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.peach
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Lease/yr',
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      color: AppColors.textMuted)),
                              Text(_fmtRevReport(leaseRevenue),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.peach)),
                            ]),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.sky.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5)),
                      child: Text('$closedLeads deals',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cyan)),
                    ),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Conversion + Generate button
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.peach.withValues(alpha: 0.25),
                        AppColors.orange.withValues(alpha: 0.15),
                      ]),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.trending_up_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                        'Conv. ${convRate.toStringAsFixed(1)}%  ·  ${_timeline.label}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      _openReportSheet(context, state, project),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        gradient: AppColors.gradientCTA,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Generate Report',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ]),
                  ),
                ),
              ]),
            ),
          ]),
    );
  }

  Widget _statPill(String label, String value, Color color) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.textSecondary)),
              ]),
        ),
      );
}
