import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import 'lead_detail_screen.dart';
import 'add_edit_lead_screen.dart';

class LeadListScreen extends StatefulWidget {
  final bool showBackButton;
  final String? projectFilter;
  const LeadListScreen({super.key, this.showBackButton = false, this.projectFilter});

  @override
  State<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends State<LeadListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  LeadStatus? _filterStatus;
  String _searchQuery = '';
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filter / sort for All-Leads tab ───────────────────────────────────────
  List<Lead> _filtered(List<Lead> leads) {
    var result = leads
        .where((l) => l.status != LeadStatus.closed)
        .toList(); // closed go to the other tab
    if (widget.projectFilter != null) {
      result = result
          .where((l) => l.projectName == widget.projectFilter)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result.where((l) =>
          l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.phone.contains(_searchQuery) ||
          l.projectName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_filterStatus != null) {
      result = result.where((l) => l.status == _filterStatus).toList();
    }
    switch (_sortBy) {
      case 'date':
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case 'name':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'status':
        result.sort((a, b) => a.status.order.compareTo(b.status.order));
        break;
    }
    return result;
  }

  // ── Closed leads for revenue tab ──────────────────────────────────────────
  List<Lead> _closedLeads(List<Lead> allLeads) {
    var result = allLeads.where((l) => l.status == LeadStatus.closed).toList();
    if (widget.projectFilter != null) {
      result = result
          .where((l) => l.projectName == widget.projectFilter)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result.where((l) =>
          l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.phone.contains(_searchQuery) ||
          l.projectName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allLeads = state.myLeads;
    final activeLeads = _filtered(allLeads);
    final closedLeads = _closedLeads(allLeads);
    final canGoBack = widget.showBackButton && Navigator.of(context).canPop();

    return SafeArea(
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      if (canGoBack)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36, height: 36,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 16, color: AppColors.textSecondary),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Leads',
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          if (widget.projectFilter != null)
                            Text(widget.projectFilter!,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.lavender,
                                    fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ]),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context, _slide(const AddEditLeadScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            gradient: AppColors.gradientCTA,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_rounded,
                              color: AppColors.textPrimary, size: 16),
                          const SizedBox(width: 4),
                          Text('Add Lead',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Shared search bar ─────────────────────────────────────
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, project...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.textMuted),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Tab bar ───────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      gradient: _tabCtrl.index == 1
                          ? AppColors.gradientSuccess
                          : AppColors.gradientCTA,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.list_alt_rounded, size: 14),
                            const SizedBox(width: 5),
                            Text('Active (${activeLeads.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on_rounded, size: 14),
                            const SizedBox(width: 5),
                            Text('Closed (${closedLeads.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ActiveLeadsTab(
                  leads: activeLeads,
                  filterStatus: _filterStatus,
                  sortBy: _sortBy,
                  isAdmin: state.isAdmin,
                  onFilterChanged: (s) => setState(() => _filterStatus = s),
                  onSortChanged: (s) => setState(() => _sortBy = s),
                  onTap: (lead) => Navigator.push(
                      context, _slide(LeadDetailScreen(lead: lead))),
                  onDelete: (lead) => _deleteLead(context, state, lead),
                ),
                _ClosedLeadsTab(
                  leads: closedLeads,
                  isAdmin: state.isAdmin,
                  onTap: (lead) => Navigator.push(
                      context, _slide(LeadDetailScreen(lead: lead))),
                  onDelete: (lead) => _deleteLead(context, state, lead),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete helper — shows confirm bottom sheet, then deletes ─────────────
  void _deleteLead(BuildContext context, AppState state, Lead lead) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 26, color: Color(0xFFD04060)),
            ),
            const SizedBox(height: 14),
            Text('Delete Lead?',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Permanently delete "${lead.name}"?\nThis action cannot be undone.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(child: Text('Cancel',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    state.deleteLead(lead.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text('"${lead.name}" deleted',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white))),
                      ]),
                      backgroundColor: const Color(0xFFD04060),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 3),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD04060),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text('Delete',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, b) => page,
        transitionsBuilder: (_, a, b, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Leads Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveLeadsTab extends StatelessWidget {
  final List<Lead> leads;
  final LeadStatus? filterStatus;
  final String sortBy;
  final bool isAdmin;
  final ValueChanged<LeadStatus?> onFilterChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<Lead> onTap;
  final ValueChanged<Lead> onDelete;

  const _ActiveLeadsTab({
    required this.leads,
    required this.filterStatus,
    required this.sortBy,
    required this.isAdmin,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status filter chips (exclude Closed — it's in its own tab)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _fchip(null, 'All', filterStatus, onFilterChanged),
                    const SizedBox(width: 6),
                    ...LeadStatus.values
                        .where((s) => s != LeadStatus.closed)
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child:
                                  _fchip(s, s.label, filterStatus, onFilterChanged),
                            )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Sort row
              Row(children: [
                Text('Sort:',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                _schip('date', 'Latest', sortBy, onSortChanged),
                const SizedBox(width: 6),
                _schip('name', 'Name', sortBy, onSortChanged),
                const SizedBox(width: 6),
                _schip('status', 'Stage', sortBy, onSortChanged),
                const Spacer(),
                Text('${leads.length} leads',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: leads.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_search_rounded,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('No active leads found',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textMuted)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: leads.length,
                  itemBuilder: (ctx, idx) {
                    final lead = leads[idx];
                    final card = Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LeadCard(lead: lead, onTap: () => onTap(lead)),
                    );
                    if (!isAdmin) return card;
                    return Dismissible(
                      key: ValueKey(lead.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        onDelete(lead);
                        return false; // never auto-remove; deletion handled via confirm sheet
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEF0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline_rounded, color: Color(0xFFD04060), size: 24),
                            const SizedBox(height: 4),
                            Text('Delete', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFD04060))),
                          ],
                        ),
                      ),
                      child: card,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _fchip(LeadStatus? status, String label, LeadStatus? current,
      ValueChanged<LeadStatus?> onChange) {
    final isActive = current == status;
    return GestureDetector(
      onTap: () => onChange(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive
              ? (status == null ? AppColors.gradientPrimary : null)
              : null,
          color: isActive && status != null
              ? status.color.withValues(alpha: 0.2)
              : isActive
                  ? null
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? (status?.color ?? AppColors.lavender).withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _schip(
      String val, String label, String current, ValueChanged<String> onChange) {
    final isActive = current == val;
    return GestureDetector(
      onTap: () => onChange(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.lavender.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive
                  ? AppColors.lavender.withValues(alpha: 0.4)
                  : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.textPrimary : AppColors.textMuted)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Closed Leads (Revenue) Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ClosedLeadsTab extends StatelessWidget {
  final List<Lead> leads;
  final bool isAdmin;
  final ValueChanged<Lead> onTap;
  final ValueChanged<Lead> onDelete;

  const _ClosedLeadsTab({
    required this.leads,
    required this.isAdmin,
    required this.onTap,
    required this.onDelete,
  });

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    // Revenue totals
    final totalRevenue =
        leads.fold<double>(0, (sum, l) => sum + (l.closedValue ?? 0));
    final saleLeads = leads.where((l) => l.leadType == LeadType.sale).toList();
    final leaseLeads = leads.where((l) => l.leadType == LeadType.lease).toList();
    final saleRevenue =
        saleLeads.fold<double>(0, (sum, l) => sum + (l.closedValue ?? 0));
    final leaseRevenue =
        leaseLeads.fold<double>(0, (sum, l) => sum + (l.closedValue ?? 0));
    final withValue = leads.where((l) => l.closedValue != null).length;

    // Group by project
    final byProject = <String, List<Lead>>{};
    for (final l in leads) {
      byProject.putIfAbsent(l.projectName, () => []).add(l);
    }

    return leads.isEmpty
        ? Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.monetization_on_outlined,
                  size: 52,
                  color: AppColors.textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('No closed leads yet',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Text('Mark a lead as Closed to see revenue here',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              // ── Revenue summary cards ──────────────────────────────────
              _RevenueCard(
                totalRevenue: totalRevenue,
                saleRevenue: saleRevenue,
                leaseRevenue: leaseRevenue,
                totalClosed: leads.length,
                saleCount: saleLeads.length,
                leaseCount: leaseLeads.length,
                withValue: withValue,
                fmt: _fmt,
              ),
              const SizedBox(height: 16),
              // ── Per-project breakdown ──────────────────────────────────
              if (byProject.length > 1) ...[
                Text('Revenue by Project',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...byProject.entries.map((e) {
                  final proj = e.key;
                  final pLeads = e.value;
                  final pRev = pLeads.fold<double>(
                      0, (s, l) => s + (l.closedValue ?? 0));
                  final pSale = pLeads
                      .where((l) => l.leadType == LeadType.sale)
                      .length;
                  final pLease = pLeads
                      .where((l) => l.leadType == LeadType.lease)
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientSuccess,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.apartment_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(proj,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(children: [
                                _TypeBadge(
                                    label: '$pSale Sale',
                                    color: LeadType.sale.color),
                                const SizedBox(width: 6),
                                _TypeBadge(
                                    label: '$pLease Lease',
                                    color: LeadType.lease.color),
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(pRev > 0 ? _fmt(pRev) : '—',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cyan)),
                            Text('${pLeads.length} deals',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
              // ── Individual closed lead cards ───────────────────────────
              Text('Closed Deals',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              ...leads.map((l) {
                final card = Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ClosedLeadCard(lead: l, onTap: () => onTap(l)),
                );
                if (!isAdmin) return card;
                return Dismissible(
                  key: ValueKey('closed_${l.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    onDelete(l);
                    return false;
                  },
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Color(0xFFD04060), size: 24),
                        const SizedBox(height: 4),
                        Text('Delete', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFD04060))),
                      ],
                    ),
                  ),
                  child: card,
                );
              }),
            ],
          );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Revenue Card (Summary)
// ─────────────────────────────────────────────────────────────────────────────
class _RevenueCard extends StatelessWidget {
  final double totalRevenue, saleRevenue, leaseRevenue;
  final int totalClosed, saleCount, leaseCount, withValue;
  final String Function(double) fmt;

  const _RevenueCard({
    required this.totalRevenue,
    required this.saleRevenue,
    required this.leaseRevenue,
    required this.totalClosed,
    required this.saleCount,
    required this.leaseCount,
    required this.withValue,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.gradientSuccess,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text('Total Closed Revenue',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
              Text(totalRevenue > 0 ? fmt(totalRevenue) : '—',
                  style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                '$totalClosed deal${totalClosed == 1 ? "" : "s"} closed'
                '${withValue < totalClosed ? " · $withValue with value" : ""}',
                style:
                    GoogleFonts.inter(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _MiniStat(
              label: 'Sale Revenue',
              value: saleRevenue > 0 ? fmt(saleRevenue) : '—',
              sub: '$saleCount deal${saleCount == 1 ? "" : "s"}',
              color: LeadType.sale.color,
              icon: Icons.sell_rounded,
              sublabel: null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
              label: 'Annual Lease',
              value: leaseRevenue > 0 ? fmt(leaseRevenue) : '—',
              sub: '$leaseCount deal${leaseCount == 1 ? "" : "s"}',
              color: LeadType.lease.color,
              icon: Icons.key_rounded,
              sublabel: leaseRevenue > 0 ? 'per year' : null,
            ),
          ),
        ]),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value, sub;
  final String? sublabel;
  final Color color;
  final IconData icon;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.sub,
      required this.color,
      required this.icon,
      this.sublabel});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (sublabel != null) ...[
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(sublabel!,
                        style: GoogleFonts.inter(
                            fontSize: 8,
                            color: AppColors.orange)),
                  ),
                ],
              ],
            ),
            Text(sub,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Closed Lead Card
// ─────────────────────────────────────────────────────────────────────────────
class _ClosedLeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;
  const _ClosedLeadCard({required this.lead, required this.onTap});

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        AvatarWidget(
            initials: lead.initials,
            size: 44,
            gradient: AppColors.gradientSuccess),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(lead.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                // Deal value badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientSuccess,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lead.closedValue != null
                            ? lead.closedValueDisplay
                            : 'No value',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      if (lead.leadType == LeadType.lease)
                        Text('annual',
                            style: GoogleFonts.inter(
                                fontSize: 8,
                                color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(lead.projectName,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              _TypeBadge(
                  label: lead.leadType.shortLabel,
                  color: lead.leadType.color),
              const SizedBox(width: 8),
              const Icon(Icons.phone_outlined,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(lead.phone,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(width: 8),
              const Icon(Icons.home_outlined, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(lead.propertyType.label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lead.assignedToName,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textMuted)),
                Text(_timeAgo(lead.updatedAt),
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ]),
        ),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Lead Card (existing _LeadCard, extended with lead-type badge)
// ─────────────────────────────────────────────────────────────────────────────
class _LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;
  const _LeadCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        AvatarWidget(
            initials: lead.initials, size: 44, gradient: _grad(lead.status)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(lead.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                StatusPill(
                    label: lead.status.label,
                    color: lead.status.color,
                    isSmall: true),
              ],
            ),
            const SizedBox(height: 3),
            Text(lead.projectName,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              // Lead type badge
              _TypeBadge(
                  label: lead.leadType.shortLabel, color: lead.leadType.color),
              const SizedBox(width: 8),
              const Icon(Icons.phone_outlined,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(lead.phone,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lead.budgetDisplay,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(_timeAgo(lead.updatedAt),
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ]),
        ),
      ]),
    );
  }

  LinearGradient _grad(LeadStatus s) {
    switch (s) {
      case LeadStatus.newLead:    return AppColors.gradientPrimary;
      case LeadStatus.contacted:  return AppColors.gradientTertiary;
      case LeadStatus.siteVisit:  return AppColors.gradientSecondary;
      case LeadStatus.negotiation: return AppColors.gradientPrimary;
      case LeadStatus.closed:     return AppColors.gradientSuccess;
      default:
        return const LinearGradient(
            colors: [Color(0xFFE0E0E8), Color(0xFFCCCCD8)]);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
