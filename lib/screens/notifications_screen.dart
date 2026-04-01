import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notifs = state.myNotifications;
    final unread = state.unreadNotificationCount;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text(
                          unread > 0 ? '$unread unread' : 'All caught up!',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: unread > 0
                                  ? AppColors.pink
                                  : AppColors.sky)),
                    ],
                  ),
                ),
                if (unread > 0)
                  TextButton.icon(
                    onPressed: () => state.markAllNotificationsRead(),
                    icon: const Icon(Icons.done_all_rounded, size: 14),
                    label: Text('Mark all read',
                        style: GoogleFonts.inter(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.lavender),
                  ),
                if (state.isAdmin)
                  GestureDetector(
                    onTap: () => _showNewAlertSheet(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('New Alert',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: notifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_none_rounded,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text('No notifications yet',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: notifs.length,
                    itemBuilder: (_, i) => _NotifCard(
                        notif: notifs[i], isAdmin: state.isAdmin),
                  ),
          ),
        ],
      ),
    );
  }

  void _showNewAlertSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewAlertSheet(state: state),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final CrmNotification notif;
  final bool isAdmin;

  const _NotifCard({required this.notif, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final priorityColors = {
      NotificationPriority.high: AppColors.gradientPrimary,
      NotificationPriority.medium: AppColors.gradientTertiary,
      NotificationPriority.low: AppColors.gradientSuccess,
    };
    final grad = priorityColors[notif.priority]!;

    return GestureDetector(
      onTap: () {
        if (!notif.isRead) {
          context.read<AppState>().markNotificationRead(notif.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: notif.isRead
              ? AppColors.surface
              : AppColors.lavender.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: notif.isRead
                  ? AppColors.border
                  : AppColors.lavender.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              decoration: BoxDecoration(
                gradient: grad,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(notif.title,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: notif.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ),
                        if (!notif.isRead)
                          Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.lavender)),
                        if (isAdmin)
                          GestureDetector(
                            onTap: () => context
                                .read<AppState>()
                                .deleteNotification(notif.id),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.delete_outline_rounded,
                                  size: 16, color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(notif.message,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    if (notif.projectName != null && notif.projectName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.apartment_rounded, size: 10, color: AppColors.lavender),
                            const SizedBox(width: 3),
                            Text(
                              notif.projectName!,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.lavender),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Text('By ${notif.createdByName}',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                        Text(_timeAgo(notif.createdAt),
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppColors.textMuted)),
                        const Spacer(),
                        StatusPill(
                          label:
                              notif.priority.name.toUpperCase(),
                          color: notif.priority ==
                                  NotificationPriority.high
                              ? AppColors.pink
                              : notif.priority ==
                                      NotificationPriority.medium
                                  ? AppColors.sky
                                  : AppColors.sky,
                          isSmall: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── New Alert Sheet ──────────────────────────────────────────────────────────
class _NewAlertSheet extends StatefulWidget {
  final AppState state;
  const _NewAlertSheet({required this.state});

  @override
  State<_NewAlertSheet> createState() => _NewAlertSheetState();
}

class _NewAlertSheetState extends State<_NewAlertSheet> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  NotificationPriority _priority = NotificationPriority.medium;
  bool _forAll = true;
  final Set<String> _selectedUsers = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (_titleCtrl.text.isEmpty || _msgCtrl.text.isEmpty) return;
    final state = widget.state;
    final notif = CrmNotification(
      title: _titleCtrl.text.trim(),
      message: _msgCtrl.text.trim(),
      createdById: state.currentUser!.id,
      createdByName: state.currentUser!.name,
      isForAll: _forAll,
      targetUserIds: _forAll ? [] : _selectedUsers.toList(),
      priority: _priority,
      companyId: state.currentCompanyId ?? '',
      isAlert: true, // Show as popup to recipients
    );
    state.addNotification(notif);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('Alert sent to ${_forAll ? 'all team members' : '${_selectedUsers.length} user(s)'}', style: GoogleFonts.inter(fontSize: 12)),
      ]),
      backgroundColor: const Color(0xFF5B3FBF),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final salesUsers = widget.state.salesUsers;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text('New Alert',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 14),
            TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded,
                        size: 18, color: AppColors.textMuted))),
            const SizedBox(height: 10),
            TextField(
                controller: _msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.message_outlined,
                        size: 18, color: AppColors.textMuted))),
            const SizedBox(height: 14),
            Text('Priority',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: NotificationPriority.values.map((p) {
                final colors = {
                  NotificationPriority.high: AppColors.pink,
                  NotificationPriority.medium: AppColors.sky,
                  NotificationPriority.low: AppColors.sky
                };
                final c = colors[p]!;
                final sel = _priority == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? c.withValues(alpha: 0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? c : AppColors.border,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Text(p.name.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Text('Recipients',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const Spacer(),
              Switch(
                  value: _forAll,
                  onChanged: (v) => setState(() => _forAll = v),
                  activeThumbColor: AppColors.lavender),
              Text(_forAll ? 'All Team' : 'Specific',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
            if (!_forAll) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: salesUsers.map((u) {
                  final sel = _selectedUsers.contains(u.id);
                  return GestureDetector(
                    onTap: () => setState(() => sel
                        ? _selectedUsers.remove(u.id)
                        : _selectedUsers.add(u.id)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.lavender.withValues(alpha: 0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel
                                ? AppColors.lavender
                                : AppColors.border),
                      ),
                      child: Text(u.name,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(
                label: 'Send Alert',
                onTap: _send,
                icon: Icons.send_rounded),
          ],
        ),
      ),
    );
  }
}
