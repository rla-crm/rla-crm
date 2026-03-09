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

  static const _tabs = ['Overview', 'Approvals', 'Companies', 'Projects', 'Subscriptions', 'Users', 'Analytics'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.pending_actions_outlined,
    Icons.business_outlined,
    Icons.apartment_outlined,
    Icons.monetization_on_outlined,
    Icons.people_outline_rounded,
    Icons.analytics_outlined,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: isWide ? _buildWideLayout() : _buildMobileLayout(),
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
      case 2: return const _CompaniesScreen();
      case 3: return const _MasterProjectsScreen();
      case 4: return const _SubscriptionDashboard();
      case 5: return const _AllUsersScreen();
      case 6: return const _MasterAnalyticsScreen();
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
          height: 56,
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
                          Icon(icons[i], size: 20, color: sel ? AppColors.peach : AppColors.textMuted),
                          if (i == 1 && pendingApprovals > 0)
                            Positioned(
                              top: -4, right: -8,
                              child: Container(
                                width: 14, height: 14,
                                decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                                child: Center(child: Text('$pendingApprovals', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(tabs[i], style: GoogleFonts.inter(fontSize: 9, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.peach : AppColors.textMuted)),
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

// ─── Overview ─────────────────────────────────────────────────────────────────
class _MasterOverview extends StatelessWidget {
  const _MasterOverview();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.masterAdminPendingApprovals;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // Stats grid
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
                  _statCard('Total Companies', state.totalCompanies.toString(), Icons.business_outlined, AppColors.gradientSecondary),
                  _statCard('Active', state.activeCompanies.toString(), Icons.check_circle_outline_rounded, AppColors.gradientSuccess),
                  _statCard('Total Users', state.totalAllUsers.toString(), Icons.people_outline_rounded, AppColors.gradientPrimary),
                  _statCard('Total Leads', state.totalAllLeads.toString(), Icons.trending_up_rounded, AppColors.gradientTertiary),
                ],
              );
            }),
            const SizedBox(height: 24),

            // Quick revenue snapshot (summary only - full details in Subscriptions tab)
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          ShaderMask(shaderCallback: (b) => AppColors.gradientSuccess.createShader(b), child: const Icon(Icons.attach_money_rounded, size: 16, color: Colors.white)),
                          const SizedBox(width: 6),
                          Text('Monthly Revenue', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                        const SizedBox(height: 4),
                        Text('₹${_fmt(state.actualMonthlyRevenue)}/mo', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text('${state.paidCompanies.length} paid companies', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 50, color: AppColors.border),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            ShaderMask(shaderCallback: (b) => AppColors.gradientTertiary.createShader(b), child: const Icon(Icons.trending_up_rounded, size: 16, color: Colors.white)),
                            const SizedBox(width: 6),
                            Text('Prospect Revenue', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                          ]),
                          const SizedBox(height: 4),
                          Text('₹${_fmt(state.prospectMonthlyRevenue)}/mo', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          Text('${state.trialCompanies.length} on trial', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Recent Companies', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...state.recentCompanies.map((c) => _companyRow(context, c)),
          ],
        ),
      ),
    );
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
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              StatusPill(label: c.plan.label, color: c.plan.color, isSmall: true),
              const SizedBox(height: 4),
              StatusPill(label: c.isActive ? 'Active' : 'Inactive', color: c.isActive ? AppColors.mint : AppColors.stageLost, isSmall: true),
            ]),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
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

// ─── Subscription / Revenue Dashboard ────────────────────────────────────────
class _SubscriptionDashboard extends StatefulWidget {
  const _SubscriptionDashboard();

  @override
  State<_SubscriptionDashboard> createState() => _SubscriptionDashboardState();
}

