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
  final String? projectFilter; // optional project name to pre-filter
  const LeadListScreen({super.key, this.showBackButton = false, this.projectFilter});

  @override
  State<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends State<LeadListScreen> {
  final _searchCtrl = TextEditingController();
  LeadStatus? _filterStatus;
  String _searchQuery = '';
  String _sortBy = 'date';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Lead> _filtered(List<Lead> leads) {
    var result = leads;
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final leads = _filtered(state.myLeads);
    final canGoBack = widget.showBackButton && Navigator.of(context).canPop();

    return SafeArea(
      child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (canGoBack) ...
                            [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 36, height: 36,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Leads', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              if (widget.projectFilter != null)
                                Text(widget.projectFilter!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.lavender, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, _slide(const AddEditLeadScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(gradient: AppColors.gradientCTA, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 16),
                              const SizedBox(width: 4),
                              Text('Add Lead', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text('${leads.length} total',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 14),
                  // Search
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search name, phone, project...',
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(null, 'All'),
                        const SizedBox(width: 6),
                        ...LeadStatus.values.map((s) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _filterChip(s, s.label),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Sort row
                  Row(
                    children: [
                      Text('Sort:',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      _sortChip('date', 'Latest'),
                      const SizedBox(width: 6),
                      _sortChip('name', 'Name'),
                      const SizedBox(width: 6),
                      _sortChip('status', 'Stage'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // List
            Expanded(
              child: leads.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded,
                              size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('No leads found',
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: leads.length,
                      itemBuilder: (ctx, idx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LeadCard(
                          lead: leads[idx],
                          onTap: () =>
                              Navigator.push(context, _slide(LeadDetailScreen(lead: leads[idx]))),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
  }

  Widget _filterChip(LeadStatus? status, String label) {
    final isActive = _filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient:
              isActive ? (status == null ? AppColors.gradientPrimary : null) : null,
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
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _sortChip(String val, String label) {
    final isActive = _sortBy == val;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.lavender.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive ? AppColors.lavender.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.textPrimary : AppColors.textMuted)),
      ),
    );
  }

  PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, b) => page,
        transitionsBuilder: (_, a, b, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;

  const _LeadCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AvatarWidget(initials: lead.initials, size: 44, gradient: _grad(lead.status)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    StatusPill(label: lead.status.label, color: lead.status.color, isSmall: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(lead.projectName,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(lead.phone,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(width: 10),
                    Icon(Icons.home_outlined, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(lead.propertyType.label,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
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
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _grad(LeadStatus s) {
    switch (s) {
      case LeadStatus.newLead:
        return AppColors.gradientPrimary;
      case LeadStatus.contacted:
        return AppColors.gradientTertiary;
      case LeadStatus.siteVisit:
        return AppColors.gradientSecondary;
      case LeadStatus.negotiation:
        return AppColors.gradientPrimary;
      case LeadStatus.closed:
        return AppColors.gradientSuccess;
      default:
        return const LinearGradient(colors: [Color(0xFFE0E0E8), Color(0xFFCCCCD8)]);
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
