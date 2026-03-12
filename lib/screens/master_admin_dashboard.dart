import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

// ─── Master Admin Dashboard ───────────────────────────────────────────────────
class MasterAdminDashboard extends StatefulWidget {
  const MasterAdminDashboard({super.key});

  @override
  State<MasterAdminDashboard> createState() => _MasterAdminDashboardState();
}

class _MasterAdminDashboardState extends State<MasterAdminDashboard>
    with TickerProviderStateMixin {
  int _tab = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _tabs = ['Overview', 'Approvals', 'Projects', 'Analytics', 'Users', 'Reports'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.pending_actions_outlined,
    Icons.apartment_outlined,
    Icons.analytics_outlined,
    Icons.people_outline_rounded,
    Icons.bar_chart_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    if (_tab == i) return;
    _fadeCtrl.reset();
    setState(() => _tab = i);
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildWideLayout(),
      );
    }
    final state = context.watch<AppState>();
    final pendingCount = state.pendingApprovalCount;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        width: 260,
        child: _MasterSidebar(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: (i) { Navigator.pop(context); _switchTab(i); },
          pendingApprovals: pendingCount,
        ),
      ),
      body: _buildMobileLayout(),
    );
  }

  Widget _buildWideLayout() {
    final state = context.watch<AppState>();
    final pendingCount = state.pendingApprovalCount;
    return Row(
      children: [
        _MasterSidebar(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: _switchTab,
          pendingApprovals: pendingCount,
        ),
        Expanded(
          child: FadeTransition(opacity: _fadeAnim, child: _currentScreen()),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final state = context.watch<AppState>();
    final pendingCount = state.pendingApprovalCount;
    return Column(
      children: [
        // Mobile top bar with menu + logout
        SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(gradient: AppColors.gradientSecondary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.menu_rounded, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RlaBrand(size: 13),
                      Text('Master Admin · ${state.currentUser?.name ?? ""}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (pendingCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('$pendingCount pending', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFD08020))),
                  ),
                GestureDetector(
                  onTap: () => context.read<AppState>().logout(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.logout_rounded, size: 17, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: FadeTransition(opacity: _fadeAnim, child: _currentScreen())),
        _MasterBottomNav(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: _switchTab,
          pendingApprovals: pendingCount,
        ),
      ],
    );
  }

  Widget _currentScreen() {
    switch (_tab) {
      case 0: return const _MasterOverview();
      case 1: return const _ApprovalsScreen();
      case 2: return const _MasterProjectsScreen();
      case 3: return const _MasterAnalyticsScreen();
      case 4: return const _AllUsersScreen();
      case 5: return const _MasterReportsScreen();
      default: return const _MasterOverview();
    }
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
class _MasterSidebar extends StatelessWidget {
  final List<String> tabs;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;
  final int pendingApprovals;

  const _MasterSidebar({
    required this.tabs, required this.icons, required this.current,
    required this.onSelect, required this.pendingApprovals,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(2, 0))],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(gradient: AppColors.gradientSecondary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.star_rounded, size: 18, color: Colors.white)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RlaBrand(size: 13),
                      Text('Master Admin', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted, letterSpacing: 0.5)),
                    ],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.peach.withValues(alpha: 0.3), AppColors.orange.withValues(alpha: 0.2)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFFD08020)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(state.currentUser?.name ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD08020)), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: List.generate(tabs.length, (i) => _sidebarItem(i)),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1)),
            _logoutItem(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(int i) {
    final sel = i == current;
    final showBadge = i == 1 && pendingApprovals > 0;
    return GestureDetector(
      onTap: () => onSelect(i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.gradientSecondary : null,
          color: sel ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icons[i], size: 18, color: sel ? AppColors.textPrimary : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(tabs[i], style: GoogleFonts.inter(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.textPrimary : AppColors.textSecondary))),
            if (showBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sel ? AppColors.textPrimary.withValues(alpha: 0.15) : AppColors.pink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$pendingApprovals', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: sel ? AppColors.textPrimary : const Color(0xFFD04060))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logoutItem(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AppState>().logout(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text('Sign Out', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Nav (mobile) ──────────────────────────────────────────────────────
class _MasterBottomNav extends StatelessWidget {
  final List<String> tabs;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;
  final int pendingApprovals;

  const _MasterBottomNav({
    required this.tabs, required this.icons, required this.current,
    required this.onSelect, required this.pendingApprovals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final sel = i == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: sel ? AppColors.peach.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(icons[i], size: 20, color: sel ? AppColors.peach : AppColors.textMuted),
                          ),
                        ),
                        if (i == 1 && pendingApprovals > 0)
                          Positioned(
                            top: -2, right: -6,
                            child: Container(
                              width: 14, height: 14,
                              decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                              child: Center(child: Text('$pendingApprovals', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Overview ─────────────────────────────────────────────────────────────────
class _MasterOverview extends StatelessWidget {
  const _MasterOverview();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.masterAdminPendingApprovals;
    final totalLeads = state.totalAllLeads;
    final totalClosures = state.totalAllClosures;
    final conversionRate = state.overallConversionRate;
    final allProjects = state.projects;
    final activeProjects = allProjects.where((p) => p.status == ProjectStatus.active).length;
    final globalStatus = state.globalLeadsByStatus;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Master Control', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('Platform-wide overview', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAlertSheet(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientSecondary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: AppColors.peach.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.notifications_active_rounded, size: 14, color: AppColors.textPrimary),
                      const SizedBox(width: 5),
                      Text('Send Alert', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => state.logout(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.logout_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text('Logout', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pending approvals banner
            if (pending.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.peach.withValues(alpha: 0.2), AppColors.orange.withValues(alpha: 0.1)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.peach.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_outlined, size: 18, color: Color(0xFFD08020)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      '${pending.length} company registration request${pending.length > 1 ? 's' : ''} pending your approval',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFD08020)),
                    )),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFD08020)),
                  ],
                ),
              ),

            // Primary KPI grid
            LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _statCard('Total Projects', allProjects.length.toString(), Icons.apartment_outlined, AppColors.gradientPrimary),
                  _statCard('Total Leads', totalLeads.toString(), Icons.trending_up_rounded, AppColors.gradientTertiary),
                  _statCard('Closures', totalClosures.toString(), Icons.check_circle_outline_rounded, AppColors.gradientSuccess),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Conversion & active projects highlight
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    'Conversion Rate',
                    '${conversionRate.toStringAsFixed(1)}%',
                    'Overall platform',
                    Icons.donut_large_rounded,
                    AppColors.gradientCTA,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    'Active Projects',
                    '$activeProjects / ${allProjects.length}',
                    'Currently running',
                    Icons.play_circle_outline_rounded,
                    AppColors.gradientSuccess,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    'Total Users',
                    state.totalAllUsers.toString(),
                    'All companies',
                    Icons.people_outline_rounded,
                    AppColors.gradientPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Lead status funnel
            Text('Global Lead Pipeline', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: LeadStatus.values.map((s) {
                  final count = globalStatus[s] ?? 0;
                  final pct = totalLeads > 0 ? count / totalLeads : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: Text(s.label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(height: 8, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                              FractionallySizedBox(
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(height: 8, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 40,
                          child: Text('$count', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Top performing projects
            Text('Top Projects by Leads', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            ..._topProjects(state),
            const SizedBox(height: 16),


          ],
        ),
      ),
    );
  }

  List<Widget> _topProjects(AppState state) {
    final allStats = state.allProjectsStats;
    final sorted = allStats.entries.toList()
      ..sort((a, b) => (b.value['totalLeads'] as int).compareTo(a.value['totalLeads'] as int));
    final top = sorted.take(5);

    if (top.isEmpty) {
      return [Center(child: Text('No projects yet', style: GoogleFonts.inter(color: AppColors.textMuted)))];
    }

    return top.map((entry) {
      final data = entry.value;
      final project = data['project'] as RealEstateProject;
      final company = data['company'] as Company;
      final totalLeads = data['totalLeads'] as int;
      final closed = data['closed'] as int;
      final rate = data['conversionRate'] as double;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(
                project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(company.name, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$totalLeads leads', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('$closed closed · ${rate.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _statCard(String label, String value, IconData icon, LinearGradient grad) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.12), grad.colors.last.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grad.colors.first.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(shaderCallback: (b) => grad.createShader(b), child: Icon(icon, size: 20, color: Colors.white)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, String sub, IconData icon, LinearGradient grad) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.1), grad.colors.last.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: grad.colors.first.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(shaderCallback: (b) => grad.createShader(b), child: Icon(icon, size: 18, color: Colors.white)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          Text(sub, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  void _showAlertSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MasterAlertSheet(state: state),
    );
  }

  Widget _companyRow(BuildContext context, Company c) {
    return GestureDetector(
      onTap: () => _showCompanyDetails(context, c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            AvatarWidget(initials: c.initials, size: 40, gradient: AppColors.gradientSecondary),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(c.adminEmail, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              ],
            )),
            StatusPill(label: c.isActive ? 'Active' : 'Inactive', color: c.isActive ? AppColors.mint : AppColors.stageLost, isSmall: true),
          ],
        ),
      ),
    );
  }

  void _showCompanyDetails(BuildContext context, Company c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyDetailSheet(company: c),
    );
  }
}

// ─── Approvals Screen ─────────────────────────────────────────────────────────
class _ApprovalsScreen extends StatefulWidget {
  const _ApprovalsScreen();

  @override
  State<_ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<_ApprovalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.approvals.where((a) => a.type == ApprovalType.companyRegistration && a.status == ApprovalStatus.pending).toList();
    final approved = state.approvals.where((a) => a.type == ApprovalType.companyRegistration && a.status == ApprovalStatus.approved).toList();
    final rejected = state.approvals.where((a) => a.type == ApprovalType.companyRegistration && a.status == ApprovalStatus.rejected).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Project Registrations', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Review project registration requests', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ],
                )),
                if (pending.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.peach.withValues(alpha: 0.4))),
                    child: Text('${pending.length} pending', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFD08020))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabCtrl,
            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.peach,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'Approved (${approved.length})'),
              Tab(text: 'Rejected (${rejected.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ApprovalList(approvals: pending, isPending: true),
                _ApprovalList(approvals: approved, isPending: false),
                _ApprovalList(approvals: rejected, isPending: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  final List<ApprovalRequest> approvals;
  final bool isPending;
  const _ApprovalList({required this.approvals, required this.isPending});

  @override
  Widget build(BuildContext context) {
    if (approvals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No requests here', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: approvals.length,
      itemBuilder: (_, i) => _ApprovalCard(approval: approvals[i], isPending: isPending),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final ApprovalRequest approval;
  final bool isPending;
  const _ApprovalCard({required this.approval, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: approval.status.color.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.gradientSecondary, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(
                    (approval.companyName ?? approval.applicantName).isNotEmpty
                        ? (approval.companyName ?? approval.applicantName)[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(approval.companyName ?? 'Unknown Company', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(approval.applicantName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.mail_outline_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(approval.applicantEmail, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                      ]),
                      if (approval.phone != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.phone_outlined, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(approval.phone!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ]),
                      ],
                    ],
                  ),
                ),
                StatusPill(label: approval.status.label, color: approval.status.color, isSmall: true),
              ],
            ),
          ),
          if (isPending)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Text(
                    'Submitted ${_timeAgo(approval.createdAt)}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showRejectDialog(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.pink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.pink.withValues(alpha: 0.4)),
                      ),
                      child: Text('Reject', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFD04060))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => state.approveCompanyRegistration(approval.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientSuccess,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Approve', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          if (!isPending && approval.reviewNote != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(children: [
                const Icon(Icons.comment_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(child: Text('Note: ${approval.reviewNote!}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic))),
              ]),
            ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, AppState state) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Registration', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject "${approval.companyName ?? approval.applicantName}"?', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.rejectCompanyRegistration(approval.id, note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
            },
            child: Text('Reject', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

// ─── Project Analytics Dashboard ──────────────────────────────────────────────
class _MasterAnalyticsScreen extends StatelessWidget {
  const _MasterAnalyticsScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allStats = state.allProjectsStats;
    final sorted = allStats.entries.toList()
      ..sort((a, b) => (b.value['totalLeads'] as int).compareTo(a.value['totalLeads'] as int));
    final totalLeads = state.totalAllLeads;
    final totalClosures = state.totalAllClosures;
    final conversionRate = state.overallConversionRate;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project Analytics', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text('Performance across all projects & companies', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),

            // Summary KPIs
            LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _kpiCard('Total Leads', totalLeads.toString(), Icons.trending_up_rounded, AppColors.gradientTertiary),
                  _kpiCard('Closures', totalClosures.toString(), Icons.check_circle_outline_rounded, AppColors.gradientSuccess),
                  _kpiCard('Conv. Rate', '${conversionRate.toStringAsFixed(1)}%', Icons.donut_large_rounded, AppColors.gradientCTA),
                  _kpiCard('Projects', state.projects.length.toString(), Icons.apartment_outlined, AppColors.gradientPrimary),
                  _kpiCard('Users', state.totalAllUsers.toString(), Icons.people_outline_rounded, const LinearGradient(colors: [AppColors.sky, AppColors.teal])),
                ],
              );
            }),
            const SizedBox(height: 24),

            // Lead status breakdown
            Text('Global Lead Status Breakdown', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: LeadStatus.values.map((s) {
                  final count = (state.globalLeadsByStatus[s] ?? 0);
                  final pct = totalLeads > 0 ? count / totalLeads : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: Text(s.label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(height: 8, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                              FractionallySizedBox(
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(height: 8, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 40,
                          child: Text('$count', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.right),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text('(${(pct * 100).toStringAsFixed(0)}%)', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Per-project table
            Text('All Projects Performance', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.apartment_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 10),
                  Text('No projects yet', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                ]),
              )
            else
              ...sorted.map((entry) {
                final data = entry.value;
                final project = data['project'] as RealEstateProject;
                final company = data['company'] as Company;
                final total = data['totalLeads'] as int;
                final closed = data['closed'] as int;
                final siteVisit = data['siteVisit'] as int;
                final newL = data['newLeads'] as int;
                final rate = data['conversionRate'] as double;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(11)),
                            child: Center(child: Text(
                              project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(project.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                Row(children: [
                                  const Icon(Icons.business_outlined, size: 11, color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text(company.name, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Expanded(child: Text(project.location, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
                                ]),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: project.status.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(project.status.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statCol('Total', '$total', AppColors.textPrimary),
                            _divider(),
                            _statCol('New', '$newL', AppColors.lavender),
                            _divider(),
                            _statCol('Site Visit', '$siteVisit', AppColors.teal),
                            _divider(),
                            _statCol('Closed', '$closed', const Color(0xFF3B8A6E)),
                            _divider(),
                            _statCol('Conv.', '${rate.toStringAsFixed(0)}%', const Color(0xFF5B3FBF)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, LinearGradient grad) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.12), grad.colors.last.withValues(alpha: 0.07)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grad.colors.first.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(shaderCallback: (b) => grad.createShader(b), child: Icon(icon, size: 18, color: Colors.white)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: AppColors.border);
}

// ─── Companies Screen ─────────────────────────────────────────────────────────
class _CompaniesScreen extends StatefulWidget {
  const _CompaniesScreen();

  @override
  State<_CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<_CompaniesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filtered = state.companies.where((c) =>
        c.name.toLowerCase().contains(_search.toLowerCase()) ||
        c.adminEmail.toLowerCase().contains(_search.toLowerCase())).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Companies', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${state.totalCompanies} registered', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ],
                )),
                GradientButton(
                  label: 'Add Project',
                  icon: Icons.add_rounded,
                  height: 40,
                  onTap: () => _showAddCompany(context),
                  gradient: AppColors.gradientSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search companies...', prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted)),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('No companies found', style: GoogleFonts.inter(color: AppColors.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _CompanyCard(company: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddCompany(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCompanySheet(),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final Company company;
  const _CompanyCard({required this.company});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final companyUsers = state.users.where((u) => u.companyId == company.id).length;
    final companyLeads = state.leads.where((l) => l.companyId == company.id).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: company.isActive ? AppColors.border : AppColors.stageLost.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AvatarWidget(
                  initials: company.initials,
                  size: 44,
                  gradient: company.isActive ? AppColors.gradientSecondary : const LinearGradient(colors: [AppColors.stageLost, AppColors.border]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(company.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                        StatusPill(label: company.isActive ? 'Active' : 'Inactive', color: company.isActive ? AppColors.mint : AppColors.stageLost, isSmall: true),
                      ]),
                      const SizedBox(height: 2),
                      Text(company.adminEmail, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Row(children: [
                        StatusPill(label: company.isActive ? 'Active' : 'Inactive', color: company.isActive ? AppColors.mint : AppColors.stageLost, isSmall: true),
                        if (!company.isApproved) ...[
                          const SizedBox(width: 6),
                          StatusPill(label: 'Pending', color: AppColors.peach, isSmall: true),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _stat(Icons.people_outline, '$companyUsers users'),
                const SizedBox(width: 16),
                _stat(Icons.trending_up_rounded, '$companyLeads leads'),
                const Spacer(),
                
                const SizedBox(width: 6),
                _actionBtn(
                  company.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                  company.isActive ? AppColors.pink : AppColors.mint,
                  () => state.toggleCompanyActive(company.id),
                ),
                const SizedBox(width: 6),
                _actionBtn(Icons.delete_outline_rounded, AppColors.stageLost, () => _confirmDelete(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: AppColors.textMuted), const SizedBox(width: 4), Text(text, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))]);

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 15, color: color)),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Company', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Delete "${company.name}"? This will also remove all associated users.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(onPressed: () { Navigator.pop(ctx); context.read<AppState>().deleteCompany(company.id); }, child: Text('Delete', style: GoogleFonts.inter(color: Colors.red))),
        ],
      ),
    );
  }
}

// ─── Company Detail Sheet ─────────────────────────────────────────────────────
class _CompanyDetailSheet extends StatelessWidget {
  final Company company;
  const _CompanyDetailSheet({required this.company});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final users = state.users.where((u) => u.companyId == company.id).toList();
    final leads = state.leads.where((l) => l.companyId == company.id).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(initials: company.initials, size: 52, gradient: AppColors.gradientSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(company.adminEmail, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              StatusPill(label: company.isActive ? 'Active' : 'Inactive', color: company.isActive ? AppColors.mint : AppColors.stageLost),
            ]),
            const SizedBox(height: 16),
            // Detailed info grid
            LayoutBuilder(builder: (_, constraints) {
              final cols = constraints.maxWidth > 400 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: [
                  _infoBadge('Users', users.length.toString()),
                  _infoBadge('Leads', leads.length.toString()),
                  _infoBadge('Admin', company.adminName),
                  _infoBadge('First Reg.', _fmtDate(company.createdAt)),
                  _infoBadge('Days Active', '${company.daysElapsed}'),
                ],
              );
            }),
            if (company.phone != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.phone_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(company.phone!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ],
            const SizedBox(height: 16),
            Text('Team Members (${users.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ...users.map((u) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  AvatarWidget(initials: u.initials, size: 32),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(u.email, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  )),
                  StatusPill(label: u.roleLabel, color: u.role == UserRole.companyAdmin ? AppColors.lavender : AppColors.sky, isSmall: true),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ─── Add Company Sheet ────────────────────────────────────────────────────────
class _AddCompanySheet extends StatefulWidget {
  const _AddCompanySheet();

  @override
  State<_AddCompanySheet> createState() => _AddCompanySheetState();
}

class _AddCompanySheetState extends State<_AddCompanySheet> {
  final _nameCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _adminNameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.isEmpty || _adminNameCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      setState(() => _error = 'Project name, admin name, and email are required');
      return;
    }
    if (_passCtrl.text.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    final state = context.read<AppState>();
    // Check email uniqueness
    if (state.users.any((u) => u.email.toLowerCase() == _emailCtrl.text.trim().toLowerCase())) {
      setState(() => _error = 'This email is already registered');
      return;
    }
    setState(() { _loading = true; _error = null; });
    // Directly create company (master admin bypass)
    final company = Company(
      name: _nameCtrl.text.trim(),
      adminEmail: _emailCtrl.text.trim(),
      adminName: _adminNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      isApproved: true,
    );
    state.addCompany(company);
    // Also create the Project Admin user automatically
    state.addUser(AppUser(
      name: _adminNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      role: UserRole.companyAdmin,
      companyId: company.id,
      companyName: company.name,
      isApproved: true,
      hasLoggedInBefore: false,
    ));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Project "${company.name}" created. Admin "${_adminNameCtrl.text.trim()}" can now log in.', style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: const Color(0xFF3B7A8A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(gradient: AppColors.gradientSecondary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_business_outlined, size: 18, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add New Project', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Creates project + Project Admin account', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.sky.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.sky.withValues(alpha: 0.4))),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF2090A0)),
                const SizedBox(width: 8),
                Expanded(child: Text('A Project Admin account will be created automatically with the credentials below.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2090A0)))),
              ]),
            ),
            const SizedBox(height: 14),
            _field(_nameCtrl, 'Project / Company Name *', Icons.business_outlined),
            const SizedBox(height: 10),
            _field(_adminNameCtrl, 'Project Admin Name *', Icons.person_outline_rounded),
            const SizedBox(height: 10),
            _field(_emailCtrl, 'Admin Email *', Icons.mail_outline_rounded, TextInputType.emailAddress),
            const SizedBox(height: 10),
            TextField(
              controller: _passCtrl, obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Admin Password *',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _field(_phoneCtrl, 'Phone (optional)', Icons.phone_outlined, TextInputType.phone),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD04060))),
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(label: 'Create Project', onTap: _save, isLoading: _loading, icon: Icons.add_business_outlined, gradient: AppColors.gradientSecondary),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, [TextInputType? type]) {
    return TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted)));
  }
}

// ─── All Users Screen ─────────────────────────────────────────────────────────
class _AllUsersScreen extends StatefulWidget {
  const _AllUsersScreen();

  @override
  State<_AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<_AllUsersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final masterAdmins = state.masterAdmins;
    final filtered = state.users.where((u) =>
        u.name.toLowerCase().contains(_search.toLowerCase()) ||
        u.email.toLowerCase().contains(_search.toLowerCase())).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All Users', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${state.totalAllUsers} total users · ${masterAdmins.length} master admins', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GradientButton(
                      label: 'Add Project Admin',
                      icon: Icons.admin_panel_settings_rounded,
                      height: 36,
                      onTap: () => _showAddProjectAdmin(context),
                      gradient: AppColors.gradientPrimary,
                    ),
                    const SizedBox(height: 6),
                    GradientButton(
                      label: 'Add Master Admin',
                      icon: Icons.star_rounded,
                      height: 36,
                      onTap: () => _showAddMasterAdmin(context),
                      gradient: AppColors.gradientSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search users...', prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted)),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final u = filtered[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: u.role == UserRole.masterAdmin ? AppColors.peach.withValues(alpha: 0.4) : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        initials: u.initials,
                        size: 40,
                        gradient: u.role == UserRole.masterAdmin
                            ? AppColors.gradientSecondary
                            : u.role == UserRole.companyAdmin
                                ? AppColors.gradientPrimary
                                : AppColors.gradientTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Text(u.email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            if (u.companyName != null) Text(u.companyName!, style: GoogleFonts.inter(fontSize: 10, color: AppColors.lavender)),
                          ],
                        ),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        StatusPill(
                          label: u.roleLabel,
                          color: u.role == UserRole.masterAdmin ? AppColors.peach : u.role == UserRole.companyAdmin ? AppColors.lavender : AppColors.sky,
                          isSmall: true,
                        ),
                        const SizedBox(height: 4),
                        StatusPill(label: u.isActive ? 'Active' : 'Inactive', color: u.isActive ? AppColors.mint : AppColors.stageLost, isSmall: true),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProjectAdmin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddProjectAdminSheet(),
    );
  }

  void _showAddMasterAdmin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMasterAdminSheet(),
    );
  }
}

// ─── Add Master Admin Sheet ───────────────────────────────────────────────────
class _AddMasterAdminSheet extends StatefulWidget {
  const _AddMasterAdminSheet();

  @override
  State<_AddMasterAdminSheet> createState() => _AddMasterAdminSheetState();
}

class _AddMasterAdminSheetState extends State<_AddMasterAdminSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final err = context.read<AppState>().createMasterAdmin(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Master Admin "${_nameCtrl.text.trim()}" created successfully!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFD08020),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(gradient: AppColors.gradientSecondary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.star_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Master Admin', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Full platform access granted immediately', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ],
                )),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.peach.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD08020)),
                const SizedBox(width: 8),
                Expanded(child: Text('This user will have complete platform access including all projects, approvals, and user management.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD08020)))),
              ]),
            ),
            const SizedBox(height: 16),
            _field(_nameCtrl, 'Full Name *', Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _field(_emailCtrl, 'Email Address *', Icons.mail_outline_rounded, TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password *',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD04060))),
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(label: 'Create Master Admin', onTap: _save, isLoading: _loading, icon: Icons.star_rounded, gradient: AppColors.gradientSecondary),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, [TextInputType? type]) {
    return TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted)));
  }
}

