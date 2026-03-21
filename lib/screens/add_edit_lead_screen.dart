import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

class AddEditLeadScreen extends StatefulWidget {
  final Lead? lead;
  const AddEditLeadScreen({super.key, this.lead});

  @override
  State<AddEditLeadScreen> createState() => _AddEditLeadScreenState();
}

class _AddEditLeadScreenState extends State<AddEditLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _budgetMinCtrl;
  late TextEditingController _budgetMaxCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _siteVisitCtrl;
  late TextEditingController _followUpCtrl;
  late TextEditingController _closedValueCtrl;

  PropertyType _propertyType = PropertyType.apartment;
  LeadSource _source = LeadSource.walkin;
  LeadStatus _status = LeadStatus.newLead;
  LeadType _leadType = LeadType.sale;
  String? _assignedToId;
  String? _assignedToName;
  String? _selectedProjectId;
  String? _selectedProjectName;

  bool _loading = false;
  int _currentSection = 0;
  final _pageCtrl = PageController();

  bool get _isEdit => widget.lead != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lead;
    _nameCtrl = TextEditingController(text: l?.name ?? '');
    _phoneCtrl = TextEditingController(text: l?.phone ?? '');
    _emailCtrl = TextEditingController(text: l?.email ?? '');
    _budgetMinCtrl = TextEditingController(text: l?.budgetMin?.toStringAsFixed(0) ?? '');
    _budgetMaxCtrl = TextEditingController(text: l?.budgetMax?.toStringAsFixed(0) ?? '');
    _notesCtrl = TextEditingController(text: l?.notes ?? '');
    _siteVisitCtrl = TextEditingController(text: l?.siteVisitDate ?? '');
    _followUpCtrl = TextEditingController(text: l?.followUpDate ?? '');
    _closedValueCtrl = TextEditingController(text: l?.closedValue?.toStringAsFixed(0) ?? '');
    if (l != null) {
      _propertyType = l.propertyType;
      _source = l.source;
      _status = l.status;
      _leadType = l.leadType;
      _assignedToId = l.assignedToId;
      _assignedToName = l.assignedToName;
      _selectedProjectId = l.projectId;
      _selectedProjectName = l.projectName;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _budgetMinCtrl, _budgetMaxCtrl, _notesCtrl, _siteVisitCtrl, _followUpCtrl, _closedValueCtrl]) {
      c.dispose();
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final salesUsers = state.salesUsers;
    // Auto-assign for sales users
    if (_assignedToId == null) {
      if (state.currentUser?.role == UserRole.sales) {
        _assignedToId = state.currentUser!.id;
        _assignedToName = state.currentUser!.name;
      } else if (salesUsers.isNotEmpty) {
        _assignedToId = salesUsers.first.id;
        _assignedToName = salesUsers.first.name;
      }
    }

    // Available projects (sales see only their projects)
    final availableProjects = state.isAdmin ? state.companyProjects : state.myProjects;

    // Auto-select project if only one
    if (_selectedProjectId == null && availableProjects.length == 1) {
      _selectedProjectId = availableProjects.first.id;
      _selectedProjectName = availableProjects.first.name;
    }

    final sections = ['Client', 'Property', 'Assignment'];
    final progress = (_currentSection + 1) / sections.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BlobBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isEdit ? 'Edit Lead' : 'New Lead',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                Text('Step ${_currentSection + 1} of ${sections.length} · ${sections[_currentSection]}',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(AppColors.lavender),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Pages ──
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _ClientSection(),
                      _PropertySection(
                        availableProjects: availableProjects,
                        salesUsers: salesUsers,
                        state: state,
                      ),
                      _AssignmentSection(salesUsers: salesUsers, state: state),
                    ],
                  ),
                ),
                // ── Bottom nav ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      if (_currentSection > 0)
                        Expanded(
                          child: GestureDetector(
                            onTap: _prevSection,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Center(child: Text('Back', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
                            ),
                          ),
                        ),
                      if (_currentSection > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GradientButton(
                          label: _currentSection < sections.length - 1 ? 'Next' : (_isEdit ? 'Update Lead' : 'Save Lead'),
                          isLoading: _loading,
                          onTap: _currentSection < sections.length - 1 ? _nextSection : () => _submit(state),
                          icon: _currentSection == sections.length - 1 ? Icons.check_rounded : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _prevSection() {
    setState(() => _currentSection--);
    _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _nextSection() {
    if (_currentSection == 0 && !_validateClient()) return;
    if (_currentSection == 1 && !_validateProperty()) return;
    setState(() => _currentSection++);
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  bool _validateClient() {
    if (_nameCtrl.text.trim().isEmpty) { _showError('Please enter client name'); return false; }
    if (_phoneCtrl.text.trim().isEmpty) { _showError('Please enter phone number'); return false; }
    return true;
  }

  bool _validateProperty() {
    if (_selectedProjectId == null) { _showError('Please select a project'); return false; }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: const Color(0xFFD04060),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit(AppState state) async {
    if (_selectedProjectId == null) { _showError('Please select a project'); return; }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final currentUser = state.currentUser!;
    final assignId = _assignedToId ?? currentUser.id;
    final assignName = _assignedToName ?? currentUser.name;

    if (_isEdit) {
      final prev = widget.lead!;
      prev.name = _nameCtrl.text.trim();
      prev.phone = _phoneCtrl.text.trim();
      prev.email = _emailCtrl.text.trim();
      prev.projectId = _selectedProjectId!;
      prev.projectName = _selectedProjectName!;
      prev.propertyType = _propertyType;
      prev.budgetMin = double.tryParse(_budgetMinCtrl.text);
      prev.budgetMax = double.tryParse(_budgetMaxCtrl.text);
      prev.source = _source;
      prev.status = _status;
      prev.leadType = _leadType;
      prev.assignedToId = assignId;
      prev.assignedToName = assignName;
      prev.notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      prev.siteVisitDate = _siteVisitCtrl.text.trim().isEmpty ? null : _siteVisitCtrl.text.trim();
      prev.followUpDate = _followUpCtrl.text.trim().isEmpty ? null : _followUpCtrl.text.trim();
      prev.closedValue = _status == LeadStatus.closed
          ? double.tryParse(_closedValueCtrl.text)
          : prev.closedValue;
      state.updateLead(prev);
      if (mounted) Navigator.pop(context, prev);
    } else {
      final lead = Lead(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        projectId: _selectedProjectId!,
        projectName: _selectedProjectName!,
        propertyType: _propertyType,
        budgetMin: double.tryParse(_budgetMinCtrl.text),
        budgetMax: double.tryParse(_budgetMaxCtrl.text),
        source: _source,
        status: _status,
        leadType: _leadType,
        assignedToId: assignId,
        assignedToName: assignName,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        siteVisitDate: _siteVisitCtrl.text.trim().isEmpty ? null : _siteVisitCtrl.text.trim(),
        followUpDate: _followUpCtrl.text.trim().isEmpty ? null : _followUpCtrl.text.trim(),
        createdById: currentUser.id,
        createdByName: currentUser.name,
        companyId: state.currentCompanyId ?? '',
        closedValue: _status == LeadStatus.closed
            ? double.tryParse(_closedValueCtrl.text)
            : null,
      );
      state.addLead(lead);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Section 1: Client ──────────────────────────────────────────────────────
  Widget _ClientSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _sectionCard('Client Information', Icons.person_outline_rounded, AppColors.gradientPrimary, [
        _field(_nameCtrl, 'Full Name *', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _field(_phoneCtrl, 'Phone Number *', Icons.phone_outlined, type: TextInputType.phone),
        const SizedBox(height: 12),
        _field(_emailCtrl, 'Email Address', Icons.mail_outline_rounded, type: TextInputType.emailAddress),
      ]),
    );
  }

  // ── Section 2: Property ────────────────────────────────────────────────────
  Widget _PropertySection({
    required List<RealEstateProject> availableProjects,
    required List<AppUser> salesUsers,
    required AppState state,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _sectionCard('Property Interest', Icons.apartment_outlined, AppColors.gradientSecondary, [
            // Project Dropdown
            Text('Project *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            availableProjects.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text('No projects available. Ask admin to create a project.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                    ]),
                  )
                : Column(
                    children: availableProjects.map((p) {
                      final isSelected = _selectedProjectId == p.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedProjectId = p.id;
                            _selectedProjectName = p.name;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.lavender.withValues(alpha: 0.1) : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppColors.lavender.withValues(alpha: 0.5) : AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    gradient: isSelected ? AppColors.gradientPrimary : const LinearGradient(colors: [Color(0xFFE8E8F0), Color(0xFFD8D8E8)]),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.apartment_rounded, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      Text(p.location, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.lavender, size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 14),
            // ── Lead Type (Sale / Lease) ──────────────────────────────────
            Text('Lead Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: LeadType.values.map((t) {
                final isActive = _leadType == t;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t == LeadType.sale ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _leadType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? (t == LeadType.sale
                                  ? AppColors.gradientPrimary
                                  : AppColors.gradientSecondary)
                              : null,
                          color: isActive ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? Colors.transparent
                                : AppColors.border,
                            width: 1.5,
                          ),
                          boxShadow: isActive
                              ? [BoxShadow(color: t.color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              t == LeadType.sale ? Icons.sell_rounded : Icons.key_rounded,
                              size: 15,
                              color: isActive ? Colors.white : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.shortLabel,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isActive ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Property Type
            Text('Property Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: PropertyType.values.map((t) {
                final isActive = _propertyType == t;
                return GestureDetector(
                  onTap: () => setState(() => _propertyType = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.gradientSecondary : null,
                      color: isActive ? null : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? Colors.transparent : AppColors.border),
                    ),
                    child: Text(t.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _field(_budgetMinCtrl, 'Min Budget (₹)', Icons.currency_rupee_rounded, type: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _field(_budgetMaxCtrl, 'Max Budget (₹)', Icons.currency_rupee_rounded, type: TextInputType.number)),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  // ── Section 3: Assignment ──────────────────────────────────────────────────
  Widget _AssignmentSection({required List<AppUser> salesUsers, required AppState state}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _sectionCard('Assignment & Details', Icons.assignment_outlined, AppColors.gradientTertiary, [
            // Source
            Text('Lead Source', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: LeadSource.values.map((s) {
                final isActive = _source == s;
                return GestureDetector(
                  onTap: () => setState(() => _source = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.gradientTertiary : null,
                      color: isActive ? null : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? Colors.transparent : AppColors.border),
                    ),
                    child: Text(s.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            // Assign To (admin only)
            if (state.isAdmin) ...[
              const SizedBox(height: 14),
              Text('Assign To', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...salesUsers.where((u) => u.isActive).map((u) {
                final isActive = _assignedToId == u.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () => setState(() { _assignedToId = u.id; _assignedToName = u.name; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.lavender.withValues(alpha: 0.1) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isActive ? AppColors.lavender.withValues(alpha: 0.5) : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          AvatarWidget(initials: u.initials, size: 32, gradient: AppColors.gradientTertiary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(u.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: AppColors.textPrimary))),
                          if (isActive) const Icon(Icons.check_circle_rounded, color: AppColors.lavender, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            // Status (admin or edit mode)
            if (state.isAdmin || _isEdit) ...[
              const SizedBox(height: 14),
              Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: LeadStatus.values.map((s) {
                  final isActive = _status == s;
                  return GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive ? s.color.withValues(alpha: 0.25) : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? s.color.withValues(alpha: 0.5) : AppColors.border),
                      ),
                      child: Text(s.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? _darken(s.color) : AppColors.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
            ],
            // ── Closed Deal Value — shown only when status = Closed ──────────
            if (_status == LeadStatus.closed) ...
              [
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A8F5C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A8F5C).withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monetization_on_rounded, size: 15, color: Color(0xFF1A8F5C)),
                          const SizedBox(width: 6),
                          Text('Closed Deal Value',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1A8F5C))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Enter the actual sale value for this deal',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 10),
                      _field(_closedValueCtrl, 'Deal Value (₹)', Icons.currency_rupee_rounded,
                          type: TextInputType.number),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: 14),
            _field(_siteVisitCtrl, 'Site Visit Date', Icons.calendar_today_outlined),
            const SizedBox(height: 12),
            _field(_followUpCtrl, 'Follow-Up Date', Icons.event_outlined),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Notes',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 56),
                  child: Icon(Icons.notes_rounded, size: 18, color: AppColors.textMuted),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, LinearGradient grad, List<Widget> children) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 17, color: AppColors.textMuted),
      ),
    );
  }

  Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0)).toColor();
  }
}
