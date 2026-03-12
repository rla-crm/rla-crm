import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import 'lead_list_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  ProjectStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    var projects = state.isMasterAdmin ? state.projects : state.myProjects;
    if (_filter != null) projects = projects.where((p) => p.status == _filter).toList();

    return SafeArea(
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Projects', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      if (state.isAdmin)
                        GestureDetector(
                          onTap: () => _showProjectSheet(context, state, null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(gradient: AppColors.gradientCTA, borderRadius: BorderRadius.circular(12)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text('New Project', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${projects.length} ${_filter?.label ?? 'total'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _fchip(null, 'All'),
                        const SizedBox(width: 6),
                        ...ProjectStatus.values.map((s) => Padding(padding: const EdgeInsets.only(right: 6), child: _fchip(s, s.label))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: projects.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.apartment_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(state.isAdmin ? 'No projects yet. Tap + to add.' : 'No projects assigned to you.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: projects.length,
                      itemBuilder: (ctx, idx) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ProjectCard(
                          project: projects[idx],
                          state: state,
                          onEdit: state.isAdmin ? () => _showProjectSheet(context, state, projects[idx]) : null,
                          onDelete: state.isAdmin ? () => _confirmDelete(context, state, projects[idx]) : null,
                          onViewLeads: () => Navigator.push(context, _slide(
                            LeadListScreen(showBackButton: true, projectFilter: projects[idx].name),
                          )),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
  }

  Widget _fchip(ProjectStatus? s, String label) {
    final isActive = _filter == s;
    return GestureDetector(
      onTap: () => setState(() => _filter = s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.gradientCTA : null,
          color: isActive ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.transparent : AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.textPrimary : AppColors.textPrimary)),
      ),
    );
  }

  void _showProjectSheet(BuildContext context, AppState state, RealEstateProject? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final devCtrl = TextEditingController(text: existing?.developerName ?? '');
    final reraCtrl = TextEditingController(text: existing?.reraNumber ?? '');
    final unitsCtrl = TextEditingController(text: existing?.totalUnits.toString() ?? '');
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
          // Sales users for this project:
          // - Project admin: use companyUsers who are sales & approved
          // - Master admin editing existing project: users whose companyId == project.id
          // - Master admin creating new project: no sales to assign yet (done after admin is assigned)
          final List<AppUser> salesForSheet = state.isMasterAdmin
              ? (existing != null
                  ? state.users.where((u) =>
                      (u.companyId == existing.id || u.companyId == existing.companyId) &&
                      u.role == UserRole.sales &&
                      u.isApproved).toList()
                  : [])
              : state.salesUsers;

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
                          _sheetField(nameCtrl, 'Project Name *', Icons.apartment_outlined),
                          const SizedBox(height: 12),
                          _sheetField(locCtrl, 'Location *', Icons.location_on_outlined),
                          const SizedBox(height: 12),
                          _sheetField(devCtrl, 'Developer Name', Icons.business_outlined),
                          const SizedBox(height: 12),
                          _sheetField(reraCtrl, 'RERA Number', Icons.verified_outlined),
                          const SizedBox(height: 12),
                          _sheetField(unitsCtrl, 'Total Units', Icons.grid_view_rounded, type: TextInputType.number),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _sheetField(priceFromCtrl, 'Price From (₹)', Icons.currency_rupee_rounded, type: TextInputType.number)),
                            const SizedBox(width: 10),
                            Expanded(child: _sheetField(priceToCtrl, 'Price To (₹)', Icons.currency_rupee_rounded, type: TextInputType.number)),
                          ]),
                          const SizedBox(height: 14),
                          TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.notes_rounded, size: 17, color: AppColors.textMuted)), alignLabelWithHint: true)),
                          const SizedBox(height: 16),
                          Text('Property Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: PropertyType.values.map((t) {
                            final ia = propType == t;
                            return GestureDetector(
                              onTap: () => setS(() => propType = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(gradient: ia ? AppColors.gradientSecondary : null, color: ia ? null : AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: ia ? Colors.transparent : AppColors.border)),
                                child: Text(t.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: ia ? FontWeight.w600 : FontWeight.w400, color: ia ? AppColors.textPrimary : AppColors.textSecondary)),
                              ),
                            );
                          }).toList()),
                          const SizedBox(height: 16),
                          if (existing != null) ...[
                            Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Row(children: ProjectStatus.values.map((s) {
                              final ia = projStatus == s;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setS(() => projStatus = s),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(color: ia ? s.color.withValues(alpha: 0.2) : AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: ia ? s.color.withValues(alpha: 0.5) : AppColors.border)),
                                    child: Text(s.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: ia ? FontWeight.w600 : FontWeight.w400, color: ia ? _darken(s.color) : AppColors.textSecondary)),
                                  ),
                                ),
                              );
                            }).toList()),
                            const SizedBox(height: 16),
                          ],
                          Text('Assign Sales Team', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          if (state.isMasterAdmin && existing == null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.sky.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.sky.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.sky),
                                const SizedBox(width: 8),
                                Expanded(child: Text(
                                  'Sales team can be assigned after creating the project and assigning a Project Admin.',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                )),
                              ]),
                            )
                          else if (salesForSheet.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: Text('No approved sales team members yet.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            )
                          else
                            ...salesForSheet.map((u) {
                              final isSel = assignedIds.contains(u.id);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: GestureDetector(
                                  onTap: () => setS(() { if (isSel) assignedIds.remove(u.id); else assignedIds.add(u.id); }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(color: isSel ? AppColors.lavender.withValues(alpha: 0.1) : AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSel ? AppColors.lavender.withValues(alpha: 0.5) : AppColors.border)),
                                    child: Row(children: [
                                      AvatarWidget(initials: u.initials, size: 32, gradient: AppColors.gradientTertiary),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(u.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: isSel ? FontWeight.w600 : FontWeight.w400, color: AppColors.textPrimary))),
                                      if (isSel) const Icon(Icons.check_circle_rounded, color: AppColors.lavender, size: 18),
                                    ]),
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: existing == null ? 'Create Project' : 'Update Project',
                            icon: existing == null ? Icons.add_rounded : Icons.check_rounded,
                            onTap: () {
                              if (nameCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty) return;
                              // companyId logic:
                              // - Master admin creating new: use 'rla_platform' placeholder.
                              //   When addProjectAdmin is called later, the project's companyId
                              //   gets updated to project.id, making it visible to that admin.
                              // - Master admin editing existing: preserve existing companyId.
                              // - Project admin: use their own currentCompanyId (== their projectId).
                              final companyId = state.isMasterAdmin
                                  ? (existing?.companyId ?? 'rla_platform')
                                  : (state.currentCompanyId ?? 'rla_platform');
                              if (existing == null) {
                                state.addProject(RealEstateProject(
                                  name: nameCtrl.text.trim(), location: locCtrl.text.trim(),
                                  description: descCtrl.text.trim(), developerName: devCtrl.text.trim(),
                                  reraNumber: reraCtrl.text.trim().isEmpty ? null : reraCtrl.text.trim(),
                                  totalUnits: int.tryParse(unitsCtrl.text) ?? 0,
                                  priceFrom: double.tryParse(priceFromCtrl.text), priceTo: double.tryParse(priceToCtrl.text),
                                  propertyType: propType, assignedSalesIds: assignedIds,
                                  createdById: state.currentUser!.id, createdByName: state.currentUser!.name,
                                  companyId: companyId,
                                ));
                              } else {
                                existing.name = nameCtrl.text.trim(); existing.location = locCtrl.text.trim();
                                existing.description = descCtrl.text.trim(); existing.developerName = devCtrl.text.trim();
                                existing.reraNumber = reraCtrl.text.trim().isEmpty ? null : reraCtrl.text.trim();
                                existing.totalUnits = int.tryParse(unitsCtrl.text) ?? 0;
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

  Widget _sheetField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) =>
      TextField(controller: ctrl, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 17, color: AppColors.textMuted)));

  void _confirmDelete(BuildContext context, AppState state, RealEstateProject p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${p.name}?', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text('All leads for this project will remain. This cannot be undone.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
          TextButton(onPressed: () { state.deleteProject(p.id); Navigator.pop(ctx); }, child: Text('Delete', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFD04060)))),
        ],
      ),
    );
  }

  Color _darken(Color color) { final hsl = HSLColor.fromColor(color); return hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0)).toColor(); }
  PageRouteBuilder _slide(Widget page) => PageRouteBuilder(pageBuilder: (_, a, b) => page, transitionsBuilder: (_, a, b, child) => SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child));
}

