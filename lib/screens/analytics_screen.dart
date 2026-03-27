import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  void _showDownloadOptions(BuildContext context, AppState state, List<Lead> leads) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportDownloadSheet(state: state, leads: leads),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Scoped leads: project admins see only their project's leads
    final leads = state.myLeads;
    final byStatus = state.leadsByStatus;
    final total = leads.length;
    final closed = byStatus[LeadStatus.closed] ?? 0;
    final siteVisit = byStatus[LeadStatus.siteVisit] ?? 0;
    final negotiation = byStatus[LeadStatus.negotiation] ?? 0;
    final lost = byStatus[LeadStatus.lost] ?? 0;
    final conversionRate = total > 0 ? (closed / total * 100) : 0.0;
    final revenue = state.closedLeadsRevenue;

    // Title: show project name for project admins, platform for master admin
    final String analyticsTitle;
    if (state.isMasterAdmin) {
      analyticsTitle = 'Platform Overview';
    } else {
      final myProjects = state.myProjects;
      if (myProjects.length == 1) {
        analyticsTitle = myProjects.first.name;
      } else if (myProjects.isNotEmpty) {
        analyticsTitle = '${myProjects.length} Projects';
      } else {
        analyticsTitle = state.currentUser?.companyName ?? 'My Projects';
      }
    }

    // Lead source breakdown
    final sourceMap = <LeadSource, int>{};
    for (final l in leads) {
      sourceMap[l.source] = (sourceMap[l.source] ?? 0) + 1;
    }
    final sortedSources = sourceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sales performance
    final salesUsers = state.salesUsers;
    final salesPerf = salesUsers.map((u) {
      final uLeads = leads.where((l) => l.assignedToId == u.id).toList();
      return (
        user: u,
        total: uLeads.length,
        closed: uLeads.where((l) => l.status == LeadStatus.closed).length
      );
    }).toList()
      ..sort((a, b) => b.closed.compareTo(a.closed));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with download button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analytics',
                          style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      Text(
                          '$analyticsTitle performance overview',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showDownloadOptions(context, state, leads),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_rounded, color: Colors.white, size: 16, shadows: [Shadow(color: Colors.black26, blurRadius: 4)]),
                        const SizedBox(width: 6),
                        Text('Export', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, shadows: [const Shadow(color: Colors.black26, blurRadius: 4)])),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // KPI cards
            LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _kpi('Conversion', '${conversionRate.toStringAsFixed(1)}%',
                      Icons.show_chart_rounded, AppColors.gradientSuccess),
                  _kpi('Total Leads', total.toString(),
                      Icons.people_alt_outlined, AppColors.gradientPrimary),
                  _kpi('Site Visits', siteVisit.toString(),
                      Icons.location_on_outlined, AppColors.gradientSecondary),
                  _kpi('Negotiation', negotiation.toString(),
                      Icons.handshake_outlined, AppColors.gradientTertiary),
                  _kpi('Closed', closed.toString(),
                      Icons.check_circle_outline_rounded,
                      AppColors.gradientSuccess),
                  _kpi(
                      'Lost',
                      lost.toString(),
                      Icons.cancel_outlined,
                      const LinearGradient(
                          colors: [AppColors.stageLost, AppColors.border])),
                ],
              );
            }),
            const SizedBox(height: 16),
            // Revenue banner for closed deals
            if (revenue > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientSuccess,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Colors.white70, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Closed Revenue', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                          Text(_fmtRevenue(revenue), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$closed deals', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                        Text('${conversionRate.toStringAsFixed(1)}% conv.', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),

            // Pipeline breakdown
            Text('Pipeline Breakdown',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: LeadStatus.values.map((s) {
                  final count = byStatus[s] ?? 0;
                  final pct = total > 0 ? count / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle, color: s.color)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(s.label,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500))),
                            Text('$count',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            Text('(${(pct * 100).toStringAsFixed(0)}%)',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Stack(children: [
                          Container(
                              height: 6,
                              decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(4))),
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                    color: s.color,
                                    borderRadius: BorderRadius.circular(4))),
                          ),
                        ]),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Lead sources
            Text('Lead Sources',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: sortedSources.isEmpty
                    ? [
                        Center(
                            child: Text('No data',
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted)))
                      ]
                    : sortedSources.map((e) {
                        final pct = total > 0 ? e.value / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 90,
                                  child: Text(e.key.label,
                                      style:
                                          GoogleFonts.inter(fontSize: 12))),
                              Expanded(
                                child: Stack(children: [
                                  Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                          color: AppColors.border,
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                  FractionallySizedBox(
                                    widthFactor: pct,
                                    child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          gradient:
                                              AppColors.gradientTertiary,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        )),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Text('${e.value}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Team leaderboard
            if (salesPerf.isNotEmpty) ...[
              Text('Team Leaderboard',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: salesPerf.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final perf = entry.value;
                    final rate = perf.total > 0
                        ? (perf.closed / perf.total * 100)
                        : 0.0;
                    final gradients = [
                      AppColors.gradientSecondary,
                      AppColors.gradientPrimary,
                      AppColors.gradientTertiary
                    ];
                    final grad = gradients[rank > 3 ? 2 : rank - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                                gradient: rank <= 3 ? grad : null,
                                color: rank > 3 ? AppColors.border : null,
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text('$rank',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: rank <= 3
                                            ? Colors.white
                                            : AppColors.textMuted))),
                          ),
                          const SizedBox(width: 10),
                          AvatarWidget(
                              initials: perf.user.initials, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(perf.user.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                LinearProgressIndicator(
                                  value: perf.total > 0
                                      ? perf.closed / perf.total
                                      : 0,
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation(
                                      grad.colors.first),
                                  borderRadius: BorderRadius.circular(4),
                                  minHeight: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${perf.closed}/${perf.total}',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              Text('${rate.toStringAsFixed(0)}%',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _kpi(
      String label, String value, IconData icon, LinearGradient grad) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          grad.colors.first.withValues(alpha: 0.12),
          grad.colors.last.withValues(alpha: 0.07)
        ]),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: grad.colors.first.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
              shaderCallback: (b) => grad.createShader(b),
              child: Icon(icon, size: 18, color: Colors.white)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _fmtRevenue(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ─── Report Download Sheet ────────────────────────────────────────────────────
class _ReportDownloadSheet extends StatefulWidget {
  final AppState state;
  final List<Lead> leads;
  const _ReportDownloadSheet({required this.state, required this.leads});

  @override
  State<_ReportDownloadSheet> createState() => _ReportDownloadSheetState();
}

class _ReportDownloadSheetState extends State<_ReportDownloadSheet> {
  String? _generating;

  void _generateReport(String type) async {
    setState(() => _generating = type);
    // Simulate report generation (1.5 seconds)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _generating = null);

    // Build report data text
    String reportContent = '';
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final companyName = widget.state.currentCompany?.name ?? 'Platform';

    if (type == 'overall') {
      final total = widget.leads.length;
      final closed = widget.leads.where((l) => l.status == LeadStatus.closed).length;
      final rate = total > 0 ? (closed / total * 100).toStringAsFixed(1) : '0.0';
      reportContent = '''
OVERALL PLATFORM REPORT — $dateStr
Company: $companyName
Total Leads: $total
Closed Deals: $closed
Conversion Rate: $rate%
Total Users: ${widget.state.totalAllUsers}
Active Projects: ${widget.state.companyProjects.length}
''';
    } else if (type == 'revenue') {
      reportContent = '''
REVENUE REPORT — $dateStr
Company: $companyName
Company: ${widget.state.currentCompany?.name ?? 'N/A'}
Leads Total: ${widget.leads.length}
Closed Leads: ${widget.leads.where((l) => l.status == LeadStatus.closed).length}
Budget Range: ${widget.leads.isNotEmpty ? widget.leads.first.budgetDisplay : 'N/A'}
''';
    } else if (type == 'users') {
      final users = widget.state.isAdmin ? widget.state.companyUsers : widget.state.salesUsers;
      final lines = users.map((u) => '  - ${u.name} (${u.roleLabel}) — ${u.email}').join('\n');
      reportContent = '''
USER REPORT — $dateStr
Company: $companyName
Total Users: ${users.length}
Users:
$lines
''';
    }

    // Show preview dialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          ShaderMask(shaderCallback: (b) => AppColors.gradientPrimary.createShader(b), child: const Icon(Icons.description_outlined, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          Text(_reportTitle(type), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(reportContent.trim(), style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sky.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.sky.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Report generated successfully. In a production environment, this would download as a PDF or CSV file.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.cyan))),
                ]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.download_done_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('${_reportTitle(type)} downloaded!', style: GoogleFonts.inter(fontSize: 12)),
                ]),
                backgroundColor: AppColors.cyan,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
              child: Text('Download', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, shadows: [const Shadow(color: Colors.black26, blurRadius: 4)])),
            ),
          ),
        ],
      ),
    );
  }

  String _reportTitle(String type) {
    switch (type) {
      case 'overall': return 'Overall Platform Report';
      case 'revenue': return 'Revenue Report';
      case 'users': return 'User Report';
      default: return 'Report';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            ShaderMask(shaderCallback: (b) => AppColors.gradientPrimary.createShader(b), child: const Icon(Icons.download_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 10),
            Text('Export Report', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 6),
          Text('Select the type of report you want to export', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          _reportOption(
            'overall',
            Icons.public_rounded,
            'Overall Platform Report',
            'Leads summary, conversion rate, team performance, pipeline stages',
            AppColors.gradientPrimary,
          ),
          const SizedBox(height: 12),
          _reportOption(
            'revenue',
            Icons.attach_money_rounded,
            'Revenue Report',
            'Company performance, deal values, closed leads breakdown',
            AppColors.gradientSuccess,
          ),
          const SizedBox(height: 12),
          _reportOption(
            'users',
            Icons.people_alt_outlined,
            'User Report',
            'All users list, roles, activity status and contact details',
            AppColors.gradientTertiary,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _reportOption(String type, IconData icon, String title, String description, LinearGradient grad) {
    final isLoading = _generating == type;
    return GestureDetector(
      onTap: isLoading ? null : () => _generateReport(type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.1), grad.colors.last.withValues(alpha: 0.05)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: grad.colors.first.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(12)),
              child: isLoading
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : Icon(icon, color: Colors.white, size: 20, shadows: const [Shadow(color: Colors.black26, blurRadius: 4)]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(description, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(isLoading ? Icons.hourglass_top_rounded : Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
