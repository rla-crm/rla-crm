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
  late Box _companiesBox;
  late Box _approvalsBox;
  late Box _emailLogsBox;
  late Box _settingsBox;

  AppUser? _currentUser;
  List<AppUser> _users = [];
  List<Lead> _leads = [];
  List<CrmNotification> _notifications = [];
  List<RealEstateProject> _projects = [];
  List<Company> _companies = [];
  List<ApprovalRequest> _approvals = [];
  List<EmailLog> _emailLogs = [];

  // ─── Getters ─────────────────────────────────────────────────────────────
  AppUser? get currentUser => _currentUser;
  List<Company> get companies => List.unmodifiable(_companies);
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

  Company? get currentCompany {
    if (currentCompanyId == null) return null;
    try { return _companies.firstWhere((c) => c.id == currentCompanyId); }
    catch (_) { return null; }
  }

  // ─── Approval getters ─────────────────────────────────────────────────────
  List<ApprovalRequest> get pendingApprovals =>
      _approvals.where((a) => a.status == ApprovalStatus.pending).toList();

  List<ApprovalRequest> get masterAdminPendingApprovals =>
      pendingApprovals.where((a) => a.type == ApprovalType.companyRegistration).toList();

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

  // ─── Company-scoped getters ───────────────────────────────────────────────
  List<RealEstateProject> get companyProjects {
    if (isMasterAdmin) return _projects;
    return _projects.where((p) => p.companyId == currentCompanyId).toList();
  }

  List<AppUser> get companyUsers {
    if (isMasterAdmin) return _users;
    return _users.where((u) => u.companyId == currentCompanyId).toList();
  }

  List<Lead> get companyLeads {
    if (isMasterAdmin) return _leads;
    return _leads.where((l) => l.companyId == currentCompanyId).toList();
  }

  List<CrmNotification> get companyNotifications {
    if (isMasterAdmin) return _notifications;
    return _notifications.where((n) => n.companyId == currentCompanyId).toList();
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
  int get totalCompanies => _companies.length;
  int get activeCompanies => _companies.where((c) => c.isActive && c.isApproved).length;
  int get totalAllLeads => _leads.length;
  int get totalAllUsers => _users.length;

  // ─── Subscription / Revenue Analytics ────────────────────────────────────
  List<Company> get approvedCompanies => _companies.where((c) => c.isApproved).toList();
  List<Company> get paidCompanies => approvedCompanies.where((c) => c.plan.isPaid).toList();
  List<Company> get trialCompanies => approvedCompanies.where((c) => c.plan == SubscriptionPlan.trial).toList();

  double get actualMonthlyRevenue =>
      paidCompanies.fold(0.0, (sum, c) => sum + c.plan.monthlyRevenue);

  double get prospectMonthlyRevenue =>
      trialCompanies.fold(0.0, (sum, c) => sum + SubscriptionPlan.professional.monthlyRevenue);

  Map<SubscriptionPlan, int> get companiesByPlan {
    final map = <SubscriptionPlan, int>{};
    for (final p in SubscriptionPlan.values) {
      map[p] = _companies.where((c) => c.plan == p && c.isApproved).length;
    }
    return map;
  }

  List<Company> get recentCompanies {
    final sorted = List<Company>.from(approvedCompanies)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  int usersForCompany(String companyId) =>
      _users.where((u) => u.companyId == companyId && u.isApproved).length;

  int leadsForCompany(String companyId) =>
      _leads.where((l) => l.companyId == companyId).length;

  // ─── Init ─────────────────────────────────────────────────────────────────
  // ─── OTP / Forgot-Password store (in-memory, expires 10 min) ─────────────
  final Map<String, _OtpEntry> _otpStore = {};

  /// Generate a 6-digit OTP for password reset and store it.
  /// Returns the OTP code (to display / simulate send).
  String generatePasswordResetOtp(String email) {
    final otp = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    _otpStore[email.toLowerCase()] = _OtpEntry(otp, DateTime.now().add(const Duration(minutes: 10)));
    // Simulate email send
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
    _usersBox = await Hive.openBox('users_v6');
    _leadsBox = await Hive.openBox('leads_v6');
    _notifBox = await Hive.openBox('notifs_v6');
    _projectsBox = await Hive.openBox('projects_v6');
    _companiesBox = await Hive.openBox('companies_v6');
    _approvalsBox = await Hive.openBox('approvals_v6');
    _emailLogsBox = await Hive.openBox('email_logs_v6');
    _settingsBox = await Hive.openBox('settings_v6');
    _loadAll();
    if (_users.isEmpty) _seedData();
  }

  void _loadAll() {
    _companies = _companiesBox.values.map((v) => Company.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _users = _usersBox.values.map((v) => AppUser.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _leads = _leadsBox.values.map((v) => Lead.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _notifications = _notifBox.values.map((v) => CrmNotification.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _projects = _projectsBox.values.map((v) => RealEstateProject.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _approvals = _approvalsBox.values.map((v) => ApprovalRequest.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
    _emailLogs = _emailLogsBox.values.map((v) => EmailLog.fromMap(Map<String, dynamic>.from(jsonDecode(v)))).toList();
  }

  void _seedData() {
    // ── Master Admin ──────────────────────────────────────────────────────
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

    // ── Demo Company 1: Prestige Group ─────────────────────────────────────
    final company1 = Company(
      id: 'company_001',
      name: 'Prestige Group',
      adminEmail: 'admin@prestige.com',
      adminName: 'Rahul Kapoor',
      phone: '+91 9876543210',
      plan: SubscriptionPlan.professional,
      isApproved: true,
      trialStartDate: DateTime.now().subtract(const Duration(days: 3)),
    );

    final comp1Admin = AppUser(
      id: 'user_c1_admin',
      name: 'Rahul Kapoor',
      email: 'admin@prestige.com',
      password: 'admin123',
      role: UserRole.companyAdmin,
      companyId: 'company_001',
      companyName: 'Prestige Group',
      isApproved: true,
      hasLoggedInBefore: true,
    );

    final comp1Sales1 = AppUser(
      id: 'user_c1_s1',
      name: 'Arjun Sharma',
      email: 'arjun@prestige.com',
      password: 'sales123',
      role: UserRole.sales,
      companyId: 'company_001',
      companyName: 'Prestige Group',
      isApproved: true,
      hasLoggedInBefore: true,
    );

    final comp1Sales2 = AppUser(
      id: 'user_c1_s2',
      name: 'Priya Mehta',
      email: 'priya@prestige.com',
      password: 'sales123',
      role: UserRole.sales,
      companyId: 'company_001',
      companyName: 'Prestige Group',
      isApproved: true,
      hasLoggedInBefore: true,
    );

    // ── Demo Company 2: Brigade Group ─────────────────────────────────────
    final company2 = Company(
      id: 'company_002',
      name: 'Brigade Group',
      adminEmail: 'admin@brigade.com',
      adminName: 'Sunita Reddy',
      phone: '+91 9876543211',
      plan: SubscriptionPlan.starter,
      isApproved: true,
      trialStartDate: DateTime.now().subtract(const Duration(days: 8)),
    );

    final comp2Admin = AppUser(
      id: 'user_c2_admin',
      name: 'Sunita Reddy',
      email: 'admin@brigade.com',
      password: 'admin123',
      role: UserRole.companyAdmin,
      companyId: 'company_002',
      companyName: 'Brigade Group',
      isApproved: true,
      hasLoggedInBefore: true,
    );

    final comp2Sales1 = AppUser(
      id: 'user_c2_s1',
      name: 'Vikram Nair',
      email: 'vikram@brigade.com',
      password: 'sales123',
      role: UserRole.sales,
      companyId: 'company_002',
      companyName: 'Brigade Group',
      isApproved: true,
      hasLoggedInBefore: true,
    );

    // ── Demo Company 3: Trial company with first-login popup ───────────────
    final company3 = Company(
      id: 'company_003',
      name: 'Sobha Realty',
      adminEmail: 'admin@sobha.com',
      adminName: 'Kiran Patel',
      phone: '+91 9876543212',
      plan: SubscriptionPlan.trial,
      isApproved: true,
      trialStartDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    final comp3Admin = AppUser(
      id: 'user_c3_admin',
      name: 'Kiran Patel',
      email: 'admin@sobha.com',
      password: 'admin123',
      role: UserRole.companyAdmin,
      companyId: 'company_003',
      companyName: 'Sobha Realty',
      isApproved: true,
      hasLoggedInBefore: false, // will trigger trial popup on first login
    );

    // ── Projects ─────────────────────────────────────────────────────────
    final proj1 = RealEstateProject(
      id: 'proj_001',
      name: 'Prestige Lakeside',
      location: 'Whitefield, Bangalore',
      description: 'Premium lakeside apartments with world-class amenities',
      developerName: 'Prestige Group',
      propertyType: PropertyType.apartment,
      priceFrom: 6500000, priceTo: 15000000,
      totalUnits: 240,
      reraNumber: 'PRM/KA/RERA/1251/308',
      assignedSalesIds: ['user_c1_s1', 'user_c1_s2'],
      createdById: 'user_c1_admin', createdByName: 'Rahul Kapoor',
      companyId: 'company_001',
    );

    final proj2 = RealEstateProject(
      id: 'proj_002',
      name: 'Prestige Orchards',
      location: 'Devanahalli, Bangalore',
      description: 'Luxury villas surrounded by lush greenery',
      developerName: 'Prestige Group',
      propertyType: PropertyType.villa,
      priceFrom: 12000000, priceTo: 35000000,
      totalUnits: 180,
      assignedSalesIds: ['user_c1_s1'],
      createdById: 'user_c1_admin', createdByName: 'Rahul Kapoor',
      companyId: 'company_001',
    );

    final proj3 = RealEstateProject(
      id: 'proj_003',
      name: 'Brigade Meadows',
      location: 'Kanakapura Road, Bangalore',
      description: 'Integrated township with residential and commercial spaces',
      developerName: 'Brigade Group',
      propertyType: PropertyType.apartment,
      priceFrom: 4500000, priceTo: 9000000,
      totalUnits: 320,
      assignedSalesIds: ['user_c2_s1'],
      createdById: 'user_c2_admin', createdByName: 'Sunita Reddy',
      companyId: 'company_002',
    );

    // ── Sample Leads ──────────────────────────────────────────────────────
    final now = DateTime.now();
    final leads = [
      Lead(id: 'lead_001', name: 'Rohan Verma', phone: '9876543001',
          email: 'rohan@email.com', projectId: 'proj_001',
          projectName: 'Prestige Lakeside', propertyType: PropertyType.apartment,
          budgetMin: 8000000, budgetMax: 12000000,
          source: LeadSource.website, status: LeadStatus.siteVisit,
          assignedToId: 'user_c1_s1', assignedToName: 'Arjun Sharma',
          siteVisitDate: '20 Mar 2026',
          createdById: 'user_c1_s1', createdByName: 'Arjun Sharma',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(hours: 3)),
          companyId: 'company_001'),
      Lead(id: 'lead_002', name: 'Kavya Iyer', phone: '9876543002',
          email: 'kavya@email.com', projectId: 'proj_002',
          projectName: 'Prestige Orchards', propertyType: PropertyType.villa,
          budgetMin: 15000000, budgetMax: 25000000,
          source: LeadSource.referral, status: LeadStatus.negotiation,
          assignedToId: 'user_c1_s1', assignedToName: 'Arjun Sharma',
          createdById: 'user_c1_s1', createdByName: 'Arjun Sharma',
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(days: 1)),
          companyId: 'company_001'),
      Lead(id: 'lead_003', name: 'Suresh Patel', phone: '9876543003',
          projectId: 'proj_001', projectName: 'Prestige Lakeside',
          propertyType: PropertyType.apartment,
          budgetMin: 6500000, budgetMax: 10000000,
          source: LeadSource.walkin, status: LeadStatus.contacted,
          assignedToId: 'user_c1_s2', assignedToName: 'Priya Mehta',
          followUpDate: '18 Mar 2026',
          createdById: 'user_c1_s2', createdByName: 'Priya Mehta',
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now.subtract(const Duration(hours: 6)),
          companyId: 'company_001'),
      Lead(id: 'lead_004', name: 'Anita Desai', phone: '9876543004',
          projectId: 'proj_001', projectName: 'Prestige Lakeside',
          propertyType: PropertyType.apartment,
          budgetMin: 7000000,
          source: LeadSource.socialMedia, status: LeadStatus.newLead,
          assignedToId: 'user_c1_s2', assignedToName: 'Priya Mehta',
          createdById: 'user_c1_s2', createdByName: 'Priya Mehta',
          createdAt: now.subtract(const Duration(hours: 8)),
          updatedAt: now.subtract(const Duration(hours: 8)),
          companyId: 'company_001'),
      Lead(id: 'lead_005', name: 'Manoj Kumar', phone: '9876543005',
          projectId: 'proj_002', projectName: 'Prestige Orchards',
          propertyType: PropertyType.villa,
          budgetMin: 20000000,
          source: LeadSource.referral, status: LeadStatus.closed,
          assignedToId: 'user_c1_s1', assignedToName: 'Arjun Sharma',
          createdById: 'user_c1_s1', createdByName: 'Arjun Sharma',
          createdAt: now.subtract(const Duration(days: 15)),
          updatedAt: now.subtract(const Duration(days: 2)),
          companyId: 'company_001'),
      Lead(id: 'lead_006', name: 'Divya Krishnan', phone: '9876543006',
          projectId: 'proj_003', projectName: 'Brigade Meadows',
          propertyType: PropertyType.apartment,
          budgetMin: 5000000, budgetMax: 8000000,
          source: LeadSource.portal, status: LeadStatus.siteVisit,
          assignedToId: 'user_c2_s1', assignedToName: 'Vikram Nair',
          siteVisitDate: '22 Mar 2026',
          createdById: 'user_c2_s1', createdByName: 'Vikram Nair',
          createdAt: now.subtract(const Duration(days: 4)),
          updatedAt: now.subtract(const Duration(days: 1)),
          companyId: 'company_002'),
      Lead(id: 'lead_007', name: 'Ravi Shankar', phone: '9876543007',
          projectId: 'proj_003', projectName: 'Brigade Meadows',
          propertyType: PropertyType.apartment,
          budgetMin: 4500000,
          source: LeadSource.coldCall, status: LeadStatus.contacted,
          assignedToId: 'user_c2_s1', assignedToName: 'Vikram Nair',
          createdById: 'user_c2_s1', createdByName: 'Vikram Nair',
          createdAt: now.subtract(const Duration(days: 6)),
          updatedAt: now.subtract(const Duration(hours: 12)),
          companyId: 'company_002'),
    ];

    // ── Notifications ─────────────────────────────────────────────────────
    final notif1 = CrmNotification(
      id: 'notif_001',
      title: 'Welcome to RLA CRM',
      message: 'Your CRM is set up and ready. Start adding leads and managing projects!',
      createdById: 'user_c1_admin', createdByName: 'Rahul Kapoor',
      isForAll: true, priority: NotificationPriority.high,
      companyId: 'company_001',
    );

    final notif2 = CrmNotification(
      id: 'notif_002',
      title: 'Welcome to RLA CRM',
      message: 'Your CRM is set up and ready. Start managing your real estate leads!',
      createdById: 'user_c2_admin', createdByName: 'Sunita Reddy',
      isForAll: true, priority: NotificationPriority.high,
      companyId: 'company_002',
    );

    // ── Sample pending approvals ──────────────────────────────────────────
    final sampleApproval1 = ApprovalRequest(
      id: 'approval_001',
      type: ApprovalType.companyRegistration,
      status: ApprovalStatus.pending,
      applicantName: 'Anand Verma',
      applicantEmail: 'admin@godrejproperties.com',
      companyName: 'Godrej Properties',
      adminEmail: 'admin@godrejproperties.com',
      phone: '+91 9988776655',
      password: 'godrej123',
    );

    final sampleApproval2 = ApprovalRequest(
      id: 'approval_002',
      type: ApprovalType.employeeSignup,
      status: ApprovalStatus.pending,
      applicantName: 'Neha Singh',
      applicantEmail: 'neha@prestige.com',
      companyId: 'company_001',
      companyName: 'Prestige Group',
      password: 'neha1234',
      role: 'sales',
    );

    // ── Save all ──────────────────────────────────────────────────────────
    _saveUser(masterAdmin);
    _saveUser(comp1Admin);
    _saveUser(comp1Sales1);
    _saveUser(comp1Sales2);
    _saveUser(comp2Admin);
    _saveUser(comp2Sales1);
    _saveUser(comp3Admin);

    _saveCompany(company1);
    _saveCompany(company2);
    _saveCompany(company3);

    _saveProject(proj1);
    _saveProject(proj2);
    _saveProject(proj3);

    for (final l in leads) { _saveLead(l); }

    _saveNotification(notif1);
    _saveNotification(notif2);

    _saveApproval(sampleApproval1);
    _saveApproval(sampleApproval2);

    _loadAll();
  }

  void _saveUser(AppUser u) => _usersBox.put(u.id, jsonEncode(u.toMap()));
  void _saveLead(Lead l) => _leadsBox.put(l.id, jsonEncode(l.toMap()));
  void _saveNotification(CrmNotification n) => _notifBox.put(n.id, jsonEncode(n.toMap()));
  void _saveProject(RealEstateProject p) => _projectsBox.put(p.id, jsonEncode(p.toMap()));
  void _saveCompany(Company c) => _companiesBox.put(c.id, jsonEncode(c.toMap()));
  void _saveApproval(ApprovalRequest a) => _approvalsBox.put(a.id, jsonEncode(a.toMap()));
  void _saveEmailLog(EmailLog e) => _emailLogsBox.put(e.id, jsonEncode(e.toMap()));

  // ─── Email Simulation ─────────────────────────────────────────────────────
  /// Simulates sending an email by logging it. In production, replace with real SMTP.
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
  bool login(String emailOrUsername, String password) {
    try {
      final user = _users.firstWhere(
          (u) => (u.email.toLowerCase() == emailOrUsername.toLowerCase()) && u.password == password);
      if (!user.isActive) return false;
      if (!user.isApproved) return false;
      _currentUser = user;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Mark user as having logged in (removes first-login popup trigger)
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

  /// Company Admin signup → goes to Master Admin for approval
  String? submitCompanyRegistration({
    required String companyName,
    required String adminName,
    required String email,
    required String password,
    String? phone,
  }) {
    // Check email not already in users
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }
    // Check no pending/approved approval for same email
    if (_approvals.any((a) =>
        a.applicantEmail.toLowerCase() == email.toLowerCase() &&
        a.status == ApprovalStatus.pending)) {
      return 'A registration request with this email is already pending approval';
    }

    final req = ApprovalRequest(
      type: ApprovalType.companyRegistration,
      applicantName: adminName,
      applicantEmail: email,
      companyName: companyName,
      adminEmail: email,
      phone: phone,
      password: password,
    );
    _saveApproval(req);
    _loadAll();
    notifyListeners();

    // Notify master admins via simulated email
    final masterAdmins = _users.where((u) => u.role == UserRole.masterAdmin);
    for (final ma in masterAdmins) {
      _sendEmail(
        toEmail: ma.email,
        toName: ma.name,
        subject: '📋 New Company Registration: $companyName',
        body: '''
Hello ${ma.name},

A new company registration request has been submitted and is awaiting your approval.

Company: $companyName
Admin Name: $adminName
Admin Email: $email
Phone: ${phone ?? 'Not provided'}

Please log in to RLA CRM to review and approve or reject this request.

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'company_registration_submitted',
      );
    }

    // Notify applicant
    _sendEmail(
      toEmail: email,
      toName: adminName,
      subject: '✅ Registration Received – RLA CRM',
      body: '''
Hello $adminName,

Thank you for registering $companyName with RLA CRM!

Your registration is currently under review by our team. You will receive an email notification once your account is approved, usually within 24 hours.

Best regards,
RLA CRM Platform
      ''',
      triggerEvent: 'company_registration_applicant_confirmation',
    );

    return null;
  }

  /// Employee signup → goes to Company Admin for approval
  SignupResult submitEmployeeSignup({
    required String name,
    required String email,
    required String password,
    required String companyId,
  }) {
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return const SignupResult(error: 'Email already registered');
    }
    if (_approvals.any((a) =>
        a.applicantEmail.toLowerCase() == email.toLowerCase() &&
        a.status == ApprovalStatus.pending)) {
      return const SignupResult(error: 'A signup request with this email is already pending');
    }

    Company company;
    try {
      company = _companies.firstWhere((c) => c.id == companyId && c.isApproved);
    } catch (_) {
      return const SignupResult(error: 'Company not found or not yet approved');
    }

    final isAdminEmail = company.adminEmail.toLowerCase() == email.toLowerCase();

    final req = ApprovalRequest(
      type: ApprovalType.employeeSignup,
      applicantName: name,
      applicantEmail: email,
      companyId: companyId,
      companyName: company.name,
      password: password,
      role: isAdminEmail ? 'admin' : 'sales',
    );
    _saveApproval(req);
    _loadAll();
    notifyListeners();

    // Notify company admins
    final companyAdmins = _users.where((u) =>
        u.companyId == companyId && u.role == UserRole.companyAdmin && u.isApproved);
    for (final ca in companyAdmins) {
      _sendEmail(
        toEmail: ca.email,
        toName: ca.name,
        subject: '👤 New Sales Team Signup: $name',
        body: '''
Hello ${ca.name},

A new sales team member has requested to join ${company.name} on RLA CRM.

Name: $name
Email: $email
Requested Role: ${isAdminEmail ? 'Project Admin' : 'Sales Team'}

Please log in to RLA CRM → Team → Pending Approvals to review this request.

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'employee_signup_submitted',
      );
    }

    // Notify applicant
    _sendEmail(
      toEmail: email,
      toName: name,
      subject: '✅ Signup Request Received – ${company.name}',
      body: '''
Hello $name,

Your request to join ${company.name} on RLA CRM has been received and is awaiting approval from the project admin.

You will be notified by email once your account is approved.

Best regards,
RLA CRM Platform
      ''',
      triggerEvent: 'employee_signup_applicant_confirmation',
    );

    return const SignupResult(pendingApproval: true);
  }

  // ─── Approval Management ──────────────────────────────────────────────────

  /// Approve a company registration (Master Admin only)
  void approveCompanyRegistration(String approvalId, {String? note}) {
    try {
      final req = _approvals.firstWhere((a) => a.id == approvalId);
      req.status = ApprovalStatus.approved;
      req.reviewedBy = _currentUser?.name;
      req.reviewNote = note;
      req.updatedAt = DateTime.now();

      // Create the company
      final company = Company(
        name: req.companyName ?? '',
        adminEmail: req.adminEmail ?? req.applicantEmail,
        adminName: req.applicantName,
        phone: req.phone,
        plan: SubscriptionPlan.trial,
        isApproved: true,
        trialStartDate: DateTime.now(),
      );
      _saveCompany(company);

      // Create the admin user
      final user = AppUser(
        name: req.applicantName,
        email: req.applicantEmail,
        password: req.password ?? 'changeme123',
        role: UserRole.companyAdmin,
        companyId: company.id,
        companyName: company.name,
        isApproved: true,
        hasLoggedInBefore: false, // will trigger trial popup
      );
      _saveUser(user);
      _saveApproval(req);
      _loadAll();
      notifyListeners();

      // Send approval email
      _sendEmail(
        toEmail: req.applicantEmail,
        toName: req.applicantName,
        subject: '🎉 Your Company is Approved – RLA CRM',
        body: '''
Hello ${req.applicantName},

Congratulations! Your company "${req.companyName}" has been approved on RLA CRM.

You can now log in with:
Email: ${req.applicantEmail}
Password: ${req.password ?? 'changeme123'}

Your 14-day free trial has started. Explore all features and choose a plan that works for you.

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'company_registration_approved',
      );
    } catch (_) {}
  }

  /// Reject a company registration (Master Admin only)
  void rejectCompanyRegistration(String approvalId, {String? note}) {
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
        subject: '❌ Registration Request Update – RLA CRM',
        body: '''
Hello ${req.applicantName},

We regret to inform you that your company registration request for "${req.companyName}" has not been approved at this time.

${note != null ? 'Reason: $note\n\n' : ''}If you have any questions, please contact our support team.

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'company_registration_rejected',
      );
    } catch (_) {}
  }

  /// Approve an employee signup (Company Admin only)
  void approveEmployeeSignup(String approvalId, {String? note}) {
    try {
      final req = _approvals.firstWhere((a) => a.id == approvalId);
      req.status = ApprovalStatus.approved;
      req.reviewedBy = _currentUser?.name;
      req.reviewNote = note;
      req.updatedAt = DateTime.now();

      // Find company
      Company? company;
      try { company = _companies.firstWhere((c) => c.id == req.companyId); } catch (_) {}

      final role = req.role == 'admin' ? UserRole.companyAdmin : UserRole.sales;
      final user = AppUser(
        name: req.applicantName,
        email: req.applicantEmail,
        password: req.password ?? 'changeme123',
        role: role,
        companyId: req.companyId,
        companyName: company?.name ?? req.companyName,
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
        subject: '🎉 Welcome to ${company?.name ?? req.companyName} – RLA CRM',
        body: '''
Hello ${req.applicantName},

Your account has been approved! You can now log in to RLA CRM.

Email: ${req.applicantEmail}
Password: ${req.password ?? 'changeme123'}
Role: ${role == UserRole.companyAdmin ? 'Project Admin' : 'Sales Team'}
Company: ${company?.name ?? req.companyName}

Best regards,
RLA CRM Platform
        ''',
        triggerEvent: 'employee_signup_approved',
      );
    } catch (_) {}
  }

  /// Reject an employee signup (Company Admin only)
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

  // ─── CRUD: Companies (Master Admin) ──────────────────────────────────────
  void addCompany(Company c) { _saveCompany(c); _loadAll(); notifyListeners(); }
  void updateCompany(Company c) { c.updatedAt = DateTime.now(); _saveCompany(c); _loadAll(); notifyListeners(); }
  void deleteCompany(String id) {
    _companiesBox.delete(id);
    _users.where((u) => u.companyId == id).toList().forEach((u) => _usersBox.delete(u.id));
    _loadAll();
    notifyListeners();
  }
  void toggleCompanyActive(String id) {
    try {
      final c = _companies.firstWhere((c) => c.id == id);
      final updated = Company(
        id: c.id, name: c.name, adminEmail: c.adminEmail, adminName: c.adminName,
        phone: c.phone, website: c.website, address: c.address,
        plan: c.plan, isActive: !c.isActive, isApproved: c.isApproved,
        createdAt: c.createdAt, trialStartDate: c.trialStartDate,
        totalLeads: c.totalLeads, totalUsers: c.totalUsers,
      );
      _saveCompany(updated);
      _loadAll();
      notifyListeners();
    } catch (_) {}
  }
  void updateCompanyPlan(String id, SubscriptionPlan plan) {
    try {
      final c = _companies.firstWhere((c) => c.id == id);
      c.plan = plan;
      _saveCompany(c);
      _loadAll();
      notifyListeners();
    } catch (_) {}
  }

  // ─── Add Project Admin (Master Admin can create companyAdmin for any company) ─
  String? addProjectAdmin({
    required String name,
    required String email,
    required String password,
    required String companyId,
  }) {
    if (!isMasterAdmin) return 'Unauthorized';
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }
    Company company;
    try {
      company = _companies.firstWhere((c) => c.id == companyId);
    } catch (_) {
      return 'Project not found';
    }
    final user = AppUser(
      name: name,
      email: email,
      password: password,
      role: UserRole.companyAdmin,
      companyId: companyId,
      companyName: company.name,
      isApproved: true,
      hasLoggedInBefore: false,
    );
    _saveUser(user);
    _loadAll();
    notifyListeners();
    _sendEmail(
      toEmail: email,
      toName: name,
      subject: '🎉 Project Admin Access Granted – RLA CRM',
      body: '''
Hello $name,

You have been added as a Project Admin for "${company.name}" on RLA CRM by ${_currentUser?.name ?? 'Master Admin'}.

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
  /// Create a new master admin (only existing master admins can do this)
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
