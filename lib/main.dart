import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/app_state.dart';
import 'core/models.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/sales_dashboard.dart';
import 'screens/master_admin_dashboard.dart';

// v15.4 — project card gradient fix (cache bust)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialise Firebase before anything else
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase may already be initialized (hot restart), ignore duplicate-app error
    if (!e.toString().contains('duplicate-app')) {
      runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF7B5FFF),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Initialization error: $e',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ));
      return;
    }
  }

  final appState = AppState();
  try {
    await appState.init();
  } catch (e) {
    // If init fails, still show the app (it will handle state gracefully)
  }

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
  final Set<String> _shownAlertIds = {};

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
