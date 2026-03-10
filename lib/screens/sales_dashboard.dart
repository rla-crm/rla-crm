import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import 'projects_screen.dart';
import 'lead_list_screen.dart';
import 'notifications_screen.dart';
import 'add_edit_lead_screen.dart';
import 'lead_detail_screen.dart';

class SalesDashboard extends StatefulWidget {
  const SalesDashboard({super.key});

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> with TickerProviderStateMixin {
  int _tab = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _tabs = ['Home', 'My Leads', 'Projects', 'Alerts'];
  static const _icons = [
    Icons.home_outlined,
    Icons.people_alt_outlined,
    Icons.apartment_outlined,
    Icons.notifications_outlined,
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
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        width: 260,
        child: _SalesSidebar(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: (i) { Navigator.pop(context); _switchTab(i); },
          unreadCount: state.unreadNotificationCount,
        ),
      ),
      body: _buildMobile(),
    );
  }

  Widget _buildWide() {
    final state = context.watch<AppState>();
    return Row(
      children: [
        _SalesSidebar(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: _switchTab,
          unreadCount: state.unreadNotificationCount,
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
        // Mobile top bar
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
                      Text(state.currentUser?.name ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(state.currentCompany?.name ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        _SalesBottomNav(
          tabs: _tabs.toList(),
          icons: _icons.toList(),
          current: _tab,
          onSelect: _switchTab,
          unreadCount: state.unreadNotificationCount,
        ),
      ],
    );
  }

  Widget _screen() {
    switch (_tab) {
      case 0: return const _SalesHome();
      case 1: return const LeadListScreen();
      case 2: return const ProjectsScreen();
      case 3: return const NotificationsScreen();
      default: return const _SalesHome();
    }
  }
}

// ─── Sales Sidebar ────────────────────────────────────────────────────────────
class _SalesSidebar extends StatelessWidget {
  final List<String> tabs;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;
  final int unreadCount;

  const _SalesSidebar({required this.tabs, required this.icons, required this.current, required this.onSelect, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final company = state.currentCompany;
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
                    decoration: BoxDecoration(gradient: AppColors.gradientTertiary, borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(company?.initials ?? 'C', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company?.name ?? 'Company', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Sales Team', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.sky.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarWidget(initials: state.currentUser?.initials ?? 'S', size: 18, gradient: AppColors.gradientTertiary),
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
                        gradient: sel ? AppColors.gradientTertiary : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(icons[i], size: 18, color: sel ? AppColors.textPrimary : AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tabs[i], style: GoogleFonts.inter(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.textPrimary : AppColors.textSecondary))),
                          if (i == 3 && unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: sel ? AppColors.textPrimary.withValues(alpha: 0.15) : AppColors.pink, borderRadius: BorderRadius.circular(10)),
                              child: Text('$unreadCount', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: sel ? AppColors.textPrimary : const Color(0xFFD04060))),
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

// ─── Sales Bottom Nav ─────────────────────────────────────────────────────────
class _SalesBottomNav extends StatelessWidget {
  final List<String> tabs;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;
  final int unreadCount;

  const _SalesBottomNav({required this.tabs, required this.icons, required this.current, required this.onSelect, required this.unreadCount});

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
                          Icon(icons[i], size: 20, color: sel ? AppColors.cyan : AppColors.textMuted),
                          if (i == 3 && unreadCount > 0)
                            Positioned(
                              top: -4, right: -8,
                              child: Container(
                                width: 14, height: 14,
                                decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                                child: Center(child: Text('$unreadCount', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(tabs[i], style: GoogleFonts.inter(fontSize: 10, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.cyan : AppColors.textMuted)),
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

// ─── Sales Home Screen ────────────────────────────────────────────────────────
class _SalesHome extends StatelessWidget {
  const _SalesHome();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myLeads = state.myLeads;
    final myProjects = state.myProjects;
    final closed = myLeads.where((l) => l.status == LeadStatus.closed).length;
    final siteVisits = myLeads.where((l) => l.status == LeadStatus.siteVisit).length;
    final recentLeads = state.myRecentLeads;

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
                      Text(state.currentUser?.name ?? 'Sales', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      if (state.currentCompany != null)
                        Text(state.currentCompany!.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.cyan, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showProfileSheet(context, state),
                  child: AvatarWidget(initials: state.currentUser?.initials ?? 'S', size: 44, gradient: AppColors.gradientTertiary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick-add lead button
            GradientButton(
              label: 'Add New Lead',
              icon: Icons.add_rounded,
              gradient: AppColors.gradientTertiary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEditLeadScreen())),
            ),
            const SizedBox(height: 16),

            // Stats grid
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
                  _stat('My Leads', myLeads.length.toString(), AppColors.gradientTertiary),
                  _stat('Closed', closed.toString(), AppColors.gradientSuccess),
                  _stat('Site Visits', siteVisits.toString(), AppColors.gradientSecondary),
                  _stat('Projects', myProjects.length.toString(), AppColors.gradientPrimary),
                ],
              );
            }),
            const SizedBox(height: 20),

            // Pipeline status
            SectionHeader(title: 'My Pipeline'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: LeadStatus.values.map((s) {
                  final count = myLeads.where((l) => l.status == s).length;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: s.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: s.color)),
                        const SizedBox(width: 5),
                        Text('${s.label}: $count', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // My projects
            if (myProjects.isNotEmpty) ...[
              SectionHeader(title: 'My Projects'),
              const SizedBox(height: 10),
              ...myProjects.map((p) => _projectTile(context, p, state)),
              const SizedBox(height: 20),
            ],

            // Recent leads
            SectionHeader(title: 'Recent Leads', action: 'View All'),
            const SizedBox(height: 10),
            ...recentLeads.map((l) => _leadCard(context, l)),

            // Upcoming site visits
            if (state.upcomingSiteVisits.where((l) => l.assignedToId == state.currentUser?.id).isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'My Site Visits'),
              const SizedBox(height: 10),
              ...state.upcomingSiteVisits
                  .where((l) => l.assignedToId == state.currentUser?.id)
                  .take(3)
                  .map((l) => _siteVisitCard(l)),
            ],

            // Follow-ups
            if (state.pendingFollowUps.where((l) => l.assignedToId == state.currentUser?.id).isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'Follow-ups Due'),
              const SizedBox(height: 10),
              ...state.pendingFollowUps
                  .where((l) => l.assignedToId == state.currentUser?.id)
                  .take(3)
                  .map((l) => _followUpCard(l)),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, LinearGradient grad) {
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

  Widget _projectTile(BuildContext context, RealEstateProject p, AppState state) {
    final pLeads = state.myLeadsForProject(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.lavender.withValues(alpha: 0.3), AppColors.pink.withValues(alpha: 0.2)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.apartment_outlined, size: 20, color: AppColors.lavender),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(p.location, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${pLeads.length} leads', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              StatusPill(label: p.status.label, color: p.status.color, isSmall: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leadCard(BuildContext context, Lead l) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: l))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            AvatarWidget(initials: l.initials, size: 36, gradient: AppColors.gradientTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
            Text(l.projectName, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
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
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(initials: state.currentUser?.initials ?? 'S', size: 60, gradient: AppColors.gradientTertiary),
            const SizedBox(height: 12),
            Text(state.currentUser?.name ?? '', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(state.currentUser?.email ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            StatusPill(label: 'Sales Agent', color: AppColors.sky),
            if (state.currentCompany != null) ...[
              const SizedBox(height: 6),
              Text(state.currentCompany!.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: 'Sign Out',
              onTap: () { Navigator.pop(context); state.logout(); },
              gradient: const LinearGradient(colors: [AppColors.sky, AppColors.cyan]),
              icon: Icons.logout_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
