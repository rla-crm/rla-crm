import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return state.isAdmin ? const _AdminTeamView() : const _SalesTeamView();
  }
}

// ─── Admin Team View ──────────────────────────────────────────────────────────
class _AdminTeamView extends StatefulWidget {
  const _AdminTeamView();

  @override
  State<_AdminTeamView> createState() => _AdminTeamViewState();
}

class _AdminTeamViewState extends State<_AdminTeamView> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final users = state.companyUsers;
    final admins = users.where((u) => u.role == UserRole.companyAdmin).length;
    final sales = users.where((u) => u.role == UserRole.sales).length;
    final active = users.where((u) => u.isActive).length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Team', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text('${users.length} members', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  GradientButton(
                    label: 'Add User',
                    icon: Icons.person_add_outlined,
                    height: 38,
                    onTap: () => _showUserSheet(context, state, null),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  _statTile('Admins', admins.toString(), AppColors.gradientPrimary),
                  const SizedBox(width: 10),
                  _statTile('Sales', sales.toString(), AppColors.gradientTertiary),
                  const SizedBox(width: 10),
                  _statTile('Active', active.toString(), AppColors.gradientSuccess),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final u = users[i];
                  final leads = state.companyLeads;
                  final uLeadCount = leads.where((l) => l.assignedToId == u.id).length;
                  final uClosedCount = leads.where((l) => l.assignedToId == u.id && l.status == LeadStatus.closed).length;
                  return _UserCard(
                    user: u,
                    leadCount: uLeadCount,
                    closedCount: uClosedCount,
                    isSelf: state.currentUser?.id == u.id,
                    canEdit: u.role != UserRole.masterAdmin, // project admin cannot edit master admins
                    onEdit: () => _showUserSheet(context, state, u),
                    onToggle: () => state.toggleUserActive(u.id),
                    onDelete: () => _confirmDelete(context, state, u),
                  );
                },
                childCount: users.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, LinearGradient grad) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [grad.colors.first.withValues(alpha: 0.12), grad.colors.last.withValues(alpha: 0.07)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: grad.colors.first.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, gradient: grad)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove User', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Remove ${user.name} from the team?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(
            onPressed: () { Navigator.pop(ctx); state.deleteUser(user.id); },
            child: Text('Remove', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showUserSheet(BuildContext context, AppState state, AppUser? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserSheet(state: state, existing: existing),
    );
  }
}

// ─── User Card ────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final AppUser user;
  final int leadCount;
  final int closedCount;
  final bool isSelf;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _UserCard({required this.user, required this.leadCount, required this.closedCount, required this.isSelf, this.canEdit = true, required this.onEdit, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == UserRole.companyAdmin;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: user.isActive ? AppColors.border : AppColors.stageLost.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                AvatarWidget(
                  initials: user.initials,
                  size: 44,
                  gradient: isAdmin ? AppColors.gradientPrimary : AppColors.gradientTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(user.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                          if (isSelf)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.lavender.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text('You', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.lavender)),
                            ),
                        ],
                      ),
                      Text(user.email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          StatusPill(label: user.roleLabel, color: isAdmin ? AppColors.lavender : AppColors.sky, isSmall: true),
                          const SizedBox(width: 6),
                          StatusPill(label: user.isActive ? 'Active' : 'Inactive', color: user.isActive ? AppColors.mint : AppColors.stageLost, isSmall: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isSelf) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat(Icons.people_alt_outlined, '$leadCount leads'),
                  const SizedBox(width: 12),
                  _stat(Icons.check_circle_outline_rounded, '$closedCount closed'),
                  const Spacer(),
                  if (canEdit) ...[
                    _actionBtn(Icons.edit_outlined, AppColors.lavender, onEdit),
                    const SizedBox(width: 6),
                    _actionBtn(user.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                        user.isActive ? AppColors.peach : AppColors.mint, onToggle),
                    const SizedBox(width: 6),
                    _actionBtn(Icons.delete_outline_rounded, AppColors.pink, onDelete),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('Master Admin', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.peach)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
    ]);
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ─── User Sheet ───────────────────────────────────────────────────────────────
class _UserSheet extends StatefulWidget {
  final AppState state;
  final AppUser? existing;
  const _UserSheet({required this.state, this.existing});

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  UserRole _role = UserRole.sales;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _passCtrl = TextEditingController(text: e?.password ?? '');
    _role = e?.role ?? UserRole.sales;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    final state = widget.state;
    // Check for email duplication on new users
    if (widget.existing == null &&
        state.users.any((u) => u.email.toLowerCase() == _emailCtrl.text.trim().toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('This email is already registered.', style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: const Color(0xFFD04060),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final user = AppUser(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      role: _role,
      companyId: state.currentCompanyId,
      companyName: state.currentUser?.companyName,
      isActive: widget.existing?.isActive ?? true,
      isApproved: true, // Admin directly creates = pre-approved
      createdAt: widget.existing?.createdAt,
    );
    if (widget.existing != null) {
      state.updateUser(user);
    } else {
      state.addUser(user);
    }
    Navigator.pop(context);
    if (widget.existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${user.name} added to your team!', style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: const Color(0xFF3B8A6E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              Text(widget.existing == null ? 'Add User' : 'Edit User', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textMuted))),
            const SizedBox(height: 10),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textMuted))),
            const SizedBox(height: 10),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Role', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [UserRole.companyAdmin, UserRole.sales].map((r) {
                final sel = _role == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _role = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: sel ? AppColors.gradientPrimary : null,
                        color: sel ? null : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                      ),
                      child: Text(r == UserRole.companyAdmin ? 'Admin' : 'Sales', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textPrimary)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            GradientButton(label: widget.existing == null ? 'Add User' : 'Save Changes', onTap: _save, icon: widget.existing == null ? Icons.person_add_outlined : Icons.save_rounded),
          ],
        ),
      ),
    );
  }
}

// ─── Sales Team View ──────────────────────────────────────────────────────────
class _SalesTeamView extends StatelessWidget {
  const _SalesTeamView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser!;
    final myLeads = state.myLeads;
    final closed = myLeads.where((l) => l.status == LeadStatus.closed).length;
    final siteVisits = myLeads.where((l) => l.status == LeadStatus.siteVisit).length;
    final teamMembers = state.companyUsers.where((u) => u.id != user.id).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Team', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            // My stats
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarWidget(initials: user.initials, size: 52, gradient: AppColors.gradientTertiary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(user.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _badge('${ myLeads.length} Leads', AppColors.sky),
                            const SizedBox(width: 6),
                            _badge('$closed Closed', AppColors.mint),
                            const SizedBox(width: 6),
                            _badge('$siteVisits Visits', AppColors.peach),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Team Members (${teamMembers.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...teamMembers.map((m) {
              final mLeads = state.companyLeads.where((l) => l.assignedToId == m.id).length;
              final mClosed = state.companyLeads.where((l) => l.assignedToId == m.id && l.status == LeadStatus.closed).length;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    AvatarWidget(initials: m.initials, size: 40, gradient: m.role == UserRole.companyAdmin ? AppColors.gradientPrimary : AppColors.gradientTertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(m.roleLabel, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$mLeads leads', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        Text('$mClosed closed', style: GoogleFonts.inter(fontSize: 10, color: AppColors.teal)),
                      ],
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }
}