// ─── Project Card ─────────────────────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final RealEstateProject project;
  final AppState state;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onViewLeads;

  const _ProjectCard({required this.project, required this.state, this.onEdit, this.onDelete, required this.onViewLeads});

  @override
  Widget build(BuildContext context) {
    final leads = state.companyLeads.where((l) => l.projectId == project.id).toList();
    final closed = leads.where((l) => l.status == LeadStatus.closed).length;
    final siteVisit = leads.where((l) => l.status == LeadStatus.siteVisit).length;
    final grads = [AppColors.gradientPrimary, AppColors.gradientSecondary, AppColors.gradientTertiary, AppColors.gradientSuccess];
    final grad = grads[project.id.hashCode % grads.length];
    final assignedNames = project.assignedSalesIds.map((id) {
      try { return state.users.firstWhere((u) => u.id == id).name.split(' ').first; } catch (_) { return ''; }
    }).where((n) => n.isNotEmpty).toList();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: grad, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(project.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(project.location, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                          ]),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(project.status.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _hstat('${leads.length}', 'Leads'),
                  _vsep(),
                  _hstat('$closed', 'Closed'),
                  _vsep(),
                  _hstat('$siteVisit', 'Site Visits'),
                  _vsep(),
                  _hstat(project.priceDisplay, 'Range'),
                ]),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (project.developerName.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.business_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(project.developerName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    if (project.propertyType != PropertyType.other) ...[
                      const SizedBox(width: 10),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(project.propertyType.label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ]),
                if (project.totalUnits > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.grid_view_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text('${project.totalUnits} units', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    if (project.reraNumber != null && project.reraNumber!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.verified_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Expanded(child: Text(project.reraNumber!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                ],
                if (assignedNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.group_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Expanded(child: Text(assignedNames.join(', '), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                const SizedBox(height: 12),
                // Pipeline mini bar
                if (leads.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: LeadStatus.values.where((s) {
                        final c = leads.where((l) => l.status == s).length;
                        return c > 0;
                      }).map((s) {
                        final c = leads.where((l) => l.status == s).length;
                        return Expanded(
                          flex: c,
                          child: Container(height: 4, color: s.color),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onViewLeads,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text('View Leads', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                      ),
                    ),
                  ),
                  if (onEdit != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFD04060))),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hstat(String val, String label) => Expanded(child: Column(children: [
    Text(val, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
    Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary)),
  ]));

  Widget _vsep() => Container(width: 1, height: 28, color: AppColors.textPrimary.withValues(alpha: 0.15), margin: const EdgeInsets.symmetric(horizontal: 4));
}
