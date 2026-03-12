import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import 'analytics_screen.dart';
import 'projects_screen.dart';
import 'lead_list_screen.dart';
import 'team_screen.dart';
import 'notifications_screen.dart';
import 'add_edit_lead_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  int _tab = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _tabs = ['Dashboard', 'Projects', 'Leads', 'Analytics', 'Alerts', 'Team', 'Approvals', 'Reports'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.apartment_outlined,
    Icons.people_alt_outlined,
    Icons.analytics_outlined,
    Icons.notifications_outlined,
    Icons.groups_outlined,
    Icons.pending_actions_outlined,
    Icons.bar_chart_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
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
        body: _buildWide(),
      );
    }
    // Mobile: use Drawer for sidebar access
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        width: 260,
        child: _AdminSidebar(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: (i) { Navigator.pop(context); _switchTab(i); },
          unreadCount: state.unreadNotificationCount,
          pendingApprovals: state.pendingApprovalCount,
        ),
      ),
      body: _buildMobile(),
    );
  }

  Widget _buildWide() {
    final state = context.watch<AppState>();
    return Row(
      children: [
        _AdminSidebar(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: _switchTab,
          unreadCount: state.unreadNotificationCount,
          pendingApprovals: state.pendingApprovalCount,
        ),
        Expanded(
          child: FadeTransition(opacity: _fadeAnim, child: _screen()),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    final state = context.watch<AppState>();
    return Column(
      children: [
        // Mobile top bar with hamburger menu
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
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.menu_rounded, size: 18, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.currentUser?.companyName ?? 'Project Admin', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(state.currentUser?.name ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
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
        Expanded(child: FadeTransition(opacity: _fadeAnim, child: _screen())),
        _AppBottomNav(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: _switchTab,
          unreadCount: state.unreadNotificationCount,
          pendingApprovals: state.pendingApprovalCount,
          accentColor: AppColors.lavender,
        ),
      ],
    );
  }

  Widget _screen() {
    switch (_tab) {
      case 0: return const _AdminHome();
      case 1: return const ProjectsScreen();
      case 2: return const LeadListScreen();
      case 3: return const AnalyticsScreen();
      case 4: return const NotificationsScreen();
      case 5: return const TeamScreen();
      case 6: return const _CompanyApprovalsScreen();
      case 7: return const _AdminReportsScreen();
      default: return const _AdminHome();
    }
  }
}

// ─── Shared Admin Sidebar ─────────────────────────────────────────────────────
class _AdminSidebar extends StatelessWidget {
  final List<String> tabs;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;
  final int unreadCount;
  final int pendingApprovals;

  const _AdminSidebar({required this.tabs, required this.icons, required this.current, required this.onSelect, required this.unreadCount, this.pendingApprovals = 0});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final projectName = state.currentUser?.companyName ?? 'Project';
    final adminName = state.currentUser?.name ?? '';
    final initials = state.currentUser?.initials ?? 'A';
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(2, 0))],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(initials, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(projectName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(adminName, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarWidget(initials: state.currentUser?.initials ?? 'A', size: 18, gradient: AppColors.gradientPrimary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(state.currentUser?.name ?? '', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: List.generate(tabs.length, (i) {
                  final sel = i == current;
                  return GestureDetector(
                    onTap: () => onSelect(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: sel ? AppColors.gradientPrimary : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(icons[i], size: 18, color: sel ? AppColors.textPrimary : AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tabs[i], style: GoogleFonts.inter(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.textPrimary : AppColors.textSecondary))),
                          if (i == 4 && unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: sel ? AppColors.textPrimary.withValues(alpha: 0.15) : AppColors.pink, borderRadius: BorderRadius.circular(10)),
                              child: Text('$unreadCount', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: sel ? AppColors.textPrimary : const Color(0xFFD04060))),
                            ),
                          if (i == 6 && pendingApprovals > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: sel ? AppColors.textPrimary.withValues(alpha: 0.15) : AppColors.peach, borderRadius: BorderRadius.circular(10)),
                              child: Text('$pendingApprovals', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: sel ? AppColors.textPrimary : const Color(0xFFD08020))),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1)),
            GestureDetector(
              onTap: () => context.read<AppState>().logout(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Text('Sign Out', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Bottom Nav ────────────────────────────────────────────────────────
class _AppBottomNav extends StatelessWidget {
  final List<String> tabs;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;
  final int unreadCount;
  final int pendingApprovals;
  final Color accentColor;

  const _AppBottomNav({required this.tabs, required this.icons, required this.current, required this.onSelect, required this.unreadCount, this.pendingApprovals = 0, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final sel = i == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(icons[i], size: 20, color: sel ? accentColor : AppColors.textMuted),
                          if (i == 4 && unreadCount > 0)
                            Positioned(
                              top: -4, right: -8,
                              child: Container(
                                width: 14, height: 14,
                                decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                                child: Center(child: Text('$unreadCount', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                              ),
                            ),
                          if (i == 6 && pendingApprovals > 0)
                            Positioned(
                              top: -4, right: -8,
                              child: Container(
                                width: 14, height: 14,
                                decoration: const BoxDecoration(color: AppColors.peach, shape: BoxShape.circle),
                                child: Center(child: Text('$pendingApprovals', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(tabs[i], style: GoogleFonts.inter(fontSize: 10, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? accentColor : AppColors.textMuted)),
                    ],
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

// ─── Admin Home ───────────────────────────────────────────────────────────────
class _AdminHome extends StatelessWidget {
  const _AdminHome();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final leads = state.companyLeads;
    final projects = state.companyProjects;
    final salesUsers = state.salesUsers;
    final byStatus = state.leadsByStatus;

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
                      Text(_greeting(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      Text(state.currentUser?.name ?? 'Admin', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      // Show project name under greeting
                      Builder(builder: (ctx) {
                        final label = state.currentUser?.companyName;
                        if (label == null || label.isEmpty) return const SizedBox.shrink();
                        return Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.lavender, fontWeight: FontWeight.w500));
                      }),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showProfileSheet(context, state),
                  child: AvatarWidget(initials: state.currentUser?.initials ?? 'A', size: 44, gradient: AppColors.gradientPrimary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Hero stats
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
                  _heroStat('Total Leads', leads.length.toString(), AppColors.gradientPrimary),
                  _heroStat('Closed', (byStatus[LeadStatus.closed] ?? 0).toString(), AppColors.gradientSuccess),
                  _heroStat('Conversion', '${state.conversionRate.toStringAsFixed(1)}%', AppColors.gradientSecondary),
                  _heroStat('Projects', projects.length.toString(), AppColors.gradientTertiary),
                ],
              );
            }),
            const SizedBox(height: 20),

            // Pipeline overview
            _pipelineSection(byStatus, leads.length),
            const SizedBox(height: 20),

            // Projects overview
            SectionHeader(title: 'Projects Overview', action: 'View All'),
            const SizedBox(height: 10),
            if (projects.isEmpty)
              _emptyCard('No projects yet')
            else
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: projects.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _ProjectMiniCard(project: projects[i], leads: state.companyLeads.where((l) => l.projectId == projects[i].id).length),
                ),
              ),
            const SizedBox(height: 20),

            // Team performance
            SectionHeader(title: 'Team Performance'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: salesUsers.map((u) {
                  final uLeads = leads.where((l) => l.assignedToId == u.id).length;
                  final uClosed = leads.where((l) => l.assignedToId == u.id && l.status == LeadStatus.closed).length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        AvatarWidget(initials: u.initials, size: 34, gradient: AppColors.gradientTertiary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              LinearProgressIndicator(
                                value: uLeads > 0 ? uClosed / uLeads : 0,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('$uClosed/$uLeads', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Recent leads
            SectionHeader(title: 'Recent Leads'),
            const SizedBox(height: 10),
            ...state.recentLeads.map((l) => _miniLeadCard(context, l)),

            // Upcoming site visits
            if (state.upcomingSiteVisits.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'Upcoming Site Visits'),
              const SizedBox(height: 10),
              ...state.upcomingSiteVisits.take(3).map((l) => _siteVisitCard(l)),
            ],

            // Follow-ups
            if (state.pendingFollowUps.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'Follow-ups Due'),
              const SizedBox(height: 10),
              ...state.pendingFollowUps.take(3).map((l) => _followUpCard(l)),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value, LinearGradient grad) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.12), grad.colors.last.withValues(alpha: 0.07)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grad.colors.first.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _pipelineSection(Map<LeadStatus, int> byStatus, int total) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pipeline Overview', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...LeadStatus.values.map((s) {
            final count = byStatus[s] ?? 0;
            final pct = total > 0 ? count / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(width: 72, child: Text(s.label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 6, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(height: 6, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 24, child: Text('$count', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      height: 80,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Center(child: Text(msg, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
    );
  }

  Widget _miniLeadCard(BuildContext context, Lead l) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditLeadScreen(lead: l))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            AvatarWidget(initials: l.initials, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(l.projectName, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            StatusPill(label: l.status.label, color: l.status.color, isSmall: true),
          ],
        ),
      ),
    );
  }

  Widget _siteVisitCard(Lead l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.stageSiteVisit.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stageSiteVisit.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.stageSiteVisit),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(l.projectName, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ])),
          Text(l.siteVisitDate ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _followUpCard(Lead l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_outlined, size: 16, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(l.assignedToName, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ])),
          Text(l.followUpDate ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _showProfileSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileSheet(state: state),
    );
  }
}

// ─── Project Mini Card ────────────────────────────────────────────────────────
class _ProjectMiniCard extends StatelessWidget {
  final RealEstateProject project;
  final int leads;
  const _ProjectMiniCard({required this.project, required this.leads});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.lavender.withValues(alpha: 0.15), AppColors.pink.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            StatusPill(label: project.status.label, color: project.status.color, isSmall: true),
          ]),
          const Spacer(),
          Text(project.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(project.location, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.people_alt_outlined, size: 11, color: AppColors.textMuted),
            const SizedBox(width: 3),
            Text('$leads leads', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ],
      ),
    );
  }
}

// ─── Company Approvals Screen (for Company Admins) ────────────────────────────
class _CompanyApprovalsScreen extends StatefulWidget {
  const _CompanyApprovalsScreen();

  @override
  State<_CompanyApprovalsScreen> createState() => _CompanyApprovalsScreenState();
}

class _CompanyApprovalsScreenState extends State<_CompanyApprovalsScreen>
    with SingleTickerProviderStateMixin {
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
    // Company-scoped approvals (type = employeeSignup)
    final myCompanyId = state.currentCompanyId;
    final pending = state.approvals.where((a) =>
        a.type == ApprovalType.employeeSignup &&
        a.status == ApprovalStatus.pending &&
        a.companyId == myCompanyId).toList();
    final approved = state.approvals.where((a) =>
        a.type == ApprovalType.employeeSignup &&
        a.status == ApprovalStatus.approved &&
        a.companyId == myCompanyId).toList();
    final rejected = state.approvals.where((a) =>
        a.type == ApprovalType.employeeSignup &&
        a.status == ApprovalStatus.rejected &&
        a.companyId == myCompanyId).toList();

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
                    Text('Sales Team Approvals', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Manage team member access requests', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
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
            indicatorColor: AppColors.lavender,
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
                _EmployeeApprovalList(approvals: pending, isPending: true),
                _EmployeeApprovalList(approvals: approved, isPending: false),
                _EmployeeApprovalList(approvals: rejected, isPending: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeApprovalList extends StatelessWidget {
  final List<ApprovalRequest> approvals;
  final bool isPending;
  const _EmployeeApprovalList({required this.approvals, required this.isPending});

  @override
  Widget build(BuildContext context) {
    if (approvals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(isPending ? 'No pending requests' : 'No records here', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: approvals.length,
      itemBuilder: (_, i) => _EmployeeApprovalCard(approval: approvals[i], isPending: isPending),
    );
  }
}

class _EmployeeApprovalCard extends StatelessWidget {
  final ApprovalRequest approval;
  final bool isPending;
  const _EmployeeApprovalCard({required this.approval, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final isAdminRequest = approval.role == 'admin';
    final grad = isAdminRequest ? AppColors.gradientPrimary : AppColors.gradientTertiary;

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
                  decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(
                    approval.applicantName.isNotEmpty ? approval.applicantName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(approval.applicantName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.mail_outline_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(approval.applicantEmail, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        StatusPill(label: isAdminRequest ? 'Project Admin' : 'Sales Team', color: isAdminRequest ? AppColors.lavender : AppColors.sky, isSmall: true),
                        const SizedBox(width: 6),
                        StatusPill(label: approval.status.label, color: approval.status.color, isSmall: true),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isPending)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Text(_timeAgo(approval.createdAt), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
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
                      child: Text('Decline', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFD04060))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => state.approveEmployeeSignup(approval.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(gradient: AppColors.gradientSuccess, borderRadius: BorderRadius.circular(10)),
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
        title: Text('Decline Request', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Decline signup for "${approval.applicantName}"?', style: GoogleFonts.inter(fontSize: 13)),
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
              state.rejectEmployeeSignup(approval.id, note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
            },
            child: Text('Decline', style: GoogleFonts.inter(color: Colors.red)),
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

// ─── Profile Sheet ────────────────────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final AppState state;
  const _ProfileSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final user = state.currentUser!;
    final projectName = user.companyName;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarWidget(initials: user.initials, size: 60, gradient: AppColors.gradientPrimary),
          const SizedBox(height: 12),
          Text(user.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(user.email, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          StatusPill(label: user.roleLabel, color: AppColors.lavender),
          if (projectName != null && projectName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(projectName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            StatusPill(label: 'Active', color: const Color(0xFFB8FFE4), isSmall: true),
          ],
          const SizedBox(height: 24),
          GradientButton(
            label: 'Sign Out',
            onTap: () { Navigator.pop(context); state.logout(); },
            gradient: const LinearGradient(colors: [AppColors.pink, Color(0xFFFFD4A8)]),
            icon: Icons.logout_rounded,
          ),
        ],
      ),
    );
  }
}

// ─── Admin Reports Screen ─────────────────────────────────────────────────────
class _AdminReportsScreen extends StatefulWidget {
  const _AdminReportsScreen();
  @override
  State<_AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<_AdminReportsScreen> {
  String? _selectedProjectId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-select if there's only one project
    if (_selectedProjectId == null) {
      final projects = context.read<AppState>().companyProjects;
      if (projects.length == 1) {
        _selectedProjectId = projects.first.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final projects = state.companyProjects;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reports', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Generate detailed project reports', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ])),
              if (_selectedProjectId != null)
                GradientButton(
                  label: 'Generate',
                  icon: Icons.picture_as_pdf_rounded,
                  height: 36,
                  onTap: () {
                    final project = projects.firstWhere((p) => p.id == _selectedProjectId);
                    _showReportSheet(context, state, project);
                  },
                  gradient: AppColors.gradientCTA,
                )
              else
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 14, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text('Generate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted.withValues(alpha: 0.5))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Select Project', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _selectedProjectId == null ? AppColors.border : AppColors.lavender, width: _selectedProjectId == null ? 1 : 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedProjectId,
                    hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('-- Select a project --', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    borderRadius: BorderRadius.circular(14),
                    items: projects.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(children: [
                          Container(width: 28, height: 28,
                            decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(7)),
                            child: Center(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedProjectId = v),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _selectedProjectId == null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bar_chart_rounded, size: 56, color: AppColors.textMuted.withValues(alpha: 0.3)),
                    const SizedBox(height: 14),
                    Text('Select a project above', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Text('to preview and generate report', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.7))),
                  ]))
                : _buildPreview(context, state, projects.firstWhere((p) => p.id == _selectedProjectId)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, AppState state, RealEstateProject project) {
    final leads = state.leads.where((l) => l.projectId == project.id).toList();
    final closedLeads = leads.where((l) => l.status == LeadStatus.closed).length;
    final siteVisits = leads.where((l) => l.status == LeadStatus.siteVisit).length;
    final convRate = leads.isEmpty ? 0.0 : (closedLeads / leads.length) * 100;
    final salesTeam = state.users.where((u) => project.assignedSalesIds.contains(u.id)).toList();
    final allActivities = <LeadActivity>[];
    for (final l in leads) { allActivities.addAll(l.activities); }
    allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.lavender.withValues(alpha: 0.15), AppColors.pink.withValues(alpha: 0.08)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(11)),
              child: Center(child: Text(project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(project.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(project.location, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              StatusPill(label: project.status.label, color: project.status.color, isSmall: true),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) => GridView.count(
          crossAxisCount: c.maxWidth > 400 ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6,
          children: [
            _kpiTile('Total Leads', '${leads.length}', AppColors.gradientPrimary),
            _kpiTile('Closed', '$closedLeads', AppColors.gradientSuccess),
            _kpiTile('Site Visits', '$siteVisits', AppColors.gradientTertiary),
            _kpiTile('Conv.%', '${convRate.toStringAsFixed(1)}%', AppColors.gradientCTA),
          ],
        )),
        const SizedBox(height: 12),
        Text('Sales Team', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        if (salesTeam.isEmpty)
          Text('No sales team assigned.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
        else
          ...salesTeam.map((u) {
            final uLeads = leads.where((l) => l.assignedToId == u.id).length;
            final uClosed = leads.where((l) => l.assignedToId == u.id && l.status == LeadStatus.closed).length;
            return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                AvatarWidget(initials: u.initials, size: 32, gradient: AppColors.gradientTertiary),
                const SizedBox(width: 10),
                Expanded(child: Text(u.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                Text('$uLeads leads · $uClosed closed', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            );
          }),
        const SizedBox(height: 12),
        Text('All Leads (${leads.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        if (leads.isEmpty)
          Text('No leads.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
        else
          ...leads.map((lead) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lead.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${lead.phone} · ${lead.assignedToName}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                Text(_fmtDate(lead.createdAt), style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
              ])),
              StatusPill(label: lead.status.label, color: lead.status.color, isSmall: true),
            ]),
          )),
        const SizedBox(height: 12),
        Text('Activity Log (${allActivities.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        if (allActivities.isEmpty)
          Text('No activity yet.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
        else
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(children: allActivities.take(30).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final act = entry.value;
              String leadName = '';
              try { leadName = leads.firstWhere((l) => l.id == act.leadId).name; } catch (_) {}
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: idx == 0 ? Colors.transparent : AppColors.border))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(act.action, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (leadName.isNotEmpty) Text('Lead: $leadName', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                    Text('By: ${act.userName}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                  ])),
                  Text(_fmtDateTime(act.timestamp), style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                ]),
              );
            }).toList()),
          ),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _kpiTile(String label, String value, LinearGradient grad) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.12), grad.colors.last.withValues(alpha: 0.07)]),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: grad.colors.first.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
    ]),
  );

  void _showReportSheet(BuildContext context, AppState state, RealEstateProject project) {
    final leads = state.leads.where((l) => l.projectId == project.id).toList();
    final salesTeam = state.users.where((u) => project.assignedSalesIds.contains(u.id)).toList();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _AdminReportSheet(project: project, leads: leads, salesTeam: salesTeam),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
  String _fmtDateTime(DateTime dt) => '${dt.day}/${dt.month}/${dt.year.toString().substring(2)} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

// ─── Admin Report Sheet (with RLA header + P&C footer) ────────────────────────
class _AdminReportSheet extends StatelessWidget {
  final RealEstateProject project;
  final List<Lead> leads;
  final List<AppUser> salesTeam;
  const _AdminReportSheet({required this.project, required this.leads, required this.salesTeam});

  @override
  Widget build(BuildContext context) {
    final closedLeads = leads.where((l) => l.status == LeadStatus.closed).length;
    final siteVisits = leads.where((l) => l.status == LeadStatus.siteVisit).length;
    final convRate = leads.isEmpty ? 0.0 : (closedLeads / leads.length) * 100;
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    final allActivities = <LeadActivity>[];
    for (final l in leads) { allActivities.addAll(l.activities); }
    allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 6), width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(children: [
            Text('Report Preview', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
          ])),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // RLA Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(11)),
                    child: Center(child: Text('R', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('RLA CRM', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0)),
                    Text('Real Estate · Leads · Growth', style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('PROJECT REPORT', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1.2)),
                    Text('$dateStr · $timeStr', style: GoogleFonts.inter(fontSize: 9, color: Colors.white.withValues(alpha: 0.7))),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              // Project Info
              _sectionTitle('Project Information'),
              const SizedBox(height: 10),
              _infoRow('Project Name', project.name),
              _infoRow('Location', project.location),
              if (project.developerName.isNotEmpty) _infoRow('Developer', project.developerName),
              if (project.reraNumber != null && project.reraNumber!.isNotEmpty) _infoRow('RERA No.', project.reraNumber!),
              _infoRow('Property Type', project.propertyType.label),
              _infoRow('Status', project.status.label),
              if (project.priceDisplay.isNotEmpty) _infoRow('Price Range', project.priceDisplay),
              const SizedBox(height: 16),
              // KPIs
              _sectionTitle('Performance Summary'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _kpiBox('Total', '${leads.length}', AppColors.lavender)),
                const SizedBox(width: 8),
                Expanded(child: _kpiBox('Visits', '$siteVisits', AppColors.sky)),
                const SizedBox(width: 8),
                Expanded(child: _kpiBox('Closed', '$closedLeads', AppColors.mint)),
                const SizedBox(width: 8),
                Expanded(child: _kpiBox('Conv.%', '${convRate.toStringAsFixed(1)}%', AppColors.peach)),
              ]),
              const SizedBox(height: 16),
              // Lead Status
              _sectionTitle('Lead Status Breakdown'),
              const SizedBox(height: 10),
              ...LeadStatus.values.map((s) {
                final cnt = leads.where((l) => l.status == s).length;
                return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  SizedBox(width: 90, child: Text(s.label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
                  Expanded(child: Stack(children: [
                    Container(height: 6, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
                    FractionallySizedBox(widthFactor: leads.isEmpty ? 0.0 : (cnt / leads.length).clamp(0.0, 1.0),
                      child: Container(height: 6, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)))),
                  ])),
                  const SizedBox(width: 8),
                  Text('$cnt', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ]));
              }),
              const SizedBox(height: 16),
              // Sales Team
              _sectionTitle('Sales Team Performance'),
              const SizedBox(height: 10),
              if (salesTeam.isEmpty)
                Text('No sales team assigned.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
              else
                ...salesTeam.map((u) {
                  final uLeads = leads.where((l) => l.assignedToId == u.id).length;
                  final uClosed = leads.where((l) => l.assignedToId == u.id && l.status == LeadStatus.closed).length;
                  final uVisits = leads.where((l) => l.assignedToId == u.id && l.status == LeadStatus.siteVisit).length;
                  return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      AvatarWidget(initials: u.initials, size: 32, gradient: AppColors.gradientTertiary),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(u.email, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$uLeads leads · $uClosed closed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('$uVisits visits', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                      ]),
                    ]),
                  );
                }),
              const SizedBox(height: 16),
              // All Leads
              _sectionTitle('All Leads (${leads.length})'),
              const SizedBox(height: 10),
              if (leads.isEmpty)
                Text('No leads.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
              else
                ...leads.map((lead) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lead.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('${lead.phone}${lead.email.isNotEmpty ? " · ${lead.email}" : ""}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                      Text('Assigned: ${lead.assignedToName} · ${_fmtDate(lead.createdAt)}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                      Text('Source: ${lead.source.label}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                    ])),
                    StatusPill(label: lead.status.label, color: lead.status.color, isSmall: true),
                  ]),
                )),
              const SizedBox(height: 16),
              // Activity Log
              _sectionTitle('Sales Activity Log (${allActivities.length})'),
              const SizedBox(height: 10),
              if (allActivities.isEmpty)
                Text('No activity recorded.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
              else
                ...allActivities.take(100).toList().asMap().entries.map((entry) {
                  final act = entry.value;
                  String leadName = '';
                  try { leadName = leads.firstWhere((l) => l.id == act.leadId).name; } catch (_) {}
                  return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(act.action, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        if (leadName.isNotEmpty) Text('Lead: $leadName', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                        Text('By: ${act.userName}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                        if (act.note != null && act.note!.isNotEmpty)
                          Text('Note: ${act.note}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                      ])),
                      Text(_fmtDateTime(act.timestamp), style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                    ]),
                  );
                }),
              const SizedBox(height: 24),
              // P&C Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text('Private & Confidential', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                    const SizedBox(width: 6),
                    const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                  ]),
                  const SizedBox(height: 4),
                  Text('This report is intended solely for authorised personnel of RLA CRM.', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted.withValues(alpha: 0.7)), textAlign: TextAlign.center),
                  Text('Unauthorised use, disclosure or distribution is strictly prohibited.', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted.withValues(alpha: 0.7)), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('Generated by RLA CRM · $dateStr', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted.withValues(alpha: 0.5))),
                ]),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Row(children: [
    Container(width: 3, height: 16, decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  ]);

  Widget _infoRow(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
      Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
    ]));

  Widget _kpiBox(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(children: [
      Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
    ]),
  );

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
  String _fmtDateTime(DateTime dt) => '${dt.day}/${dt.month}/${dt.year.toString().substring(2)} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}
