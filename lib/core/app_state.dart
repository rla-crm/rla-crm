import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';
import '../services/sync_service.dart';

// ─── Signup Result ────────────────────────────────────────────────────────────
class SignupResult {
  final String? error;
  final bool promotedToAdmin;
  final bool pendingApproval;
  const SignupResult({this.error, this.promotedToAdmin = false, this.pendingApproval = false});
  bool get success => error == null;
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  // ─── Hive boxes (session cache ONLY — cloud is the source of truth) ────────
  // Hive is written after every cloud pull so a page-refresh shows data
  // immediately while the first cloud pull is in flight (~300ms).
  // Hive data is NEVER pushed back to the cloud.
  late Box _usersBox;
  late Box _leadsBox;
  late Box _notifBox;
  late Box _projectsBox;
  late Box _approvalsBox;
  late Box _emailLogsBox;
  late Box _settingsBox;

  AppUser? _currentUser;
  List<AppUser> _users = [];
  List<Lead> _leads = [];
  List<CrmNotification> _notifications = [];
  List<RealEstateProject> _projects = [];
  List<ApprovalRequest> _approvals = [];
  List<EmailLog> _emailLogs = [];

  // ─── Real-time sync infrastructure ────────────────────────────────────────
  // CLOUD IS THE SINGLE SOURCE OF TRUTH.
  //
  //  _versionTimer  (every 3s, lightweight)
  //    → polls GET /api/sync/version
  //    → triggers a full pullAll only when version changed
  //
  //  _immediateTimer (one-shot, fires 1s after any write)
  //    → forces a full re-pull to confirm the cloud write landed
  Timer? _versionTimer;
  Timer? _immediateTimer;
  static const Duration _versionPollInterval = Duration(seconds: 3);
  bool _syncInProgress = false;

  // NOTE: Tombstone sets are kept ONLY for the flush operation —
  // they are NOT used during normal sync (cloud data replaces local wholesale).
  final Set<String> _deletedLeadIds      = {};
  final Set<String> _deletedProjectIds   = {};
  final Set<String> _deletedUserIds      = {};
  final Set<String> _deletedApprovalIds  = {};
  final Set<String> _deletedNotifIds     = {};

  // ─── Getters ─────────────────────────────────────────────────────────────
  AppUser? get currentUser => _currentUser;
  List<AppUser> get users => List.unmodifiable(_users);
  List<Lead> get leads => List.unmodifiable(_leads);
  List<CrmNotification> get notifications => List.unmodifiable(_notifications);
  List<RealEstateProject> get projects => List.unmodifiable(_projects);
  List<ApprovalRequest> get approvals => List.unmodifiable(_approvals);
  List<EmailLog> get emailLogs => List.unmodifiable(_emailLogs);

  bool get isMasterAdmin => _currentUser?.role == UserRole.masterAdmin;
  bool get isCompanyAdmin => _currentUser?.role == UserRole.companyAdmin;
  bool get isAdmin => isMasterAdmin || isCompanyAdmin;
  bool get isSales => _currentUser?.role == UserRole.sales;

  String? get currentCompanyId => _currentUser?.companyId;

  /// All project IDs the current user is associated with.
  /// For project admins this is all their managed projects; for sales all assigned projects.
  List<String> get currentProjectIds => _currentUser?.projectIds ?? [];

  // currentCompany is no longer a Company object — returns null (company module removed)
  // For compatibility, kept as a getter returning null
  dynamic get currentCompany => null;

  // ─── Approval getters ─────────────────────────────────────────────────────
  List<ApprovalRequest> get pendingApprovals =>
      _approvals.where((a) => a.status == ApprovalStatus.pending).toList();

  /// Master admin sees ONLY orphaned employee-signup requests
  /// (i.e., requests for projects that have NO active project admin assigned).
  /// Requests for projects WITH a project admin are handled by that admin.
  List<ApprovalRequest> get masterAdminPendingApprovals {
    return pendingApprovals.where((a) {
      if (a.type != ApprovalType.employeeSignup) return false;
      // Check if the project has ANY active admin (using projectIds for multi-project support)
      final hasProjectAdmin = _users.any((u) =>
          (u.companyId == a.companyId || u.projectIds.contains(a.companyId)) &&
          u.role == UserRole.companyAdmin &&
          u.isApproved &&
          u.isActive);
      // Show to master admin only if no project admin exists
      return !hasProjectAdmin;
    }).toList();
  }

  List<ApprovalRequest> get companyPendingApprovals {
    if (!isCompanyAdmin) return [];
    // Include approvals for any of the admin's managed projects
    final myPids = currentProjectIds.toSet();
    if (currentCompanyId != null) myPids.add(currentCompanyId!);
    return pendingApprovals
        .where((a) =>
            a.type == ApprovalType.employeeSignup &&
            (a.companyId != null && myPids.contains(a.companyId)))
        .toList();
  }

  int get pendingApprovalCount {
    if (isMasterAdmin) return masterAdminPendingApprovals.length;
    if (isCompanyAdmin) return companyPendingApprovals.length;
    return 0;
  }

  // ─── Project-scoped getters ───────────────────────────────────────────────
  // Multi-project support:
  // - Project admins can manage multiple projects (stored in projectIds).
  // - Projects match when p.id is in the user's projectIds, or via legacy companyId/p.companyId.
  List<RealEstateProject> get companyProjects {
    if (isMasterAdmin) return _projects;
    // Multi-project: match any project whose ID is in the user's projectIds,
    // or via legacy companyId/p.companyId matching.
    final pids = currentProjectIds.toSet();
    final cid = currentCompanyId;
    if (pids.isEmpty && cid == null) return [];
    return _projects.where((p) =>
        pids.contains(p.id) ||
        (cid != null && (p.companyId == cid || p.id == cid))
    ).toList();
  }

  List<AppUser> get companyUsers {
    if (isMasterAdmin) return _users;
    // Include all users who share at least one project with the current user.
    final myProjIds = companyProjects.map((p) => p.id).toSet();
    if (myProjIds.isEmpty) return [];
    return _users.where((u) =>
        u.projectIds.any((pid) => myProjIds.contains(pid)) ||
        (u.companyId != null && myProjIds.contains(u.companyId))
    ).toList();
  }

  List<Lead> get companyLeads {
    if (isMasterAdmin) return _leads;
    final myProjectIds = companyProjects.map((p) => p.id).toSet();
    if (myProjectIds.isEmpty) return [];
    return _leads.where((l) => myProjectIds.contains(l.projectId)).toList();
  }

  List<CrmNotification> get companyNotifications {
    if (isMasterAdmin) return _notifications;
    final cid = currentCompanyId;
    final pids = currentProjectIds.toSet();
    if (cid == null && pids.isEmpty) return [];
    return _notifications.where((n) =>
        n.companyId == cid ||
        (n.projectId != null && pids.contains(n.projectId)) ||
        n.isForAll).toList();
  }

