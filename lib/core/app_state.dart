import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

// ─── Signup Result ────────────────────────────────────────────────────────────
class SignupResult {
  final String? error;
  final bool promotedToAdmin;
  final bool pendingApproval;
  const SignupResult({this.error, this.promotedToAdmin = false, this.pendingApproval = false});
  bool get success => error == null;
}

class AppState extends ChangeNotifier {
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

  // currentCompany is no longer a Company object — returns null (company module removed)
  // For compatibility, kept as a getter returning null
  dynamic get currentCompany => null;

  // ─── Approval getters ─────────────────────────────────────────────────────
  List<ApprovalRequest> get pendingApprovals =>
      _approvals.where((a) => a.status == ApprovalStatus.pending).toList();

  /// Master admin sees all pending employee-signup requests (no company registration)
  List<ApprovalRequest> get masterAdminPendingApprovals =>
      pendingApprovals.where((a) => a.type == ApprovalType.employeeSignup).toList();

  List<ApprovalRequest> get companyPendingApprovals {
    if (!isCompanyAdmin) return [];
    return pendingApprovals
        .where((a) =>
            a.type == ApprovalType.employeeSignup &&
            a.companyId == currentCompanyId)
        .toList();
  }

  int get pendingApprovalCount {
    if (isMasterAdmin) return masterAdminPendingApprovals.length;
    if (isCompanyAdmin) return companyPendingApprovals.length;
    return 0;
  }

  // ─── Project-scoped getters ───────────────────────────────────────────────
  // NOTE: For project admins created by master admin, their companyId == projectId.
  // Projects created by master admin start with companyId='rla_platform' until an admin is assigned.
  // We match on BOTH p.companyId == currentCompanyId AND p.id == currentCompanyId.
  List<RealEstateProject> get companyProjects {
    if (isMasterAdmin) return _projects;
    final cid = currentCompanyId;
    if (cid == null) return [];
    return _projects.where((p) => p.companyId == cid || p.id == cid).toList();
  }

  List<AppUser> get companyUsers {
    if (isMasterAdmin) return _users;
    final cid = currentCompanyId;
    if (cid == null) return [];
    return _users.where((u) => u.companyId == cid).toList();
  }

  List<Lead> get companyLeads {
    if (isMasterAdmin) return _leads;
    final cid = currentCompanyId;
    if (cid == null) return [];
    final myProjectIds = companyProjects.map((p) => p.id).toSet();
    return _leads.where((l) => l.companyId == cid || myProjectIds.contains(l.projectId)).toList();
  }

  List<CrmNotification> get companyNotifications {
    if (isMasterAdmin) return _notifications;
    final cid = currentCompanyId;
    if (cid == null) return [];
    return _notifications.where((n) => n.companyId == cid || n.isForAll).toList();
  }

  // ─── Role-based project/lead getters ─────────────────────────────────────
  List<RealEstateProject> get myProjects {
    if (isMasterAdmin) return _projects;
    if (isCompanyAdmin) return companyProjects;
    return companyProjects.where((p) => p.assignedSalesIds.contains(_currentUser?.id)).toList();
  }

  List<Lead> get myLeads {
    if (isMasterAdmin) return _leads;
    if (isCompanyAdmin) return companyLeads;
    return companyLeads.where((l) => l.assignedToId == _currentUser?.id).toList();
  }