// ─── Add Project Admin Sheet ──────────────────────────────────────────────────
class _AddProjectAdminSheet extends StatefulWidget {
  const _AddProjectAdminSheet();

  @override
  State<_AddProjectAdminSheet> createState() => _AddProjectAdminSheetState();
}

class _AddProjectAdminSheetState extends State<_AddProjectAdminSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _selectedProjectId;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (_selectedProjectId == null) {
      setState(() => _error = 'Please select a project');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final err = context.read<AppState>().addProjectAdmin(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      projectId: _selectedProjectId!,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project Admin "${_nameCtrl.text.trim()}" added successfully!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF5B3FBF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.read<AppState>().projects.toList();
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Project Admin', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Assign admin access to an existing project', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ],
                )),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lavender.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lavender.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.lavender),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'This Project Admin will have full access to manage leads, sales team, and settings for the selected project.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.lavender),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Select Project *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _selectedProjectId == null ? AppColors.border : AppColors.lavender,
                    width: _selectedProjectId == null ? 1 : 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProjectId,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('-- Choose project --', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  borderRadius: BorderRadius.circular(14),
                  items: projects.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(7)),
                            child: Center(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(p.location, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          )),
                        ],
                      ),
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedProjectId = v),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _field(_nameCtrl, 'Admin Full Name *', Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _field(_emailCtrl, 'Email Address *', Icons.mail_outline_rounded, TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password *',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD04060))),
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(label: 'Add Project Admin', onTap: _save, isLoading: _loading, icon: Icons.admin_panel_settings_rounded, gradient: AppColors.gradientPrimary),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, [TextInputType? type]) {
    return TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted)));
  }
}