class _SubscriptionDashboardState extends State<_SubscriptionDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final actual = state.actualMonthlyRevenue;
    final prospect = state.prospectMonthlyRevenue;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subscription Revenue', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Revenue tracking & trial management', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                // Revenue summary cards
                Row(
                  children: [
                    Expanded(child: _revenueCard('Actual Revenue', '₹${_fmt(actual)}/mo', '${state.paidCompanies.length} paid companies', AppColors.gradientSuccess, Icons.attach_money_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _revenueCard('Prospect Revenue', '₹${_fmt(prospect)}/mo', '${state.trialCompanies.length} on trial', AppColors.gradientTertiary, Icons.trending_up_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                // Subscription plan breakdown
                Text('Plan Distribution', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: SubscriptionPlan.values.map((plan) {
                      final count = state.companiesByPlan[plan] ?? 0;
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: plan.color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: plan.color.withValues(alpha: 0.4)),
                              ),
                              child: Center(child: Text('$count', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                            ),
                            const SizedBox(height: 4),
                            Text(plan.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.center),
                            Text(plan.price, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted), textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabCtrl,
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.teal,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: 'Actual Revenue (${state.paidCompanies.length})'),
              Tab(text: 'Prospects (${state.trialCompanies.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _CompanyRevenueList(companies: state.paidCompanies, isActual: true),
                _CompanyRevenueList(companies: state.trialCompanies, isActual: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard(String title, String amount, String sub, LinearGradient grad, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.15), grad.colors.last.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grad.colors.first.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ShaderMask(shaderCallback: (b) => grad.createShader(b), child: Icon(icon, size: 18, color: Colors.white)),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
          ]),
          const SizedBox(height: 8),
          Text(amount, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _CompanyRevenueList extends StatelessWidget {
  final List<Company> companies;
  final bool isActual;
  const _CompanyRevenueList({required this.companies, required this.isActual});

  @override
  Widget build(BuildContext context) {
    if (companies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActual ? Icons.monetization_on_outlined : Icons.hourglass_empty_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(isActual ? 'No paid companies yet' : 'No companies on trial', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: companies.length,
      itemBuilder: (ctx, i) => _CompanyRevenueCard(company: companies[i], isActual: isActual),
    );
  }
}

class _CompanyRevenueCard extends StatelessWidget {
  final Company company;
  final bool isActual;
  const _CompanyRevenueCard({required this.company, required this.isActual});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final userCount = state.usersForCompany(company.id);
    final leadCount = state.leadsForCompany(company.id);

    return GestureDetector(
      onTap: () => _showDetails(context, state, userCount, leadCount),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarWidget(initials: company.initials, size: 44, gradient: isActual ? AppColors.gradientSuccess : AppColors.gradientTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(company.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(company.adminEmail, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          StatusPill(label: company.plan.label, color: company.plan.color, isSmall: true),
                          const SizedBox(width: 6),
                          if (isActual)
                            Text(company.plan.price, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.teal))
                          else
                            Text('${company.trialDaysLeft} days left', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: company.trialDaysLeft < 5 ? const Color(0xFFD04060) : AppColors.orange)),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
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
                  _statChip(Icons.people_outline, '$userCount users'),
                  const SizedBox(width: 14),
                  _statChip(Icons.trending_up_rounded, '$leadCount leads'),
                  const SizedBox(width: 14),
                  _statChip(Icons.calendar_today_outlined, '${company.daysElapsed}d on platform'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
    ]);
  }

  void _showDetails(BuildContext context, AppState state, int userCount, int leadCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyDetailSheet(company: company),
    );
  }
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
                        StatusPill(label: company.plan.label, color: company.plan.color, isSmall: true),
                        const SizedBox(width: 6),
                        Text(company.plan.price, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
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
                _actionBtn(Icons.tune_rounded, AppColors.lavender, () => _showPlanSelector(context)),
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

  void _showPlanSelector(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => _PlanSelectorSheet(company: company));
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

class _PlanSelectorSheet extends StatelessWidget {
  final Company company;
  const _PlanSelectorSheet({required this.company});

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
          Text('Change Plan – ${company.name}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...SubscriptionPlan.values.map((plan) => GestureDetector(
            onTap: () { context.read<AppState>().updateCompanyPlan(company.id, plan); Navigator.pop(context); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: company.plan == plan ? plan.color.withValues(alpha: 0.2) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: company.plan == plan ? plan.color : AppColors.border, width: company.plan == plan ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: plan.color)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(plan.label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  Text(plan.price, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(width: 10),
                  Text('Max ${plan.maxUsers} users', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  if (company.plan == plan) ...[const SizedBox(width: 8), const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF3B8A6E))],
                ],
              ),
            ),
          )),
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
              StatusPill(label: company.plan.label, color: company.plan.color),
              const SizedBox(width: 8),
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
                  _infoBadge('Days Elapsed', '${company.daysElapsed}'),
                  if (company.plan == SubscriptionPlan.trial)
                    _infoBadge('Trial Left', '${company.trialDaysLeft} days'),
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
  SubscriptionPlan _plan = SubscriptionPlan.trial;
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
      plan: _plan,
      isApproved: true,
      trialStartDate: DateTime.now(),
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
            const SizedBox(height: 14),
            Text('Subscription Plan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: SubscriptionPlan.values.map((p) => GestureDetector(
                onTap: () => setState(() => _plan = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _plan == p ? p.color.withValues(alpha: 0.2) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _plan == p ? p.color : AppColors.border, width: _plan == p ? 1.5 : 1),
                  ),
                  child: Text(p.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                ),
              )).toList(),
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
                Expanded(child: Text('This user will have complete platform access including all companies, approvals, and user management.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD08020)))),
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
  String? _selectedCompanyId;

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
    if (_selectedCompanyId == null) {
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
      companyId: _selectedCompanyId!,
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
    final companies = context.read<AppState>().companies.where((c) => c.isApproved && c.isActive).toList();
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
                border: Border.all(color: _selectedCompanyId == null ? AppColors.border : AppColors.lavender,
                    width: _selectedCompanyId == null ? 1 : 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCompanyId,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('-- Choose project --', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  borderRadius: BorderRadius.circular(14),
                  items: companies.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(7)),
                            child: Center(child: Text(c.initials, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                          const SizedBox(width: 10),
                          Text(c.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCompanyId = v),
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

  void _showProjectSheet(BuildContext context, AppState state, RealEstateProject? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    final devCtrl = TextEditingController(text: existing?.developerName ?? '');
    final priceFromCtrl = TextEditingController(text: existing?.priceFrom?.toStringAsFixed(0) ?? '');
    final priceToCtrl = TextEditingController(text: existing?.priceTo?.toStringAsFixed(0) ?? '');
    PropertyType propType = existing?.propertyType ?? PropertyType.apartment;
    ProjectStatus projStatus = existing?.status ?? ProjectStatus.active;
    List<String> assignedIds = List.from(existing?.assignedSalesIds ?? []);
    String? selectedCompanyId = existing?.companyId.isNotEmpty == true ? existing!.companyId : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final salesForSheet = selectedCompanyId != null
              ? state.users.where((u) => u.companyId == selectedCompanyId && u.role == UserRole.sales && u.isApproved).toList()
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
                          Text('Assign to Company *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: selectedCompanyId == null ? AppColors.border : AppColors.lavender, width: selectedCompanyId == null ? 1 : 1.5)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCompanyId,
                                hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('-- Select company --', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                                isExpanded: true,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                borderRadius: BorderRadius.circular(14),
                                items: state.companies.where((c) => c.isApproved && c.isActive).map((c) =>
                                  DropdownMenuItem(value: c.id, child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(children: [
                                      Container(width: 28, height: 28, decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(7)),
                                          child: Center(child: Text(c.initials, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)))),
                                      const SizedBox(width: 10),
                                      Text(c.name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
                                    ]),
                                  )),
                                ).toList(),
                                onChanged: (v) => setS(() { selectedCompanyId = v; assignedIds.clear(); }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 16),
                          Text('Assign Sales Team', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          if (selectedCompanyId == null)
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.peach.withValues(alpha: 0.3))),
                              child: Text('Select a company above to assign sales team members.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)))
                          else if (salesForSheet.isEmpty)
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: Text('No approved sales team members in this company.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)))
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
                          const SizedBox(height: 20),
                          GradientButton(
                            label: existing == null ? 'Create Project' : 'Update Project',
                            icon: existing == null ? Icons.add_rounded : Icons.check_rounded,
                            onTap: () {
                              if (nameCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty) return;
                              final companyId = selectedCompanyId ?? '';
                              if (companyId.isEmpty) return;
                              if (existing == null) {
                                state.addProject(RealEstateProject(
                                  name: nameCtrl.text.trim(), location: locCtrl.text.trim(),
                                  developerName: devCtrl.text.trim(),
                                  priceFrom: double.tryParse(priceFromCtrl.text), priceTo: double.tryParse(priceToCtrl.text),
                                  propertyType: propType, assignedSalesIds: assignedIds,
                                  createdById: state.currentUser!.id, createdByName: state.currentUser!.name,
                                  companyId: companyId,
                                ));
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
                      Text('${state.projects.length} projects across all companies', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
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
                      Company? company;
                      try { company = state.companies.firstWhere((c) => c.id == p.companyId); } catch (_) {}
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
                                  if (company != null)
                                    Row(children: [
                                      const Icon(Icons.business_outlined, size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(company.name, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
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
class _MasterAnalyticsScreen extends StatelessWidget {
  const _MasterAnalyticsScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final companies = state.companies;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Analytics', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Cross-company performance overview', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _kpiCard('Companies', state.totalCompanies.toString(), AppColors.gradientSecondary),
                  _kpiCard('Users', state.totalAllUsers.toString(), AppColors.gradientPrimary),
                  _kpiCard('Leads', state.totalAllLeads.toString(), AppColors.gradientTertiary),
                  _kpiCard('Active', state.activeCompanies.toString(), AppColors.gradientSuccess),
                  _kpiCard('Paid', state.paidCompanies.length.toString(), AppColors.gradientCTA),
                  _kpiCard('On Trial', state.trialCompanies.length.toString(), const LinearGradient(colors: [AppColors.sky, AppColors.teal])),
                ],
              );
            }),
            const SizedBox(height: 24),
            Text('Per-Company Stats', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.lavender.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      _th('Company', flex: 3),
                      _th('Plan', flex: 2),
                      _th('Users', flex: 1),
                      _th('Leads', flex: 1),
                      _th('Status', flex: 2),
                    ]),
                  ),
                  ...companies.asMap().entries.map((e) {
                    final c = e.value;
                    final uCount = state.users.where((u) => u.companyId == c.id).length;
                    final lCount = state.leads.where((l) => l.companyId == c.id).length;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(c.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
                        Expanded(flex: 2, child: StatusPill(label: c.plan.label, color: c.plan.color, isSmall: true)),
                        Expanded(flex: 1, child: Text('$uCount', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary))),
                        Expanded(flex: 1, child: Text('$lCount', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary))),
                        Expanded(flex: 2, child: StatusPill(label: c.isActive ? 'Active' : 'Inactive', color: c.isActive ? AppColors.mint : AppColors.stageLost, isSmall: true)),
                      ]),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, LinearGradient grad) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.15), grad.colors.last.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grad.colors.first.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _th(String t, {int flex = 1}) => Expanded(flex: flex, child: Text(t, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)));
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

    // Create a notification per company (grouped by companyId)
    final companies = _target == "companyAdmins"
        ? state.companies.where((c) => c.isApproved && c.isActive).toList()
        : state.companies.where((c) => c.id == _selectedCompanyId).toList();

    for (final company in companies) {
      final companyAdminIds = targetIds.where((id) {
        final u = state.users.where((u) => u.id == id).isNotEmpty
            ? state.users.firstWhere((u) => u.id == id)
            : null;
        return u?.companyId == company.id;
      }).toList();

      if (companyAdminIds.isEmpty && _target != "companyAdmins") continue;

      final ids = _target == "companyAdmins" ? companyAdminIds : targetIds;
      if (ids.isEmpty) continue;

      final notif = CrmNotification(
        title: _titleCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
        createdById: state.currentUser!.id,
        createdByName: state.currentUser!.name,
        isForAll: false,
        targetUserIds: ids,
        priority: _priority,
        companyId: company.id,
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
              : "Alert sent to ${state.companies.where((c) => c.id == _selectedCompanyId).isNotEmpty ? state.companies.firstWhere((c) => c.id == _selectedCompanyId).name : "company"} admin",
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
    final companies = widget.state.companies.where((c) => c.isApproved && c.isActive).toList();
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
                  child: Center(child: Text("Specific Company", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
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
                    hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("-- Choose company --", style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    borderRadius: BorderRadius.circular(14),
                    items: companies.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(c.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
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