  List<Lead> myLeadsForProject(String projectId) {
    if (isAdmin) return companyLeads.where((l) => l.projectId == projectId).toList();
    return companyLeads.where((l) => l.projectId == projectId && l.assignedToId == _currentUser?.id).toList();
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
  Map<LeadStatus, int> get leadsByStatus {
    final src = isAdmin ? companyLeads : myLeads;
    final map = <LeadStatus, int>{};
    for (final s in LeadStatus.values) { map[s] = src.where((l) => l.status == s).length; }
    return map;
  }

  double get conversionRate {
    final src = isAdmin ? companyLeads : myLeads;
    if (src.isEmpty) return 0.0;
    return (src.where((l) => l.status == LeadStatus.closed).length / src.length) * 100;
  }

  List<Lead> get recentLeads {
    final src = isAdmin ? companyLeads : myLeads;
    final sorted = List<Lead>.from(src)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(5).toList();
  }

  List<Lead> get myRecentLeads {
    final sorted = List<Lead>.from(myLeads)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(5).toList();
  }

  List<Lead> get todaysLeads {
    final today = DateTime.now();
    return companyLeads.where((l) =>
        l.createdAt.year == today.year &&
        l.createdAt.month == today.month &&
        l.createdAt.day == today.day).toList();
  }

  List<Lead> get upcomingSiteVisits {
    return companyLeads.where((l) =>
        l.status == LeadStatus.siteVisit &&
        l.siteVisitDate != null &&
        l.siteVisitDate!.isNotEmpty).toList();
  }

  List<Lead> get pendingFollowUps {
    return companyLeads.where((l) =>
        l.followUpDate != null && l.followUpDate!.isNotEmpty).toList();
  }

  Map<String, Map<String, int>> get projectStats {
    final map = <String, Map<String, int>>{};
    for (final p in companyProjects) {
      final pLeads = companyLeads.where((l) => l.projectId == p.id);
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

  /// Returns per-project stats including admin info. No Company dependency.
  Map<String, Map<String, dynamic>> get allProjectsStats {
    final map = <String, Map<String, dynamic>>{};
    for (final p in _projects) {
      final pLeads = _leads.where((l) => l.projectId == p.id).toList();
      final closed = pLeads.where((l) => l.status == LeadStatus.closed).length;
      // Find project admin
      String adminName = 'No admin assigned';
      try {
        final admin = _users.firstWhere(
          (u) => u.companyId == p.id && u.role == UserRole.companyAdmin && u.isApproved,
        );
        adminName = admin.name;
      } catch (_) {}
      map[p.id] = {
        'project': p,
        'adminName': adminName,
        'totalLeads': pLeads.length,
        'closed': closed,
        'siteVisit': pLeads.where((l) => l.status == LeadStatus.siteVisit).length,
        'newLeads': pLeads.where((l) => l.status == LeadStatus.newLead).length,
        'conversionRate': pLeads.isEmpty ? 0.0 : (closed / pLeads.length) * 100,
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
      _users.where((u) => u.companyId == projectId && u.isApproved).length;

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
      );
      _saveUser(updated);
      _otpStore.remove(email.toLowerCase());
      _loadAll();
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
    _usersBox      = await Hive.openBox('users_v8');
    _leadsBox      = await Hive.openBox('leads_v8');
    _notifBox      = await Hive.openBox('notifs_v8');
    _projectsBox   = await Hive.openBox('projects_v8');
    _approvalsBox  = await Hive.openBox('approvals_v8');
    _emailLogsBox  = await Hive.openBox('email_logs_v8');
    _settingsBox   = await Hive.openBox('settings_v8');

    // Migrate existing data from older box versions
    await _migrateFromOldBoxes();

    _loadAll();
    if (_users.isEmpty) _seedData();
  }

  /// Migrate data from v7 boxes to v8 boxes (removes company dependency)
  Future<void> _migrateFromOldBoxes() async {
    try {
      // Try to migrate users from v7
      final oldUsersBox = await Hive.openBox('users_v7');
      if (oldUsersBox.isNotEmpty && _usersBox.isEmpty) {
        for (final key in oldUsersBox.keys) {
          try {
            final v = oldUsersBox.get(key);
            if (v != null) _usersBox.put(key, v);
          } catch (_) {}
        }
      }
      // Migrate leads
      final oldLeadsBox = await Hive.openBox('leads_v7');
      if (oldLeadsBox.isNotEmpty && _leadsBox.isEmpty) {
        for (final key in oldLeadsBox.keys) {
          try {
            final v = oldLeadsBox.get(key);
            if (v != null) _leadsBox.put(key, v);
          } catch (_) {}
        }
      }
      // Migrate projects
      final oldProjectsBox = await Hive.openBox('projects_v7');
      if (oldProjectsBox.isNotEmpty && _projectsBox.isEmpty) {
        for (final key in oldProjectsBox.keys) {
          try {
            final v = oldProjectsBox.get(key);
            if (v != null) _projectsBox.put(key, v);
          } catch (_) {}
        }
      }
      // Migrate notifications
      final oldNotifBox = await Hive.openBox('notifs_v7');
      if (oldNotifBox.isNotEmpty && _notifBox.isEmpty) {
        for (final key in oldNotifBox.keys) {
          try {
            final v = oldNotifBox.get(key);
            if (v != null) _notifBox.put(key, v);
          } catch (_) {}
        }
      }
      // Migrate approvals
      final oldApprovalsBox = await Hive.openBox('approvals_v7');
      if (oldApprovalsBox.isNotEmpty && _approvalsBox.isEmpty) {
        for (final key in oldApprovalsBox.keys) {
          try {
            final v = oldApprovalsBox.get(key);
            if (v != null) _approvalsBox.put(key, v);
          } catch (_) {}
        }
      }
      // Migrate email logs
      final oldEmailLogsBox = await Hive.openBox('email_logs_v7');
      if (oldEmailLogsBox.isNotEmpty && _emailLogsBox.isEmpty) {
        for (final key in oldEmailLogsBox.keys) {
          try {
            final v = oldEmailLogsBox.get(key);
            if (v != null) _emailLogsBox.put(key, v);
          } catch (_) {}
        }
      }
      // Migrate settings
      final oldSettingsBox = await Hive.openBox('settings_v7');
      if (oldSettingsBox.isNotEmpty) {
        for (final key in oldSettingsBox.keys) {
          try {
            if (_settingsBox.get(key) == null) {
              _settingsBox.put(key, oldSettingsBox.get(key));
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // Migration failed silently — fresh start
    }
  }

  void _loadAll() {
    _users = _usersBox.values.map((v) => AppUser.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _leads = _leadsBox.values.map((v) => Lead.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _notifications = _notifBox.values.map((v) => CrmNotification.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _projects = _projectsBox.values.map((v) => RealEstateProject.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _approvals = _approvalsBox.values.map((v) => ApprovalRequest.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _emailLogs = _emailLogsBox.values.map((v) => EmailLog.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
  }

  void _seedData() {
    // ── Master Admin only ─────────────────────────────────────────────────
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
    _saveUser(masterAdmin);
    _loadAll();
  }

  void _saveUser(AppUser u) => _usersBox.put(u.id, jsonEncode(u.toMap()));
  void _saveLead(Lead l) => _leadsBox.put(l.id, jsonEncode(l.toMap()));
  void _saveNotification(CrmNotification n) => _notifBox.put(n.id, jsonEncode(n.toMap()));
  void _saveProject(RealEstateProject p) => _projectsBox.put(p.id, jsonEncode(p.toMap()));
  void _saveApproval(ApprovalRequest a) => _approvalsBox.put(a.id, jsonEncode(a.toMap()));
  void _saveEmailLog(EmailLog e) => _emailLogsBox.put(e.id, jsonEncode(e.toMap()));

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

  // ─── Authentication ───────────────────────────────────────────────────────
  /// Returns null on success, or an error message string on failure.
  String? loginWithError(String emailOrUsername, String password) {
    AppUser? user;
    try {
      user = _users.firstWhere(
          (u) => u.email.toLowerCase() == emailOrUsername.toLowerCase());
    } catch (_) {
      return 'No account found with this email address';
    }
    if (user.password != password) return 'Incorrect password. Please try again';
    if (!user.isApproved) return 'Your account is pending approval. Please contact the admin';
    if (!user.isActive) return 'Your account has been deactivated. Please contact the admin';
    _currentUser = user;
    notifyListeners();
    return null;
  }

  bool login(String emailOrUsername, String password) {
    return loginWithError(emailOrUsername, password) == null;
  }

  void logout() {
    _currentUser = null;
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
    );
    _saveUser(updated);
    _currentUser = updated;
    _loadAll();
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
    _loadAll();
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
      );
      _saveUser(user);
      _saveApproval(req);
      _loadAll();
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
      _loadAll();
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
  String? addProjectAdmin({
    required String name,
    required String email,
    required String password,
    String? companyId,    // legacy param — maps to projectId
    String? projectId,    // preferred param
  }) {
    if (!isMasterAdmin) return 'Unauthorized';
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }
    final resolvedProjectId = projectId ?? companyId;
    if (resolvedProjectId == null || resolvedProjectId.isEmpty) {
      return 'Project not selected';
    }
    RealEstateProject? project;
    try {
      project = _projects.firstWhere((p) => p.id == resolvedProjectId);
    } catch (_) {
      return 'Project not found';
    }
    final user = AppUser(
      name: name,
      email: email,
      password: password,
      role: UserRole.companyAdmin,
      companyId: resolvedProjectId,   // user.companyId == project.id
      companyName: project.name,
      isApproved: true,
      hasLoggedInBefore: false,
    );
    _saveUser(user);
    // CRITICAL: Update the project's companyId so companyProjects getter finds it
    if (project.companyId != resolvedProjectId) {
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
        createdById: project.createdById,
        createdByName: project.createdByName,
        createdAt: project.createdAt,
        updatedAt: DateTime.now(),
        totalUnits: project.totalUnits,
        reraNumber: project.reraNumber,
        companyId: resolvedProjectId,
      );
      _saveProject(updatedProject);
    }
    _loadAll();
    notifyListeners();
    _sendEmail(
      toEmail: email,
      toName: name,
      subject: '🎉 Project Admin Access Granted – RLA CRM',
      body: '''
Hello $name,

You have been added as a Project Admin for "${project.name}" on RLA CRM by ${_currentUser?.name ?? 'Master Admin'}.

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
    _loadAll();
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
  void addProject(RealEstateProject p) { _saveProject(p); _loadAll(); notifyListeners(); }
  void updateProject(RealEstateProject p) { p.updatedAt = DateTime.now(); _saveProject(p); _loadAll(); notifyListeners(); }
  void deleteProject(String id) { _projectsBox.delete(id); _loadAll(); notifyListeners(); }

  // ─── CRUD: Users ──────────────────────────────────────────────────────────
  void addUser(AppUser u) { _saveUser(u); _loadAll(); notifyListeners(); }
  void updateUser(AppUser u) { _saveUser(u); _loadAll(); notifyListeners(); }
  void deleteUser(String id) { _usersBox.delete(id); _loadAll(); notifyListeners(); }
  void toggleUserActive(String id) {
    try {
      final u = _users.firstWhere((u) => u.id == id);
      final updated = AppUser(
        id: u.id, name: u.name, email: u.email, password: u.password,
        role: u.role, isActive: !u.isActive, isApproved: u.isApproved,
        hasLoggedInBefore: u.hasLoggedInBefore,
        createdAt: u.createdAt, companyId: u.companyId, companyName: u.companyName,
      );
      _saveUser(updated);
      _loadAll();
      notifyListeners();
    } catch (_) {}
  }

  // ─── CRUD: Leads ──────────────────────────────────────────────────────────
  void addLead(Lead l) { _saveLead(l); _loadAll(); notifyListeners(); }
  void updateLead(Lead l) { l.updatedAt = DateTime.now(); _saveLead(l); _loadAll(); notifyListeners(); }
  void deleteLead(String id) { _leadsBox.delete(id); _loadAll(); notifyListeners(); }

  // ─── CRUD: Notifications ──────────────────────────────────────────────────
  void addNotification(CrmNotification n) { _saveNotification(n); _loadAll(); notifyListeners(); }
  void deleteNotification(String id) { _notifBox.delete(id); _loadAll(); notifyListeners(); }
  void markNotificationRead(String id) {
    try {
      final n = _notifications.firstWhere((n) => n.id == id);
      n.isRead = true;
      _saveNotification(n);
      _loadAll();
      notifyListeners();
    } catch (_) {}
  }
  void markAllNotificationsRead() {
    for (final n in myNotifications.where((n) => !n.isRead)) {
      n.isRead = true;
      _saveNotification(n);
    }
    _loadAll();
    notifyListeners();
  }
}

// ─── OTP Entry ────────────────────────────────────────────────────────────────
class _OtpEntry {
  final String code;
  final DateTime expiry;
  _OtpEntry(this.code, this.expiry);
}
