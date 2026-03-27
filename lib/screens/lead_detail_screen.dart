import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// web package removed — using url_launcher for all platforms
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import 'add_edit_lead_screen.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> with TickerProviderStateMixin {
  late Lead _lead;
  final _noteCtrl = TextEditingController();
  bool _showNoteInput = false;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Refresh lead from state
    final fresh = state.leads.firstWhere((l) => l.id == _lead.id, orElse: () => _lead);
    _lead = fresh;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BlobBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context, state)),
                  SliverToBoxAdapter(child: _buildPipelineStepper()),
                  SliverToBoxAdapter(child: _buildQuickActions(context, state)),
                  SliverToBoxAdapter(child: _buildDetails()),
                  SliverToBoxAdapter(child: _buildActivityTimeline()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              const RlaBrand(size: 13),
              const Spacer(),
              // ── Delete button (admin only) ─────────────────────────────────
              if (state.isAdmin)
                GestureDetector(
                  onTap: () => _confirmDelete(context, state),
                  child: Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFD04060)),
                  ),
                ),
              // ── Edit button (admin or assigned sales) ──────────────────────
              if (state.isAdmin || _lead.assignedToId == state.currentUser?.id)
                GestureDetector(
                  onTap: () async {
                    final updated = await Navigator.push<Lead>(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, a, b) => AddEditLeadScreen(lead: _lead),
                        transitionsBuilder: (_, a, b, child) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      ),
                    );
                    if (updated != null) setState(() => _lead = updated);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Hero profile card
          GlassCard(
            gradient: AppColors.gradientPrimary,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Text(_lead.initials, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_lead.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(_lead.phone, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                          if (_lead.email.isNotEmpty)
                            Text(_lead.email, style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
                        ],
                      ),
                    ),
                    StatusPill(label: _lead.status.label, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _heroInfo(Icons.apartment_outlined, _lead.projectName)),
                    Expanded(child: _heroInfo(Icons.home_outlined, _lead.propertyType.label)),
                    Expanded(child: _heroInfo(Icons.currency_rupee_outlined, _lead.budgetDisplay)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete confirmation dialog ──────────────────────────────────────────────
  void _confirmDelete(BuildContext context, AppState state) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 28, color: Color(0xFFD04060)),
              ),
              const SizedBox(height: 16),
              Text('Delete Lead?',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to permanently delete "${_lead.name}"? This action cannot be undone.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                // Delete
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);           // close dialog
                      state.deleteLead(_lead.id);   // delete from Hive + cloud sync
                      Navigator.pop(context);        // go back to leads list
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Lead "${_lead.name}" deleted', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                        ]),
                        backgroundColor: const Color(0xFFD04060),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 3),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroInfo(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(height: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildPipelineStepper() {
    final state = context.read<AppState>();
    final canMove = state.isAdmin || _lead.assignedToId == state.currentUser?.id;
    final stages = LeadStatus.values.where((s) => s != LeadStatus.lost).toList();
    final currentIdx = stages.indexWhere((s) => s == _lead.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Pipeline Stage', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5))),
              if (canMove && _lead.status == LeadStatus.lost) ...[
                GestureDetector(
                  onTap: () {
                    _lead.status = LeadStatus.newLead;
                    state.updateLead(_lead);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
                    child: Text('Reopen', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ]),
            if (canMove && _lead.status != LeadStatus.lost)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text('Tap any stage to move lead', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(stages.length, (i) {
                final isDone = i <= currentIdx;
                final isCurrent = i == currentIdx;
                final isClickable = canMove && !isCurrent;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: isClickable ? () {
                            final newStatus = stages[i];
                            void doMove() {
                              final activity = LeadActivity(
                                leadId: _lead.id,
                                userId: state.currentUser!.id,
                                userName: state.currentUser!.name,
                                action: 'Stage moved',
                                note: 'Moved from ${_lead.status.label} to ${newStatus.label}',
                                fromStatus: _lead.status,
                                toStatus: newStatus,
                              );
                              _lead.activities.add(activity);
                              _lead.status = newStatus;
                              state.updateLead(_lead);
                              setState(() {});
                            }
                            if (newStatus == LeadStatus.closed) {
                              _showClosedValueDialog(context, state, onConfirm: doMove);
                            } else {
                              doMove();
                            }
                          } : null,
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: isCurrent ? 28 : (isClickable ? 22 : 20),
                                height: isCurrent ? 28 : (isClickable ? 22 : 20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: isDone ? AppColors.gradientCTA : null,
                                  color: isDone ? null : (isClickable ? AppColors.lavender.withValues(alpha: 0.15) : AppColors.border),
                                  border: isClickable && !isDone ? Border.all(color: AppColors.lavender.withValues(alpha: 0.4), width: 1.5) : null,
                                  boxShadow: isCurrent ? [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.4), blurRadius: 8)] : [],
                                ),
                                child: Center(
                                  child: isDone
                                      ? Icon(Icons.check_rounded, size: isCurrent ? 14 : 10, color: Colors.white)
                                      : isClickable
                                          ? Icon(Icons.touch_app_rounded, size: 10, color: AppColors.lavender.withValues(alpha: 0.6))
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stages[i].label,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                  color: isDone ? AppColors.textPrimary : (isClickable ? AppColors.lavender : AppColors.textMuted),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < stages.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              gradient: i < currentIdx ? AppColors.gradientCTA : null,
                              color: i < currentIdx ? null : AppColors.border,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            if (_lead.status == LeadStatus.lost)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E8).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text('This lead is marked as Lost', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppState state) {
    final canEdit = state.isAdmin || _lead.assignedToId == state.currentUser?.id;
    if (!canEdit) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Contact Actions (Call / WhatsApp / Email) ─────────────────────
          Text('Quick Contact', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _actionTile(
                Icons.call_rounded, 'Call',
                AppColors.gradientSuccess,
                () => _doContact(context, state, 'call'),
                iconColor: Colors.white,
                labelColor: Colors.white,
              )),
              const SizedBox(width: 8),
              Expanded(child: _actionTile(
                Icons.chat_rounded, 'WhatsApp',
                const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
                () => _doContact(context, state, 'whatsapp'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _actionTile(
                Icons.email_rounded, 'Email',
                AppColors.gradientSecondary,
                () => _doContact(context, state, 'email'),
              )),
            ],
          ),
          const SizedBox(height: 14),
          // ── Add Note ───────────────────────────────────────────────────────
          Text('Add Note', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _showNoteInput = !_showNoteInput),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.gradientPrimary.colors.first.withValues(alpha: 0.12), AppColors.gradientPrimary.colors.last.withValues(alpha: 0.06)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lavender.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.note_add_outlined, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add a Note', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(_showNoteInput ? 'Tap to close' : 'Tap to write a note about this lead',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  )),
                  Icon(_showNoteInput ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (_showNoteInput) ...[
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 4, autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Write your note here...',
                      border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() { _showNoteInput = false; _noteCtrl.clear(); }),
                        child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          final note = _noteCtrl.text.trim();
                          if (note.isEmpty) return;
                          final activity = LeadActivity(
                            leadId: _lead.id,
                            userId: state.currentUser!.id,
                            userName: state.currentUser!.name,
                            action: 'Note added',
                            note: note,
                          );
                          _lead.activities.add(activity);
                          state.updateLead(_lead);
                          setState(() { _showNoteInput = false; _noteCtrl.clear(); });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(gradient: AppColors.gradientCTA, borderRadius: BorderRadius.circular(10)),
                          child: Text('Save Note', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (state.isAdmin || _lead.assignedToId == state.currentUser?.id) ...[
            const SizedBox(height: 14),
            Text('Move to Stage', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: LeadStatus.values.map((s) {
                final isActive = _lead.status == s;
                return GestureDetector(
                  onTap: () {
                    if (isActive) return;
                    void doStageMove() {
                      final activity = LeadActivity(
                        leadId: _lead.id,
                        userId: state.currentUser!.id,
                        userName: state.currentUser!.name,
                        action: 'Stage moved',
                        note: 'Moved from ${_lead.status.label} to ${s.label}',
                        fromStatus: _lead.status,
                        toStatus: s,
                      );
                      _lead.activities.add(activity);
                      _lead.status = s;
                      state.updateLead(_lead);
                      setState(() {});
                    }
                    if (s == LeadStatus.closed) {
                      _showClosedValueDialog(context, state, onConfirm: doStageMove);
                    } else {
                      doStageMove();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isActive ? s == LeadStatus.closed
                          ? AppColors.gradientSuccess
                          : s == LeadStatus.lost
                              ? const LinearGradient(colors: [Color(0xFFE0E0E8), Color(0xFFCCCCD8)])
                              : AppColors.gradientCTA
                          : null,
                      color: isActive ? null : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? Colors.transparent : s.color.withValues(alpha: 0.4)),
                      boxShadow: isActive ? [BoxShadow(color: s.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive) ...[
                          Icon(Icons.check_circle_rounded,
                            size: 12,
                            color: (isActive && (s == LeadStatus.closed || s == LeadStatus.lost))
                                ? (s == LeadStatus.closed ? Colors.white : AppColors.textSecondary)
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(s.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? (s == LeadStatus.closed
                                    ? Colors.white
                                    : s == LeadStatus.lost
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary)
                                : _darken(s.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Performs the contact action and logs it to the lead timeline.
  /// Uses dart:html window.open on web (no async gap → no popup block).
  /// Uses url_launcher on mobile/desktop.
  void _doContact(BuildContext context, AppState state, String type) {
    final rawPhone = _lead.phone.trim();
    final phone    = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final email    = _lead.email.trim();

    // ── Validate ──────────────────────────────────────────────────────────────
    if ((type == 'call' || type == 'whatsapp') && phone.isEmpty) {
      _showSnack(context, 'No phone number available for this lead.', isError: true);
      return;
    }
    if (type == 'email' && email.isEmpty) {
      _showSnack(context, 'No email address available for this lead.', isError: true);
      return;
    }

    // ── Build URL string and log text ─────────────────────────────────────────
    String urlStr;
    String action;
    String note;

    switch (type) {
      case 'call':
        action = 'Called lead';
        note   = 'Placed a phone call to $rawPhone';
        urlStr = 'tel:$phone';
        break;
      case 'whatsapp':
        action = 'WhatsApp message';
        note   = 'Opened WhatsApp chat with $rawPhone';
        final wpPhone = phone.startsWith('+') ? phone.substring(1) : phone;
        final msg     = Uri.encodeComponent(
            'Hi ${_lead.name}, this is regarding your inquiry for ${_lead.projectName}. How can I help you?');
        urlStr = 'https://wa.me/$wpPhone?text=$msg';
        break;
      case 'email':
        action = 'Email sent';
        note   = 'Opened email composer for $email';
        final subj = Uri.encodeComponent(
            'Regarding ${_lead.projectName} – ${_lead.propertyType.label}');
        final body = Uri.encodeComponent(
            'Dear ${_lead.name},\n\nI am reaching out regarding your inquiry for ${_lead.projectName}.\n\nBest regards');
        urlStr = 'mailto:$email?subject=$subj&body=$body';
        break;
      default:
        return;
    }

    // ── Log activity immediately (synchronous, before any launch attempt) ─────
    _lead.activities.add(LeadActivity(
      leadId:   _lead.id,
      userId:   state.currentUser!.id,
      userName: state.currentUser!.name,
      action:   action,
      note:     note,
    ));
    state.updateLead(_lead);
    setState(() {});

    // ── Launch ────────────────────────────────────────────────────────────────
    // Use url_launcher for all platforms
    _launchMobile(context, urlStr, type);
  }

  Future<void> _launchMobile(BuildContext context, String urlStr, String type) async {
    final uri = Uri.parse(urlStr);
    final label = type == 'call' ? 'phone dialer'
        : type == 'whatsapp' ? 'WhatsApp'
        : 'email app';
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (context.mounted) {
          _showSnack(context, 'Could not open $label.', isError: true);
        }
      }
    }
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.open_in_new_rounded,
          size: 16,
          color: Colors.white,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 12, color: Colors.white))),
      ]),
      backgroundColor: isError ? const Color(0xFFD04060) : AppColors.lavender,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lead Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _detailRow('Source', _lead.source.label),
            _detailRow('Lead Type', _lead.leadType.label),
            if (_lead.status == LeadStatus.closed)
              _detailRow(_lead.closedValueLabel, _lead.closedValueDisplay,
                  highlight: _lead.closedValue != null),
            _detailRow('Assigned To', _lead.assignedToName),
            _detailRow('Created By', _lead.createdByName),
            _detailRow('Created', _formatDate(_lead.createdAt)),
            _detailRow('Last Updated', _formatDate(_lead.updatedAt)),
            if (_lead.siteVisitDate != null && _lead.siteVisitDate!.isNotEmpty)
              _detailRow('Site Visit', _lead.siteVisitDate!),
            if (_lead.followUpDate != null && _lead.followUpDate!.isNotEmpty)
              _detailRow('Follow Up', _lead.followUpDate!),
            if (_lead.notes != null && _lead.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 8),
              Text('Notes', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text(_lead.notes!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: highlight
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientCTA,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(value,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  )
                : Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    final activities = _lead.activities.reversed.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Timeline', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            Center(child: Text('No activity yet', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)))
          else
            ...activities.asMap().entries.map((e) {
              final idx = e.key;
              final a = e.value;
              final isLast = idx == activities.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 10, height: 10,
                          decoration: const BoxDecoration(
                              gradient: AppColors.gradientCTA,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: AppColors.lavender.withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(a.action, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Text(_formatDate(a.timestamp), style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                              if (a.note != null && a.note!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(a.note!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
                              ],
                              const SizedBox(height: 2),
                              Text('by ${a.userName}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy · HH:mm').format(dt);

  Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0)).toColor();
  }

  // ── Closed-Value Prompt Dialog ─────────────────────────────────────────────
  /// Shows a dialog asking for the deal value when a lead is moved to Closed.
  /// Calls [onConfirm] with the (optional) entered value so the caller can
  /// persist the status + closedValue together.
  void _showClosedValueDialog(
    BuildContext context,
    AppState state, {
    required VoidCallback onConfirm,
  }) {
    final isLease = _lead.leadType == LeadType.lease;
    final valueLabel = isLease ? 'Annual Lease Amount (₹)' : 'Sale / Deal Value (₹)';
    final valueHint  = isLease ? 'e.g. 1200000 for ₹12L/year' : 'e.g. 5000000 for ₹50L';
    final ctrl = TextEditingController(
      text: _lead.closedValue != null
          ? _lead.closedValue!.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientCTA,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.monetization_on_rounded, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mark as Closed',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(isLease ? 'Enter annual lease amount' : 'Enter the deal value',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Lead summary row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lavender.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(_lead.initials,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_lead.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${_lead.projectName} · ${isLease ? "Lease" : "Sale"}',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Value field
              Text(valueLabel,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: valueHint,
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18, color: AppColors.textMuted),
                  suffixText: isLease ? '/year' : null,
                ),
              ),
              const SizedBox(height: 6),
              Text('You can leave this blank and update it later.',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
              const SizedBox(height: 20),
              // Action buttons
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
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
                      final val = double.tryParse(ctrl.text.trim());
                      _lead.closedValue = val;
                      Navigator.pop(ctx);
                      onConfirm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientCTA,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Center(child: Text('Confirm Closed',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, LinearGradient gradient, VoidCallback onTap, {Color? iconColor, Color? labelColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: iconColor ?? AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor ?? AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