  // ─── Role-based project/lead getters ─────────────────────────────────────
  List<RealEstateProject> get myProjects {
    if (isMasterAdmin) return _projects;
    if (isCompanyAdmin) return companyProjects;
    // Sales: see a project if they are in assignedSalesIds OR the project is
    // in their projectIds list (multi-project support).
    final uid = _currentUser?.id;
    final myPids = currentProjectIds.toSet();
    return _projects.where((p) =>
        (uid != null && p.assignedSalesIds.contains(uid)) ||
        myPids.contains(p.id)
    ).toList();
  }

  List<Lead> get myLeads {
    if (isMasterAdmin) return _leads;
    if (isCompanyAdmin) return companyLeads;
    // Sales: see leads assigned to them OR leads belonging to their projects
    final uid = _currentUser?.id;
    final myProjectIds = myProjects.map((p) => p.id).toSet();
    return companyLeads.where((l) =>
        (uid != null && l.assignedToId == uid) ||
        myProjectIds.contains(l.projectId)
    ).toList();
  }

  List<Lead> myLeadsForProject(String projectId) {
    if (isAdmin) return companyLeads.where((l) => l.projectId == projectId).toList();
    // Sales can see all leads in their project, not just their own assigned leads
    return companyLeads.where((l) => l.projectId == projectId).toList();
  }

  List<AppUser> get salesUsers =>
      companyUsers.where((u) => u.role == UserRole.sales && u.isApproved).toList();

