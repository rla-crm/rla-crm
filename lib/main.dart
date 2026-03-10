import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_state.dart';
import 'core/models.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/sales_dashboard.dart';
import 'screens/master_admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final appState = AppState();
  await appState.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const RlaCrmApp(),
    ),
  );
}

class RlaCrmApp extends StatefulWidget {
  const RlaCrmApp({super.key});

  @override
  State<RlaCrmApp> createState() => _RlaCrmAppState();
}

class _RlaCrmAppState extends State<RlaCrmApp> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RLA CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: _splashDone
          ? const AppRouter()
          : SplashScreen(
              onComplete: () => setState(() => _splashDone = true),
            ),
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _trialDialogShown = false;
  final Set<String> _shownAlertIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkFirstLogin();
  }

  void _showAlertPopup(AppState state, CrmNotification alert) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AlertPopupDialog(
        notification: alert,
        onDismiss: () {
          Navigator.pop(ctx);
          state.markNotificationRead(alert.id);
        },
      ),
    );
  }

  void _checkFirstLogin() {
    final state = context.read<AppState>();
    final user = state.currentUser;
    if (user == null) {
      _trialDialogShown = false;
      return;
    }
    // Show free trial popup for Company Admins on their very first login
    if (user.role == UserRole.companyAdmin &&
        !user.hasLoggedInBefore &&
        !_trialDialogShown) {
      _trialDialogShown = true;
      // Use post-frame callback to ensure widget is mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTrialPopup(state);
      });
    }
  }

  void _showTrialPopup(AppState state) {
    final company = state.currentCompany;
    final daysLeft = company?.trialDaysLeft ?? Company.trialDurationDays;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TrialWelcomeDialog(
        companyName: company?.name ?? 'Your Company',
        daysLeft: daysLeft,
        onDismiss: () {
          Navigator.pop(ctx);
          state.markFirstLoginDone();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;

    // Check for new alert popups whenever state changes
    _checkNewAlertsFromState(state);

    if (user == null) return const LoginScreen();
    if (user.role == UserRole.masterAdmin) return const MasterAdminDashboard();
    if (user.role == UserRole.companyAdmin) return const AdminDashboard();
    return const SalesDashboard();
  }

  void _checkNewAlertsFromState(AppState state) {
    final user = state.currentUser;
    if (user == null || user.role == UserRole.masterAdmin) return;
    final myNotifs = state.myNotifications;
    for (final notif in myNotifs) {
      if (!notif.isRead && !_shownAlertIds.contains(notif.id) && notif.isAlert) {
        _shownAlertIds.add(notif.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAlertPopup(state, notif);
        });
        break;
      }
    }
  }
}

// ─── Free Trial Welcome Dialog ────────────────────────────────────────────────
class _TrialWelcomeDialog extends StatelessWidget {
  final String companyName;
  final int daysLeft;
  final VoidCallback onDismiss;

  const _TrialWelcomeDialog({
    required this.companyName,
    required this.daysLeft,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final pct = daysLeft / Company.trialDurationDays;
    final urgencyColor = daysLeft <= 3
        ? const Color(0xFFD04060)
        : daysLeft <= 7
            ? const Color(0xFFD08020)
            : const Color(0xFF3B8A6E);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.rocket_launch_rounded, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Welcome to RLA CRM!', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(companyName, style: GoogleFonts.inter(fontSize: 14, color: AppColors.lavender, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Trial status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 18, color: urgencyColor),
                      const SizedBox(width: 8),
                      Text(
                        'Free Trial Active',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: urgencyColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$daysLeft',
                        style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w900, color: urgencyColor),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('days', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: urgencyColor)),
                          Text('remaining', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  Stack(
                    children: [
                      Container(height: 8, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(height: 8, decoration: BoxDecoration(color: urgencyColor, borderRadius: BorderRadius.circular(4))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${Company.trialDurationDays - daysLeft} of ${Company.trialDurationDays} days used',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Plan benefits
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  Text('Upgrade to unlock full potential', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  _planRow('Starter', '₹2,999/mo', '10 users · 5 projects', AppColors.sky),
                  const SizedBox(height: 6),
                  _planRow('Professional', '₹7,999/mo', '50 users · 25 projects', AppColors.lavender),
                  const SizedBox(height: 6),
                  _planRow('Enterprise', 'Custom', 'Unlimited users & projects', AppColors.peach),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CTA buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(child: Text('Explore First', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDismiss, // In production: navigate to billing
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Center(child: Text('Choose a Plan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _planRow(String name, String price, String limits, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        Text(price, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Text(limits, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}

// ─── Alert Popup Dialog ───────────────────────────────────────────────────────
class _AlertPopupDialog extends StatelessWidget {
  final CrmNotification notification;
  final VoidCallback onDismiss;

  const _AlertPopupDialog({required this.notification, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final priorityColor = notification.priority == NotificationPriority.high
        ? const Color(0xFFD04060)
        : notification.priority == NotificationPriority.medium
            ? const Color(0xFFD08020)
            : AppColors.lavender;

    final grad = notification.priority == NotificationPriority.high
        ? AppColors.gradientPrimary
        : notification.priority == NotificationPriority.medium
            ? AppColors.gradientSecondary
            : AppColors.gradientTertiary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert icon
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: grad,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: grad.colors.first.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.notifications_active_rounded, size: 30, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 6)]),
            ),
            const SizedBox(height: 16),

            // Priority badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 6, color: priorityColor),
                const SizedBox(width: 5),
                Text(
                  '${notification.priority.name.toUpperCase()} PRIORITY ALERT',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: priorityColor, letterSpacing: 0.8),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            Text(
              notification.title,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              notification.message,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'From: ${notification.createdByName}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),

            // Dismiss button
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: grad,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: grad.colors.first.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Center(
                  child: Text(
                    'Acknowledged',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