// ─── Master Projects Screen ───────────────────────────────────────────────────
class _MasterProjectsScreen extends StatefulWidget {
  const _MasterProjectsScreen();
  @override
  State<_MasterProjectsScreen> createState() => _MasterProjectsScreenState();
}

class _MasterProjectsScreenState extends State<_MasterProjectsScreen> {
  String _search = '';

  // Helper: get the project admin name for a given companyId (or project ID)
  String _projectAdminName(AppState state, String projectId) {
    try {
      final admin = state.users.firstWhere(
        (u) => u.companyId == projectId && u.role == UserRole.companyAdmin && u.isApproved,
      );
      return admin.name;
    } catch (_) {
      return 'No admin assigned';
    }
  }

  void _showProjectSheet(BuildContext context, AppState state, RealEstateProject? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    final devCtrl = TextEditingController(text: existing?.developerName ?? '');
    final priceFromCtrl = TextEditingController(text: existing?.priceFrom?.toStringAsFixed(0) ?? '');
    final priceToCtrl = TextEditingController(text: existing?.priceTo?.toStringAsFixed(0) ?? '');
    PropertyType propType = existing?.propertyType ?? PropertyType.apartment;
    ProjectStatus projStatus = existing?.status ?? ProjectStatus.active;
    List<String> assignedIds = List.from(existing?.assignedSalesIds ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Sales team: when editing, show members linked to this project; when creating, empty
          final salesForSheet = existing != null
              ? state.users.where((u) => u.companyId == existing.companyId && u.role == UserRole.sales && u.isApproved).toList()
              : <AppUser>[];
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(existing == null ? 'New Project' : 'Edit Project', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary))),
                      ],
                    ),
                  ),
                  Container(margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), height: 1, color: AppColors.border),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Project Details ────────────────────────────────
                          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Project Name *', prefixIcon: Icon(Icons.apartment_outlined, size: 17, color: AppColors.textMuted))),
                          const SizedBox(height: 12),
                          TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location *', prefixIcon: Icon(Icons.location_on_outlined, size: 17, color: AppColors.textMuted))),
                          const SizedBox(height: 12),
                          TextField(controller: devCtrl, decoration: const InputDecoration(labelText: 'Developer Name', prefixIcon: Icon(Icons.business_outlined, size: 17, color: AppColors.textMuted))),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: TextField(controller: priceFromCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price From (₹)', prefixIcon: Icon(Icons.currency_rupee_rounded, size: 17, color: AppColors.textMuted)))),
                            const SizedBox(width: 10),
                            Expanded(child: TextField(controller: priceToCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price To (₹)', prefixIcon: Icon(Icons.currency_rupee_rounded, size: 17, color: AppColors.textMuted)))),
                          ]),
                          const SizedBox(height: 14),
                          Text('Property Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: PropertyType.values.map((t) {
                            final ia = propType == t;
                            return GestureDetector(
                              onTap: () => setS(() => propType = t),
                              child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(gradient: ia ? AppColors.gradientSecondary : null, color: ia ? null : AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: ia ? Colors.transparent : AppColors.border)),
                                child: Text(t.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: ia ? FontWeight.w600 : FontWeight.w400, color: ia ? AppColors.textPrimary : AppColors.textSecondary)),
                              ),
                            );
                          }).toList()),
                          if (existing != null) ...[
                            const SizedBox(height: 16),
                            Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Row(children: ProjectStatus.values.map((s) {
                              final ia = projStatus == s;
                              return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                                onTap: () => setS(() => projStatus = s),
                                child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(color: ia ? s.color.withValues(alpha: 0.2) : AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: ia ? s.color.withValues(alpha: 0.5) : AppColors.border)),
                                  child: Text(s.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: ia ? FontWeight.w600 : FontWeight.w400, color: AppColors.textPrimary)),
                                ),
                              ));
                            }).toList()),
                          ],
                          // ── Sales Team (only shown when editing) ───────────
                          if (existing != null) ...[
                            const SizedBox(height: 16),
                            Text('Assign Sales Team', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            if (salesForSheet.isEmpty)
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                                child: Text('No approved sales team members yet. The Project Admin can add sales members after login.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)))
                            else
                              ...salesForSheet.map((u) {
                                final isSel = assignedIds.contains(u.id);
                                return Padding(padding: const EdgeInsets.only(bottom: 6), child: GestureDetector(
                                  onTap: () => setS(() { if (isSel) assignedIds.remove(u.id); else assignedIds.add(u.id); }),
                                  child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(color: isSel ? AppColors.lavender.withValues(alpha: 0.1) : AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSel ? AppColors.lavender.withValues(alpha: 0.5) : AppColors.border)),
                                    child: Row(children: [
                                      AvatarWidget(initials: u.initials, size: 32, gradient: AppColors.gradientTertiary),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(u.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: isSel ? FontWeight.w600 : FontWeight.w400, color: AppColors.textPrimary))),
                                      if (isSel) const Icon(Icons.check_circle_rounded, color: AppColors.lavender, size: 18),
                                    ]),
                                  ),
                                ));
                              }),
                          ],
                          const SizedBox(height: 20),
                          GradientButton(
                            label: existing == null ? 'Create Project' : 'Update Project',
                            icon: existing == null ? Icons.add_rounded : Icons.check_rounded,
                            onTap: () {
                              if (nameCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty) return;
                              if (existing == null) {
                                // Create new standalone project — admin assigned separately via Users tab
                                final newProject = RealEstateProject(
                                  name: nameCtrl.text.trim(), location: locCtrl.text.trim(),
                                  developerName: devCtrl.text.trim(),
                                  priceFrom: double.tryParse(priceFromCtrl.text), priceTo: double.tryParse(priceToCtrl.text),
                                  propertyType: propType, assignedSalesIds: [],
                                  createdById: state.currentUser!.id, createdByName: state.currentUser!.name,
                                  companyId: 'rla_platform',
                                );
                                state.addProject(newProject);
                              } else {
                                existing.name = nameCtrl.text.trim(); existing.location = locCtrl.text.trim();
                                existing.developerName = devCtrl.text.trim();
                                existing.priceFrom = double.tryParse(priceFromCtrl.text);
                                existing.priceTo = double.tryParse(priceToCtrl.text);
                                existing.propertyType = propType; existing.status = projStatus;
                                existing.assignedSalesIds = assignedIds;
                                state.updateProject(existing);
                              }
                              Navigator.pop(ctx);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    var projects = state.projects;
    if (_search.isNotEmpty) {
      projects = projects.where((p) =>
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.location.toLowerCase().contains(_search.toLowerCase())).toList();
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All Projects', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('${state.projects.length} active projects on the platform', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GradientButton(
                  label: 'New Project',
                  icon: Icons.add_rounded,
                  height: 38,
                  onTap: () => _showProjectSheet(context, state, null),
                  gradient: AppColors.gradientCTA,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search projects...', prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted)),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: projects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.apartment_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(_search.isNotEmpty ? 'No projects match your search.' : 'No projects yet. Tap "New Project" to create one.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: projects.length,
                    itemBuilder: (ctx, i) {
                      final p = projects[i];
                      // Find admin for this project
                      final adminName = _projectAdminName(state, p.companyId);
                      final leads = state.leads.where((l) => l.projectId == p.id).toList();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(12)),
                              child: Center(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(adminName, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(p.location, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: p.status.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                  child: Text(p.status.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                const SizedBox(height: 4),
                                Text('${leads.length} leads', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _showProjectSheet(context, state, p),
                                  child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.lavender.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.lavender)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Master Analytics Screen ──────────────────────────────────────────────────
// ─── Master Reports Screen ───────────────────────────────────────────────────
class _MasterReportsScreen extends StatelessWidget {
  const _MasterReportsScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Use ALL projects directly — no longer grouped by company
    final allProjects = state.projects;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project Reports', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text('Performance summary per project', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),

            if (allProjects.isEmpty)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('No projects yet. Use the Projects tab to create your first project.', style: GoogleFonts.inter(color: AppColors.textMuted)),
                ]),
              )
            else
              ...allProjects.map((project) {
                // Users linked to this project (via companyId = project.id)
                final projectUsers = state.users.where((u) => u.companyId == project.id && u.isApproved).toList();
                // Also include users linked via the legacy 'rla_platform' companyId (standalone projects)
                final projectLeads = state.leads.where((l) => l.projectId == project.id).toList();
                final closedLeads = projectLeads.where((l) => l.status == LeadStatus.closed).length;
                final siteVisits = projectLeads.where((l) => l.status == LeadStatus.siteVisit).length;
                final newLeads = projectLeads.where((l) => l.status == LeadStatus.newLead).length;
                final convRate = projectLeads.isEmpty ? 0.0 : (closedLeads / projectLeads.length) * 100;
                final salesTeam = projectUsers.where((u) => u.role == UserRole.sales).length;
                final adminUser = projectUsers.where((u) => u.role == UserRole.companyAdmin).firstOrNull;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(13)),
                              child: Center(child: Text(project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(project.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  Text(project.location, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                  if (adminUser != null) ...[
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      const Icon(Icons.person_outline_rounded, size: 11, color: AppColors.lavender),
                                      const SizedBox(width: 4),
                                      Text('Admin: ${adminUser.name}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.lavender)),
                                    ]),
                                  ],
                                ],
                              ),
                            ),
                            StatusPill(label: project.status.label, color: project.status.color, isSmall: true),
                          ],
                        ),
                      ),
                      // Stats grid
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _reportStat('Sales Team', '$salesTeam', AppColors.gradientTertiary),
                                _vDivider(),
                                _reportStat('Total Leads', '${projectLeads.length}', AppColors.gradientSecondary),
                                _vDivider(),
                                _reportStat('Closures', '$closedLeads', AppColors.gradientSuccess),
                                _vDivider(),
                                _reportStat('Conv.', '${convRate.toStringAsFixed(0)}%', AppColors.gradientCTA),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Mini lead pipeline
                            if (projectLeads.isNotEmpty) ...[
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Pipeline: ', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  _pipelinePill('New $newLeads', LeadStatus.newLead.color),
                                  const SizedBox(width: 4),
                                  _pipelinePill('Visit $siteVisits', LeadStatus.siteVisit.color),
                                  const SizedBox(width: 4),
                                  _pipelinePill('Closed $closedLeads', LeadStatus.closed.color),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _reportStat(String label, String value, LinearGradient grad) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => grad.createShader(b),
          child: Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _vDivider() => Container(width: 1, height: 30, color: AppColors.border);

  Widget _pipelinePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
}

// ─── Master Alert Sheet ───────────────────────────────────────────────────────
class _MasterAlertSheet extends StatefulWidget {
  final AppState state;
  const _MasterAlertSheet({required this.state});

  @override
  State<_MasterAlertSheet> createState() => _MasterAlertSheetState();
}

class _MasterAlertSheetState extends State<_MasterAlertSheet> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  NotificationPriority _priority = NotificationPriority.medium;
  String _target = "companyAdmins"; // companyAdmins or specific company
  String? _selectedCompanyId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (_titleCtrl.text.isEmpty || _msgCtrl.text.isEmpty) return;
    final state = widget.state;

    List<String> targetIds = [];
    // ignore: unused_local_variable
    String targetCompanyId = "";

    if (_target == "companyAdmins") {
      // Send to all company admins
      targetIds = state.users
          .where((u) => u.role == UserRole.companyAdmin && u.isApproved && u.isActive)
          .map((u) => u.id)
          .toList();
      targetCompanyId = "all";
    } else if (_selectedCompanyId != null) {
      // Send to admins of specific company
      targetIds = state.users
          .where((u) => u.companyId == _selectedCompanyId && u.role == UserRole.companyAdmin)
          .map((u) => u.id)
          .toList();
      targetCompanyId = _selectedCompanyId!;
    }

    if (targetIds.isEmpty) return;

    // Create a notification per project
    final projectsToNotify = _target == "companyAdmins"
        ? state.projects.toList()
        : state.projects.where((p) => p.id == _selectedCompanyId).toList();

    for (final project in projectsToNotify) {
      final projectAdminIds = targetIds.where((id) {
        final u = state.users.where((u) => u.id == id).isNotEmpty
            ? state.users.firstWhere((u) => u.id == id)
            : null;
        return u?.companyId == project.id;
      }).toList();

      if (projectAdminIds.isEmpty && _target != "companyAdmins") continue;

      final ids = _target == "companyAdmins" ? projectAdminIds : targetIds;
      if (ids.isEmpty) continue;

      final notif = CrmNotification(
        title: _titleCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
        createdById: state.currentUser!.id,
        createdByName: state.currentUser!.name,
        isForAll: false,
        targetUserIds: ids,
        priority: _priority,
        companyId: project.id,
        isAlert: true,
      );
      state.addNotification(notif);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          _target == "companyAdmins"
              ? "Alert sent to all Project Admins"
              : "Alert sent to ${state.projects.where((p) => p.id == _selectedCompanyId).isNotEmpty ? state.projects.firstWhere((p) => p.id == _selectedCompanyId).name : "project"} admin",
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ]),
      backgroundColor: const Color(0xFFD08020),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final projects = widget.state.projects.toList();
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(gradient: AppColors.gradientSecondary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_active_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Send Alert", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text("Alert will appear as popup to recipients", style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              )),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: "Alert Title *", prefixIcon: Icon(Icons.title_rounded, size: 18, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Message *", alignLabelWithHint: true, prefixIcon: Icon(Icons.message_outlined, size: 18, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 14),
            Text("Priority", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: NotificationPriority.values.map((p) {
              final colors = {
                NotificationPriority.high: AppColors.pink,
                NotificationPriority.medium: AppColors.peach,
                NotificationPriority.low: AppColors.mint
              };
              final c = colors[p]!;
              final sel = _priority == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? c.withValues(alpha: 0.2) : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? c : AppColors.border, width: sel ? 1.5 : 1),
                    ),
                    child: Text(p.name.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            Text("Send To", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _target = "companyAdmins"),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _target == "companyAdmins" ? AppColors.peach.withValues(alpha: 0.2) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _target == "companyAdmins" ? AppColors.peach : AppColors.border, width: _target == "companyAdmins" ? 1.5 : 1),
                  ),
                  child: Center(child: Text("All Project Admins", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _target = "specificCompany"),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _target == "specificCompany" ? AppColors.lavender.withValues(alpha: 0.2) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _target == "specificCompany" ? AppColors.lavender : AppColors.border, width: _target == "specificCompany" ? 1.5 : 1),
                  ),
                  child: Center(child: Text("Specific Project", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                ),
              )),
            ]),
            if (_target == "specificCompany") ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _selectedCompanyId == null ? AppColors.border : AppColors.lavender, width: _selectedCompanyId == null ? 1 : 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCompanyId,
                    hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("-- Choose project --", style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    borderRadius: BorderRadius.circular(14),
                    items: projects.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCompanyId = v),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(
              label: "Send Alert",
              onTap: _send,
              icon: Icons.send_rounded,
              gradient: AppColors.gradientSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