  List<CrmNotification> get myNotifications {
    if (_currentUser == null) return [];
    final base = companyNotifications;
    return base.where((n) {
      if (n.isForAll) return true;
      return n.targetUserIds.contains(_currentUser!.id);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get unreadNotificationCount =>
      myNotifications.where((n) => !n.isRead).length;

  // ─── Analytics ────────────────────────────────────────────────────────────
  // All analytics use myLeads / myProjects so they are automatically scoped:
  //   Master Admin  → all leads / all projects
  //   Project Admin → only their company's leads / projects
  //   Sales         → only leads assigned to them

  Map<LeadStatus, int> get leadsByStatus {
    final src = myLeads;
    final map = <LeadStatus, int>{};
    for (final s in LeadStatus.values) {
      map[s] = src.where((l) => l.status == s).length;
    }
    return map;
  }

  double get conversionRate {
    final src = myLeads;
    if (src.isEmpty) return 0.0;
    return (src.where((l) => l.status == LeadStatus.closed).length / src.length) * 100;
  }

  /// Total revenue from closed leads (with closedValue set), scoped to role.
  double get closedLeadsRevenue {
    return myLeads
        .where((l) => l.status == LeadStatus.closed && l.closedValue != null)
        .fold(0.0, (sum, l) => sum + l.closedValue!);
  }

  List<Lead> get recentLeads {
    final src = myLeads;
    final sorted = List<Lead>.from(src)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(5).toList();
  }

  List<Lead> get myRecentLeads {
    final sorted = List<Lead>.from(myLeads)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(5).toList();
  }

  List<Lead> get todaysLeads {
    final today = DateTime.now();
    return myLeads.where((l) =>
        l.createdAt.year == today.year &&
        l.createdAt.month == today.month &&
        l.createdAt.day == today.day).toList();
  }

  List<Lead> get upcomingSiteVisits {
    return myLeads.where((l) =>
        l.status == LeadStatus.siteVisit &&
        l.siteVisitDate != null &&
        l.siteVisitDate!.isNotEmpty).toList();
  }

  List<Lead> get pendingFollowUps {
    return myLeads.where((l) =>
        l.followUpDate != null && l.followUpDate!.isNotEmpty).toList();
  }

  Map<String, Map<String, int>> get projectStats {
    final map = <String, Map<String, int>>{};
    for (final p in myProjects) {
      final pLeads = myLeads.where((l) => l.projectId == p.id);
      map[p.id] = {
        'total': pLeads.length,
        'closed': pLeads.where((l) => l.status == LeadStatus.closed).length,
        'siteVisit': pLeads.where((l) => l.status == LeadStatus.siteVisit).length,
      };
    }
    return map;
  }

  // ─── Master Admin analytics ───────────────────────────────────────────────
  int get totalAllLeads => _leads.length;
  int get totalAllUsers => _users.length;

  // ─── Master Admin Project & Lead Analytics ─────────────────────────────────
  int get totalAllProjects => _projects.length;
  int get totalAllClosures => _leads.where((l) => l.status == LeadStatus.closed).length;
  double get overallConversionRate {
    if (_leads.isEmpty) return 0.0;
    return (totalAllClosures / _leads.length) * 100;
  }

  /// Total revenue across ALL projects (master admin view).
  double get totalAllRevenue => _leads
      .where((l) => l.status == LeadStatus.closed && l.closedValue != null)
      .fold(0.0, (sum, l) => sum + l.closedValue!);

  /// Returns per-project stats including all admin info and revenue.
  Map<String, Map<String, dynamic>> get allProjectsStats {
    final map = <String, Map<String, dynamic>>{};
    for (final p in _projects) {
      final pLeads = _leads.where((l) => l.projectId == p.id).toList();
      final closedLeads = pLeads.where((l) => l.status == LeadStatus.closed).toList();
      final revenue = closedLeads
          .where((l) => l.closedValue != null)
          .fold(0.0, (double sum, l) => sum + l.closedValue!);
      // Multi-admin: collect ALL admins for this project
      final admins = _users.where(
        (u) => (u.companyId == p.id || u.projectIds.contains(p.id) ||
                p.adminIds.contains(u.id)) &&
                u.role == UserRole.companyAdmin && u.isApproved,
      ).toList();
      final adminName = admins.isNotEmpty
          ? admins.map((a) => a.name).join(', ')
          : 'No admin assigned';
      map[p.id] = {
        'project': p,
        'adminName': adminName,
        'totalLeads': pLeads.length,
        'closed': closedLeads.length,
        'siteVisit': pLeads.where((l) => l.status == LeadStatus.siteVisit).length,
        'newLeads': pLeads.where((l) => l.status == LeadStatus.newLead).length,
        'conversionRate': pLeads.isEmpty ? 0.0 : (closedLeads.length / pLeads.length) * 100,
        'revenue': revenue,
      };
    }
    return map;
  }

  Map<LeadStatus, int> get globalLeadsByStatus {
    final map = <LeadStatus, int>{};
    for (final s in LeadStatus.values) {
      map[s] = _leads.where((l) => l.status == s).length;
    }
    return map;
  }

  int usersForProject(String projectId) =>
      _users.where((u) =>
          (u.companyId == projectId || u.projectIds.contains(projectId)) &&
          u.isApproved).length;

  int leadsForProject(String projectId) =>
      _leads.where((l) => l.projectId == projectId).length;

  // ─── Init ─────────────────────────────────────────────────────────────────
  // ─── OTP / Forgot-Password store (in-memory, expires 10 min) ─────────────
  final Map<String, _OtpEntry> _otpStore = {};

  /// Generate a 6-digit OTP for password reset and store it.
  String generatePasswordResetOtp(String email) {
    final otp = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    _otpStore[email.toLowerCase()] = _OtpEntry(otp, DateTime.now().add(const Duration(minutes: 10)));
    _sendEmail(
      toEmail: email,
      toName: email.split('@').first,
      subject: '🔐 Your RLA CRM Password Reset OTP',
      body: '''
Hello,

Your one-time password (OTP) for resetting your RLA CRM account password is:

  $otp

This OTP is valid for 10 minutes. Do not share it with anyone.

If you did not request this, please ignore this email.

Best regards,
RLA CRM Platform
      ''',
      triggerEvent: 'password_reset_otp',
    );
    if (kDebugMode) debugPrint('🔐 OTP for $email: $otp');
    return otp;
  }

  /// Validate OTP and return error string or null on success.
  String? verifyOtp(String email, String otp) {
    final entry = _otpStore[email.toLowerCase()];
    if (entry == null) return 'No OTP requested for this email';
    if (DateTime.now().isAfter(entry.expiry)) {
      _otpStore.remove(email.toLowerCase());
      return 'OTP has expired. Please request a new one.';
    }
    if (entry.code != otp.trim()) return 'Incorrect OTP. Please try again.';
    return null;
  }

  /// Reset password after OTP verified. Returns error string or null.
  String? resetPassword(String email, String newPassword) {
    try {
      final user = _users.firstWhere((u) => u.email.toLowerCase() == email.toLowerCase());
      final updated = AppUser(
        id: user.id, name: user.name, email: user.email,
        password: newPassword,
        role: user.role, isActive: user.isActive, isApproved: user.isApproved,
        hasLoggedInBefore: user.hasLoggedInBefore,
        createdAt: user.createdAt, companyId: user.companyId, companyName: user.companyName,
        projectIds: user.projectIds,
      );
      _saveUser(updated);
      _otpStore.remove(email.toLowerCase());
      
      notifyListeners();
      return null;
    } catch (_) {
      return 'Email not found';
    }
  }

  /// Check if email exists in users
  bool emailExists(String email) =>
      _users.any((u) => u.email.toLowerCase() == email.toLowerCase());

  // ─── Remember Me ──────────────────────────────────────────────────────────
  String? get rememberedEmail => _settingsBox.get('remembered_email') as String?;
  String? get rememberedPassword => _settingsBox.get('remembered_password') as String?;

  void saveRememberMe(String email, String password) {
    _settingsBox.put('remembered_email', email);
    _settingsBox.put('remembered_password', password);
  }

  void clearRememberMe() {
    _settingsBox.delete('remembered_email');
    _settingsBox.delete('remembered_password');
  }

  Future<void> init() async {
    await Hive.initFlutter();

    // ── Open boxes (v10 = cloud-first era) ───────────────────────────────
    _usersBox      = await Hive.openBox('users_v10');
    _leadsBox      = await Hive.openBox('leads_v10');
    _notifBox      = await Hive.openBox('notifs_v10');
    _projectsBox   = await Hive.openBox('projects_v10');
    _approvalsBox  = await Hive.openBox('approvals_v10');
    _emailLogsBox  = await Hive.openBox('email_logs_v10');
    _settingsBox   = await Hive.openBox('settings_v10');

    // ── ALWAYS clear local cache on startup ───────────────────────────────
    // Cloud is the single source of truth. We never trust stale local data.
    // The cache is rebuilt from cloud on every startup.
    await _usersBox.clear();
    await _leadsBox.clear();
    await _notifBox.clear();
    await _projectsBox.clear();
    await _approvalsBox.clear();
    // (keep email logs and settings — they are local-only)

    // ── Pull from cloud — up to 4 attempts with escalating delays ────────
    SyncService.resetAvailability();
    SyncService.resetVersion();
    await _forcePullFromCloud();

    if (_users.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ No users after sync #1, retrying in 1s...');
      await Future.delayed(const Duration(seconds: 1));
      SyncService.resetAvailability();
      await _forcePullFromCloud();
    }
    if (_users.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ No users after sync #2, retrying in 2s...');
      await Future.delayed(const Duration(seconds: 2));
      SyncService.resetAvailability();
      await _forcePullFromCloud();
    }
    if (_users.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ No users after sync #3, retrying in 3s...');
      await Future.delayed(const Duration(seconds: 3));
      SyncService.resetAvailability();
      await _forcePullFromCloud();
    }

    // ── Ensure master admin exists on cloud ───────────────────────────────
    final hasMasterAdmin = _users.any((u) => u.role == UserRole.masterAdmin);
    if (!hasMasterAdmin) {
      if (kDebugMode) debugPrint('🔑 Master admin missing — seeding');
      await _seedMasterAdmin();
    } else {
      await _ensureMasterAdminInCloud();
    }

    WidgetsBinding.instance.addObserver(this);
    SyncService.onWriteSuccess = _scheduleImmediateSync;
    _startPeriodicSync();
  }

  Future<void> _ensureMasterAdminInCloud() async {
    try {
      // Preserve the existing master admin record if we have it
      // (so hasLoggedInBefore is not reset on every startup)
      AppUser? existing;
      try { existing = _users.firstWhere((u) => u.id == 'master_admin_001'); } catch (_) {}
      final masterAdmin = existing ?? AppUser(
        id: 'master_admin_001',
        name: 'Aksayal',
        email: 'aksayal@gmail.com',
        password: '09101991',
        role: UserRole.masterAdmin,
        companyId: null,
        isApproved: true,
        hasLoggedInBefore: true,
      );
      await SyncService.upsert(SyncService.kUsers, masterAdmin.toMap());
      if (kDebugMode) debugPrint('✅ Master admin ensured in cloud');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Could not push master admin: $e');
    }
  }

  Future<void> _seedMasterAdmin() async {
    final masterAdmin = AppUser(
      id: 'master_admin_001',
      name: 'Aksayal',
      email: 'aksayal@gmail.com',
      password: '09101991',
      role: UserRole.masterAdmin,
      companyId: null,
      isApproved: true,
      hasLoggedInBefore: true,
    );
    // Write to cloud first
    await SyncService.upsert(SyncService.kUsers, masterAdmin.toMap());
    // Update in-memory
    _users = [masterAdmin];
    // Update cache
    _usersBox.put(masterAdmin.id, jsonEncode(masterAdmin.toMap()));
    notifyListeners();
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncService.resetAvailability();
      SyncService.resetVersion();
      _syncFromCloud();
    }
  }

  // ── Periodic version poll (every 3s) ──────────────────────────────────────
  void _startPeriodicSync() {
    _versionTimer?.cancel();
    _versionTimer = Timer.periodic(_versionPollInterval, (_) async {
      final changed = await SyncService.hasCloudChanged();
      if (changed) await _syncFromCloud();
    });
  }

  void _stopPeriodicSync() {
    _versionTimer?.cancel();
    _versionTimer = null;
    _immediateTimer?.cancel();
    _immediateTimer = null;
  }

  /// Schedule a cloud pull 3s after a confirmed write.
  /// 3s gives the cloud storage enough time to persist before we re-pull.
  /// Does NOT reset version — lets the normal version poll detect the change
  /// so the periodic timer doesn't race against this timer.
  void _scheduleImmediateSync() {
    _immediateTimer?.cancel();
    _immediateTimer = Timer(const Duration(seconds: 3), () async {
      // Don't reset version here — the upsert already updated _lastKnownVersion.
      // Just force a fresh pull to confirm cloud state matches local state.
      await _forcePullFromCloud();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPeriodicSync();
    SyncService.stopRetryTimer();
    super.dispose();
  }

  // ─── Cloud sync: cloud is the single source of truth ────────────────────
  // On every pull we REPLACE the in-memory lists and the Hive cache entirely
  // from cloud data. There is no merge, no push-back, no conflict resolution.
  // The cloud version always wins.
  // ── Force pull — bypasses _syncInProgress guard (used during login/init) ──
  Future<void> _forcePullFromCloud() async {
    _syncInProgress = false; // clear any stale lock
    await _syncFromCloud();
  }

  Future<void> _syncFromCloud() async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      final pullResult = await SyncService.pullAll();
      // If the pull failed (version == -1) keep showing whatever is in memory
      if (pullResult.version < 0) {
        if (kDebugMode) debugPrint('⚠️ pullAll failed — keeping current state');
        return;
      }

      final remote = pullResult.collections;

      // ── Replace in-memory lists entirely from cloud ───────────────────────
      final remoteUsers = remote[SyncService.kUsers] ?? [];
      final remoteLeads = remote[SyncService.kLeads] ?? [];
      final remoteProjects = remote[SyncService.kProjects] ?? [];
      final remoteApprovals = remote[SyncService.kApprovals] ?? [];
      final remoteNotifs = remote[SyncService.kNotifications] ?? [];

      // Parse — skip any malformed records gracefully
      final newUsers = <AppUser>[];
      for (final raw in remoteUsers) {
        try { newUsers.add(AppUser.fromMap(raw)); } catch (e) {
          if (kDebugMode) debugPrint('⚠️ parse user: $e');
        }
      }
      final newLeads = <Lead>[];
      for (final raw in remoteLeads) {
        try { newLeads.add(Lead.fromMap(raw)); } catch (e) {
          if (kDebugMode) debugPrint('⚠️ parse lead: $e');
        }
      }
      final newProjects = <RealEstateProject>[];
      for (final raw in remoteProjects) {
        try { newProjects.add(RealEstateProject.fromMap(raw)); } catch (e) {
          if (kDebugMode) debugPrint('⚠️ parse project: $e');
        }
      }
      final newApprovals = <ApprovalRequest>[];
      for (final raw in remoteApprovals) {
        try { newApprovals.add(ApprovalRequest.fromMap(raw)); } catch (e) {
          if (kDebugMode) debugPrint('⚠️ parse approval: $e');
        }
      }
      final newNotifs = <CrmNotification>[];
      for (final raw in remoteNotifs) {
        try {
          final n = CrmNotification.fromMap(raw);
          // Preserve local isRead state for notifications we already have
          final existing = _notifications.where((x) => x.id == n.id);
          if (existing.isNotEmpty) n.isRead = existing.first.isRead;
          newNotifs.add(n);
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ parse notif: $e');
        }
      }

      _users         = newUsers;
      _leads         = newLeads;
      _projects      = newProjects;
      _approvals     = newApprovals;
      _notifications = newNotifs;

      // ── Update Hive cache (page-refresh speed-up only) ────────────────────
      await _replaceCache();

      notifyListeners();

      if (kDebugMode) {
        debugPrint('☁️ sync v${pullResult.version}: '
            '${_users.length}u ${_leads.length}l '
            '${_projects.length}p ${_approvals.length}a ${_notifications.length}n');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ _syncFromCloud error: $e');
    } finally {
      _syncInProgress = false;
    }
  }

  // ── Replace Hive cache entirely from current in-memory state ─────────────
  Future<void> _replaceCache() async {
    await _usersBox.clear();
    await _leadsBox.clear();
    await _notifBox.clear();
    await _projectsBox.clear();
    await _approvalsBox.clear();
    for (final u in _users)         { _usersBox.put(u.id,    jsonEncode(u.toMap())); }
    for (final l in _leads)         { _leadsBox.put(l.id,    jsonEncode(l.toMap())); }
    for (final n in _notifications) { _notifBox.put(n.id,    jsonEncode(n.toMap())); }
    for (final p in _projects)      { _projectsBox.put(p.id, jsonEncode(p.toMap())); }
    for (final a in _approvals)     { _approvalsBox.put(a.id, jsonEncode(a.toMap())); }
  }

  // ─── Cache load (page-refresh speed-up only) ─────────────────────────────
  // Populates in-memory lists from Hive so the UI is non-empty during the
  // ~300ms before the first cloud pull completes. This is READ-ONLY;
  // the data is immediately replaced by the cloud pull that follows.
  void _loadFromCache() {
    try {
      _users = _usersBox.values
          .map((v) => AppUser.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
          .toList();
    } catch (_) { _users = []; }
    try {
      _leads = _leadsBox.values
          .map((v) => Lead.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
          .toList();
    } catch (_) { _leads = []; }
    try {
      _notifications = _notifBox.values
          .map((v) => CrmNotification.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
          .toList();
    } catch (_) { _notifications = []; }
    try {
      _projects = _projectsBox.values
          .map((v) => RealEstateProject.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
          .toList();
    } catch (_) { _projects = []; }
    try {
      _approvals = _approvalsBox.values
          .map((v) => ApprovalRequest.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
          .toList();
    } catch (_) { _approvals = []; }
    try {
      _emailLogs = _emailLogsBox.values
          .map((v) => EmailLog.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
          .toList();
    } catch (_) { _emailLogs = []; }
  }

  // ─── Write helpers: cloud-first ───────────────────────────────────────────
  // 1. Update in-memory list immediately (optimistic UI update)
  // 2. Write to cloud — on failure the retry queue will re-send
  // 3. Schedule an immediate re-pull (1s) to confirm cloud state
  // Hive cache is updated by _replaceCache() which runs on every cloud pull.

  void _saveUser(AppUser u) {
    // Optimistic update — add to memory immediately
    _users = [ ..._users.where((x) => x.id != u.id), u ];
    notifyListeners();
    // Schedule re-pull ONLY after cloud confirms the write
    SyncService.upsert(SyncService.kUsers, u.toMap()).then((ok) {
      if (ok) {
        _scheduleImmediateSync();
      } else {
        if (kDebugMode) debugPrint('⚠️ _saveUser cloud failed: ${u.id} — queued for retry');
      }
    });
  }

  void _saveLead(Lead l) {
    _leads = [ ..._leads.where((x) => x.id != l.id), l ];
    notifyListeners();
    SyncService.upsert(SyncService.kLeads, l.toMap()).then((ok) {
      if (ok) {
        _scheduleImmediateSync();
      } else {
        if (kDebugMode) debugPrint('⚠️ _saveLead cloud failed: ${l.id} — queued for retry');
      }
    });
  }

  void _saveNotification(CrmNotification n) {
    _notifications = [ ..._notifications.where((x) => x.id != n.id), n ];
    SyncService.upsert(SyncService.kNotifications, n.toMap()).then((ok) {
      if (!ok && kDebugMode) debugPrint('⚠️ _saveNotif cloud failed: ${n.id} — queued');
    });
    // isRead changes are local only — no immediate re-sync needed
    notifyListeners();
  }

  void _saveProject(RealEstateProject p) {
    _projects = [ ..._projects.where((x) => x.id != p.id), p ];
    notifyListeners();
    SyncService.upsert(SyncService.kProjects, p.toMap()).then((ok) {
      if (ok) {
        _scheduleImmediateSync();
      } else {
        if (kDebugMode) debugPrint('⚠️ _saveProject cloud failed: ${p.id} — queued for retry');
      }
    });
  }

  void _saveApproval(ApprovalRequest a) {
    _approvals = [ ..._approvals.where((x) => x.id != a.id), a ];
    notifyListeners();
    SyncService.upsert(SyncService.kApprovals, a.toMap()).then((ok) {
      if (ok) {
        _scheduleImmediateSync();
      } else {
        if (kDebugMode) debugPrint('⚠️ _saveApproval cloud failed: ${a.id} — queued for retry');
      }
    });
  }

  void _saveEmailLog(EmailLog e) {
    _emailLogs = [ ..._emailLogs.where((x) => x.id != e.id), e ];
    _emailLogsBox.put(e.id, jsonEncode(e.toMap()));
  }

  // ─── Email Simulation ─────────────────────────────────────────────────────
  void _sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String body,
    required String triggerEvent,
  }) {
    final log = EmailLog(
      toEmail: toEmail,
      toName: toName,
      subject: subject,
      body: body,
      triggerEvent: triggerEvent,
    );
    _saveEmailLog(log);
    if (kDebugMode) {
      debugPrint('📧 [EMAIL SIMULATED] To: $toEmail | Subject: $subject');
    }
  }

  // ─── Authentication ── CLOUD ONLY ─────────────────────────────────────────
  // Login ALWAYS authenticates against the live cloud data.
  // No local cache is ever used for authentication — this ensures every device
  // (incognito, new browser, different laptop) always sees the same accounts.
  Future<String?> loginWithErrorAsync(String emailOrUsername, String password) async {
    final email = emailOrUsername.trim().toLowerCase();

    // ── Force a fresh cloud pull before every login attempt ──────────────
    // Up to 4 attempts with progressive delays to handle slow connections.
    // Uses _forcePullFromCloud() to bypass any stale _syncInProgress lock.
    for (int attempt = 1; attempt <= 4; attempt++) {
      SyncService.resetAvailability();
      SyncService.resetVersion();
      await _forcePullFromCloud();

      final found = _users.any((u) =>
          u.email.toLowerCase() == email ||
          u.name.toLowerCase() == email);
      if (found) break;

      if (attempt < 4) {
        if (kDebugMode) debugPrint('⚠️ User not found after cloud sync #$attempt, retrying...');
        await Future.delayed(Duration(milliseconds: 700 * attempt));
      }
    }

    AppUser? user;
    try {
      user = _users.firstWhere((u) =>
          u.email.toLowerCase() == email ||
          u.name.toLowerCase() == email);
    } catch (_) {
      return 'Account not found. Please check your email or contact your admin.';
    }

    if (user.password != password) return 'Incorrect password. Please try again.';
    if (!user.isApproved) return 'Your account is pending approval. Please contact the admin.';
    if (!user.isActive)   return 'Your account has been deactivated. Please contact the admin.';

    _currentUser = user;
    notifyListeners();
    unawaited(_syncFromCloud()); // pull remaining data in background
    return null;
  }

  /// Synchronous login — only used internally; always prefer loginWithErrorAsync.
  String? loginWithError(String emailOrUsername, String password) {
    final email = emailOrUsername.trim().toLowerCase();
    AppUser? user;
    try {
      user = _users.firstWhere((u) => u.email.toLowerCase() == email);
    } catch (_) {
      return 'Account not found. Please check your email or contact your admin.';
    }
    if (user.password != password) return 'Incorrect password. Please try again.';
    if (!user.isApproved) return 'Your account is pending approval. Please contact the admin.';
    if (!user.isActive)   return 'Your account has been deactivated. Please contact the admin.';
    _currentUser = user;
    notifyListeners();
    _syncFromCloud();
    return null;
  }

  bool login(String emailOrUsername, String password) {
    return loginWithError(emailOrUsername, password) == null;
  }

  /// Manual refresh from cloud — call this from pull-to-refresh or on app resume
  Future<void> refreshFromCloud() => _syncFromCloud();

  /// Returns true if sync service is available (has network + API reachable)
  bool get isSyncAvailable => SyncService.isAvailable;

  void logout() {
    _currentUser = null;
    // Force a fresh cloud pull on next login attempt
    SyncService.resetVersion();
    notifyListeners();
  }

  void markFirstLoginDone() {
    if (_currentUser == null) return;
    final updated = AppUser(
      id: _currentUser!.id,
      name: _currentUser!.name,
      email: _currentUser!.email,
      password: _currentUser!.password,
      role: _currentUser!.role,
      isActive: _currentUser!.isActive,
      isApproved: _currentUser!.isApproved,
      hasLoggedInBefore: true,
      createdAt: _currentUser!.createdAt,
      companyId: _currentUser!.companyId,
      companyName: _currentUser!.companyName,
      projectIds: _currentUser!.projectIds,
    );
    _saveUser(updated);
    _currentUser = updated;
    
    notifyListeners();
  }

  // ─── Signup / Approval Flow ───────────────────────────────────────────────

  /// Employee (Sales Team) signup → goes to Project Admin for approval.
  /// [companyId] stores the projectId in the project-centric flow.
  SignupResult submitEmployeeSignup({
    required String name,
    required String email,
    required String password,
    required String companyId,   // projectId in the new flow
  }) {
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return const SignupResult(error: 'Email already registered');
    }
    if (_approvals.any((a) =>
        a.applicantEmail.toLowerCase() == email.toLowerCase() &&
        a.status == ApprovalStatus.pending)) {
      return const SignupResult(error: 'A signup request with this email is already pending');
    }

    // Resolve project name from projects list
    String projectName = 'Unknown Project';
    try {
      final proj = _projects.firstWhere((p) => p.id == companyId);
      projectName = proj.name;
    } catch (_) {
      try {
        final proj = _projects.firstWhere((p) => p.companyId == companyId);
        projectName = proj.name;
      } catch (_) {}
    }

    final req = ApprovalRequest(
      type: ApprovalType.employeeSignup,
      applicantName: name,
      applicantEmail: email,
      companyId: companyId,   // stores projectId
      companyName: projectName,
      password: password,
      role: 'sales',
    );
    _saveApproval(req);
    
    notifyListeners();

    // Notify project admins
    final projectAdmins = _users.where((u) =>
        u.companyId == companyId && u.role == UserRole.companyAdmin && u.isApproved);
    for (final ca in projectAdmins) {
      _sendEmail(
        toEmail: ca.email,
        toName: ca.name,
        subject: '👤 New Sales Team Signup: $name',
        body: '''
Hello ${ca.name},

A new sales team member has requested to join $projectName on RLA CRM.

Name: $name
Email: $email
Requested Role: Sales Team

Please log in to RLA CRM → Team → Pending Approvals to review this request.

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'employee_signup_submitted',
      );
    }

    _sendEmail(
      toEmail: email,
      toName: name,
      subject: '✅ Signup Request Received – $projectName',
      body: '''
Hello $name,

Your request to join $projectName on RLA CRM has been received and is awaiting approval from the project admin.

You will be notified by email once your account is approved.

Best regards,
RLA CRM Platform
      ''',
      triggerEvent: 'employee_signup_applicant_confirmation',
    );

    return const SignupResult(pendingApproval: true);
  }

  // ─── Approval Management ──────────────────────────────────────────────────

  /// Approve an employee signup (Project Admin or Master Admin)
  void approveEmployeeSignup(String approvalId, {String? note}) {
    try {
      final req = _approvals.firstWhere((a) => a.id == approvalId);
      req.status = ApprovalStatus.approved;
      req.reviewedBy = _currentUser?.name;
      req.reviewNote = note;
      req.updatedAt = DateTime.now();

      // Resolve display name from project
      String entityName = req.companyName ?? 'the project';
      try {
        final proj = _projects.firstWhere((p) => p.id == req.companyId);
        entityName = proj.name;
      } catch (_) {}

      final role = req.role == 'admin' ? UserRole.companyAdmin : UserRole.sales;
      final user = AppUser(
        name: req.applicantName,
        email: req.applicantEmail,
        password: req.password ?? 'changeme123',
        role: role,
        companyId: req.companyId,    // companyId == projectId for project-scoped users
        companyName: entityName,
        isApproved: true,
        hasLoggedInBefore: false,
        projectIds: req.companyId != null ? [req.companyId!] : [],
      );
      _saveUser(user);
      _saveApproval(req);

      // ── CRITICAL: Auto-add sales user to project's assignedSalesIds ──────────
      // This ensures the sales user sees their project immediately upon approval,
      // without requiring the admin to manually edit the project.
      if (role == UserRole.sales && req.companyId != null) {
        try {
          final proj = _projects.firstWhere((p) => p.id == req.companyId);
          if (!proj.assignedSalesIds.contains(user.id)) {
            final updatedProj = RealEstateProject(
              id: proj.id,
              name: proj.name,
              location: proj.location,
              description: proj.description,
              developerName: proj.developerName,
              propertyType: proj.propertyType,
              priceFrom: proj.priceFrom,
              priceTo: proj.priceTo,
              status: proj.status,
              assignedSalesIds: [...proj.assignedSalesIds, user.id],
              adminIds: proj.adminIds,
              createdById: proj.createdById,
              createdByName: proj.createdByName,
              createdAt: proj.createdAt,
              updatedAt: DateTime.now(),
              totalUnits: proj.totalUnits,
              reraNumber: proj.reraNumber,
              companyId: proj.companyId,
            );
            _saveProject(updatedProj);
          }
        } catch (_) {}
      }

      
      notifyListeners();

      _sendEmail(
        toEmail: req.applicantEmail,
        toName: req.applicantName,
        subject: '🎉 Welcome to $entityName – RLA CRM',
        body: '''
Hello ${req.applicantName},

Your account has been approved! You can now log in to RLA CRM.

Email: ${req.applicantEmail}
Password: ${req.password ?? 'changeme123'}
Role: ${role == UserRole.companyAdmin ? 'Project Admin' : 'Sales Team'}
Project: $entityName

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'employee_signup_approved',
      );
    } catch (_) {}
  }

  /// Reject an employee signup (Project Admin or Master Admin)
  void rejectEmployeeSignup(String approvalId, {String? note}) {
    try {
      final req = _approvals.firstWhere((a) => a.id == approvalId);
      req.status = ApprovalStatus.rejected;
      req.reviewedBy = _currentUser?.name;
      req.reviewNote = note;
      req.updatedAt = DateTime.now();
      _saveApproval(req);
      
      notifyListeners();

      _sendEmail(
        toEmail: req.applicantEmail,
        toName: req.applicantName,
        subject: '❌ Signup Request Update – RLA CRM',
        body: '''
Hello ${req.applicantName},

Your request to join "${req.companyName}" has not been approved at this time.

${note != null ? 'Reason: $note\n\n' : ''}Please contact the project admin for more information.

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'employee_signup_rejected',
      );
    } catch (_) {}
  }

  // ─── Add Project Admin (Master Admin can create companyAdmin for any project) ─
  // Supports multi-project: pass a list of projectIds to assign the admin to multiple projects at once.
  String? addProjectAdmin({
    required String name,
    required String email,
    required String password,
    String? companyId,    // legacy param — maps to projectId
    String? projectId,    // single project (preferred)
    List<String>? projectIds,  // multi-project assignment
  }) {
    if (!isMasterAdmin) return 'Unauthorized';
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }
    // Build the resolved list of project IDs
    final resolvedIds = <String>{};
    if (projectIds != null) resolvedIds.addAll(projectIds);
    if (projectId != null && projectId.isNotEmpty) resolvedIds.add(projectId);
    if (companyId != null && companyId.isNotEmpty) resolvedIds.add(companyId);

    if (resolvedIds.isEmpty) return 'Project not selected';

    // Validate all projects exist
    final projects = <RealEstateProject>[];
    for (final pid in resolvedIds) {
      try {
        projects.add(_projects.firstWhere((p) => p.id == pid));
      } catch (_) {
        return 'Project not found: $pid';
      }
    }

    // Primary project is the first one for backward compat
    final primaryProject = projects.first;
    final primaryId = primaryProject.id;

    final user = AppUser(
      name: name,
      email: email,
      password: password,
      role: UserRole.companyAdmin,
      companyId: primaryId,   // user.companyId == first project.id (backward compat)
      companyName: projects.map((p) => p.name).join(', '),
      isApproved: true,
      hasLoggedInBefore: false,
      projectIds: resolvedIds.toList(),
    );
    _saveUser(user);

    // Update each project: set companyId if needed and add to adminIds
    for (final proj in projects) {
      final newAdminIds = proj.adminIds.contains(user.id)
          ? proj.adminIds
          : [...proj.adminIds, user.id];
      final needsCompanyId = proj.companyId != proj.id && proj.companyId == 'rla_platform';
      final updatedProject = RealEstateProject(
        id: proj.id,
        name: proj.name,
        location: proj.location,
        description: proj.description,
        developerName: proj.developerName,
        propertyType: proj.propertyType,
        priceFrom: proj.priceFrom,
        priceTo: proj.priceTo,
        status: proj.status,
        assignedSalesIds: proj.assignedSalesIds,
        adminIds: newAdminIds,
        createdById: proj.createdById,
        createdByName: proj.createdByName,
        createdAt: proj.createdAt,
        updatedAt: DateTime.now(),
        totalUnits: proj.totalUnits,
        reraNumber: proj.reraNumber,
        companyId: needsCompanyId ? proj.id : proj.companyId,
      );
      _saveProject(updatedProject);
    }

    
    notifyListeners();
    _sendEmail(
      toEmail: email,
      toName: name,
      subject: '🎉 Project Admin Access Granted – RLA CRM',
      body: '''
Hello $name,

You have been added as a Project Admin for "${projects.map((p) => p.name).join(', ')}" on RLA CRM by ${_currentUser?.name ?? 'Master Admin'}.

Login credentials:
Email: $email
Password: $password

Please log in and change your password.

Best regards,
RLA CRM Platform
      ''',
      triggerEvent: 'project_admin_created',
    );
    return null;
  }

  /// Assign an EXISTING project admin user to an additional project.
  /// This is the key method for multi-project admin support.
  String? assignAdminToProject({required String userId, required String projectId}) {
    if (!isMasterAdmin) return 'Unauthorized';
    AppUser adminUser;
    try {
      adminUser = _users.firstWhere((u) => u.id == userId);
    } catch (_) {
      return 'User not found';
    }
    if (adminUser.role != UserRole.companyAdmin) return 'User is not a project admin';

    RealEstateProject project;
    try {
      project = _projects.firstWhere((p) => p.id == projectId);
    } catch (_) {
      return 'Project not found';
    }

    // Add projectId to user's projectIds
    if (!adminUser.projectIds.contains(projectId)) {
      final newPids = [...adminUser.projectIds, projectId];
      // Rebuild companyName with all project names
      final allProjects = _projects.where((p) => newPids.contains(p.id)).toList();
      final updatedUser = AppUser(
        id: adminUser.id, name: adminUser.name, email: adminUser.email,
        password: adminUser.password, role: adminUser.role,
        isActive: adminUser.isActive, isApproved: adminUser.isApproved,
        hasLoggedInBefore: adminUser.hasLoggedInBefore,
        createdAt: adminUser.createdAt,
        companyId: adminUser.companyId, // keep primary
        companyName: allProjects.map((p) => p.name).join(', '),
        projectIds: newPids,
      );
      _saveUser(updatedUser);
    }

    // Add admin to project's adminIds
    if (!project.adminIds.contains(userId)) {
      final needsCompanyId = project.companyId == 'rla_platform';
      final updatedProject = RealEstateProject(
        id: project.id,
        name: project.name,
        location: project.location,
        description: project.description,
        developerName: project.developerName,
        propertyType: project.propertyType,
        priceFrom: project.priceFrom,
        priceTo: project.priceTo,
        status: project.status,
        assignedSalesIds: project.assignedSalesIds,
        adminIds: [...project.adminIds, userId],
        createdById: project.createdById,
        createdByName: project.createdByName,
        createdAt: project.createdAt,
        updatedAt: DateTime.now(),
        totalUnits: project.totalUnits,
        reraNumber: project.reraNumber,
        companyId: needsCompanyId ? project.id : project.companyId,
      );
      _saveProject(updatedProject);
    }

    
    notifyListeners();
    return null;
  }

  /// Assign a sales user to additional projects (multi-project sales assignment).
  String? assignSalesToProjects({required String userId, required List<String> projectIds}) {
    AppUser salesUser;
    try {
      salesUser = _users.firstWhere((u) => u.id == userId);
    } catch (_) {
      return 'User not found';
    }
    if (salesUser.role != UserRole.sales) return 'User is not a sales member';

    // Build updated projectIds for user
    final newPids = {...salesUser.projectIds, ...projectIds}.toList();
    final allProjects = _projects.where((p) => newPids.contains(p.id)).toList();
    final updatedUser = AppUser(
      id: salesUser.id, name: salesUser.name, email: salesUser.email,
      password: salesUser.password, role: salesUser.role,
      isActive: salesUser.isActive, isApproved: salesUser.isApproved,
      hasLoggedInBefore: salesUser.hasLoggedInBefore,
      createdAt: salesUser.createdAt,
      companyId: salesUser.companyId,
      companyName: allProjects.map((p) => p.name).join(', '),
      projectIds: newPids,
    );
    _saveUser(updatedUser);

    // Add user to each project's assignedSalesIds
    for (final pid in projectIds) {
      try {
        final proj = _projects.firstWhere((p) => p.id == pid);
        if (!proj.assignedSalesIds.contains(userId)) {
          final updatedProj = RealEstateProject(
            id: proj.id, name: proj.name, location: proj.location,
            description: proj.description, developerName: proj.developerName,
            propertyType: proj.propertyType, priceFrom: proj.priceFrom,
            priceTo: proj.priceTo, status: proj.status,
            assignedSalesIds: [...proj.assignedSalesIds, userId],
            adminIds: proj.adminIds,
            createdById: proj.createdById, createdByName: proj.createdByName,
            createdAt: proj.createdAt, updatedAt: DateTime.now(),
            totalUnits: proj.totalUnits, reraNumber: proj.reraNumber,
            companyId: proj.companyId,
          );
          _saveProject(updatedProj);
        }
      } catch (_) {}
    }

    
    notifyListeners();
    return null;
  }

  // ─── CRUD: Master Admins ──────────────────────────────────────────────────
  String? createMasterAdmin({
    required String name,
    required String email,
    required String password,
  }) {
    if (!isMasterAdmin) return 'Unauthorized';
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }
    final user = AppUser(
      name: name,
      email: email,
      password: password,
      role: UserRole.masterAdmin,
      isApproved: true,
      hasLoggedInBefore: false,
    );
    _saveUser(user);
    
    notifyListeners();

    _sendEmail(
      toEmail: email,
      toName: name,
      subject: '🔑 Master Admin Access Granted – RLA CRM',
      body: '''
Hello $name,

You have been granted Master Admin access to RLA CRM by ${_currentUser?.name}.

Login credentials:
Email: $email
Password: $password

Please log in and change your password.

Best regards,
RLA CRM Platform
      ''',
      triggerEvent: 'master_admin_created',
    );

    return null;
  }

  List<AppUser> get masterAdmins =>
      _users.where((u) => u.role == UserRole.masterAdmin).toList();

  // ─── CRUD: Projects ───────────────────────────────────────────────────────
  void addProject(RealEstateProject p) { _saveProject(p); }
  void updateProject(RealEstateProject p) { p.updatedAt = DateTime.now(); _saveProject(p); }
  void deleteProject(String id) {
    _projects = _projects.where((p) => p.id != id).toList();
    notifyListeners();
    SyncService.delete(SyncService.kProjects, id);
    _scheduleImmediateSync();
  }

  // ─── CRUD: Users ──────────────────────────────────────────────────────────
  void addUser(AppUser u) { _saveUser(u); }
  void updateUser(AppUser u) { _saveUser(u); }
  void deleteUser(String id) {
    _users = _users.where((u) => u.id != id).toList();
    notifyListeners();
    SyncService.delete(SyncService.kUsers, id);
    _scheduleImmediateSync();
  }

  /// Add a user and also assign them to the given project's assignedSalesIds list.
  void addUserAndAssignToProject(AppUser u, String? projectId) {
    // Build projectIds including the assigned project
    final pids = u.projectIds.toList();
    if (projectId != null && !pids.contains(projectId)) pids.add(projectId);
    final userWithProjects = AppUser(
      id: u.id, name: u.name, email: u.email, password: u.password,
      role: u.role, isActive: u.isActive, isApproved: u.isApproved,
      hasLoggedInBefore: u.hasLoggedInBefore, createdAt: u.createdAt,
      companyId: u.companyId ?? projectId, companyName: u.companyName,
      projectIds: pids,
    );
    _saveUser(userWithProjects);
    if (projectId != null && u.role == UserRole.sales) {
      try {
        final project = _projects.firstWhere((p) => p.id == projectId);
        if (!project.assignedSalesIds.contains(userWithProjects.id)) {
          final updatedProject = RealEstateProject(
            id: project.id,
            name: project.name,
            location: project.location,
            description: project.description,
            developerName: project.developerName,
            propertyType: project.propertyType,
            priceFrom: project.priceFrom,
            priceTo: project.priceTo,
            status: project.status,
            assignedSalesIds: [...project.assignedSalesIds, userWithProjects.id],
            adminIds: project.adminIds,
            createdById: project.createdById,
            createdByName: project.createdByName,
            createdAt: project.createdAt,
            updatedAt: DateTime.now(),
            totalUnits: project.totalUnits,
            reraNumber: project.reraNumber,
            companyId: project.companyId,
          );
          _saveProject(updatedProject);
        }
      } catch (_) {}
    }
  }

  void toggleUserActive(String id) {
    try {
      final u = _users.firstWhere((u) => u.id == id);
      final updated = AppUser(
        id: u.id, name: u.name, email: u.email, password: u.password,
        role: u.role, isActive: !u.isActive, isApproved: u.isApproved,
        hasLoggedInBefore: u.hasLoggedInBefore,
        createdAt: u.createdAt, companyId: u.companyId, companyName: u.companyName,
        projectIds: u.projectIds,
      );
      _saveUser(updated);
    } catch (_) {}
  }

  // ─── CRUD: Leads ──────────────────────────────────────────────────────────
  void addLead(Lead l) { _saveLead(l); }
  void updateLead(Lead l) { l.updatedAt = DateTime.now(); _saveLead(l); }
  void deleteLead(String id) {
    _leads = _leads.where((l) => l.id != id).toList();
    notifyListeners();
    SyncService.delete(SyncService.kLeads, id).then((ok) {
      if (!ok && kDebugMode) debugPrint('⚠️ Cloud delete failed for lead $id — will retry');
    });
    _scheduleImmediateSync();
  }

  // ─── CRUD: Notifications ──────────────────────────────────────────────────
  void addNotification(CrmNotification n) { _saveNotification(n); }
  void deleteNotification(String id) {
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();
    SyncService.delete(SyncService.kNotifications, id);
  }
  void markNotificationRead(String id) {
    try {
      final n = _notifications.firstWhere((n) => n.id == id);
      n.isRead = true;
      _saveNotification(n);
    } catch (_) {}
  }
  void markAllNotificationsRead() {
    for (final n in myNotifications.where((n) => !n.isRead)) {
      n.isRead = true;
      _saveNotification(n);
    }
    notifyListeners();
  }

  // ─── Flush all platform data except master admin ───────────────────────────
  /// Wipes every user (except master admin), every project, lead, approval,
  /// notification, and email log — both from local Hive and from the cloud.
  /// The master admin record is preserved and re-seeded if needed.
  /// Returns null on success, or an error string on failure.
  Future<String?> flushAllDataExceptMasterAdmin() async {
    if (!isMasterAdmin) return 'Unauthorized';
    try {
      // 1. Stop sync timers to prevent re-pulling data during flush
      _versionTimer?.cancel();
      _versionTimer = null;
      _immediateTimer?.cancel();
      _immediateTimer = null;

      // 2. Capture master admin record BEFORE wiping anything
      const masterAdminId = 'master_admin_001';
      AppUser? masterAdmin;
      try {
        masterAdmin = _users.firstWhere((u) => u.id == masterAdminId);
      } catch (_) {}
      // Fallback: reconstruct from known credentials
      masterAdmin ??= AppUser(
        id: masterAdminId,
        name: 'Aksayal',
        email: 'aksayal@gmail.com',
        password: '09101991',
        role: UserRole.masterAdmin,
        companyId: null,
        isApproved: true,
        hasLoggedInBefore: true,
      );

      // 3. Clear in-memory state immediately
      _users         = [masterAdmin];
      _leads         = [];
      _projects      = [];
      _approvals     = [];
      _notifications = [];
      _emailLogs     = [];
      notifyListeners();

      // 4. Flush Hive cache and re-seed master admin
      await _usersBox.clear();
      await _leadsBox.clear();
      await _projectsBox.clear();
      await _approvalsBox.clear();
      await _notifBox.clear();
      await _emailLogsBox.clear();
      _usersBox.put(masterAdmin.id, jsonEncode(masterAdmin.toMap()));

      // 5. Flush the cloud (delete all records except master admin user)
      await SyncService.flushCloudExceptMasterAdmin(masterAdminId: masterAdminId);

      // 6. Re-push master admin to cloud to ensure it is preserved
      await SyncService.upsert(SyncService.kUsers, masterAdmin.toMap());

      // 7. Restart sync timers
      _startPeriodicSync();

      if (kDebugMode) debugPrint('✅ Platform flush complete — master admin preserved');
      return null; // success
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ flushAllDataExceptMasterAdmin: $e');
      // Restart sync timers even on error
      _startPeriodicSync();
      return 'Flush failed: $e';
    }
  }
}

// ─── OTP Entry ────────────────────────────────────────────────────────────────
class _OtpEntry {
  final String code;
  final DateTime expiry;
  _OtpEntry(this.code, this.expiry);
}
