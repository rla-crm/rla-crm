import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ─── Enums ───────────────────────────────────────────────────────────────────

enum UserRole { masterAdmin, companyAdmin, sales }

enum LeadStatus { newLead, contacted, siteVisit, negotiation, closed, lost }

enum LeadSource {
  walkin, referral, website, socialMedia, portal, coldCall, exhibition, other
}

enum PropertyType {
  apartment, villa, plot, commercial, penthouse, studio, other
}

enum NotificationPriority { low, medium, high }

enum ProjectStatus { active, onHold, completed }

enum SubscriptionPlan { trial, starter, professional, enterprise }

// NEW: Approval request types and status
enum ApprovalType { companyRegistration, employeeSignup }

enum ApprovalStatus { pending, approved, rejected }

// ─── Extensions ──────────────────────────────────────────────────────────────

extension LeadStatusExt on LeadStatus {
  String get label {
    switch (this) {
      case LeadStatus.newLead: return 'New';
      case LeadStatus.contacted: return 'Contacted';
      case LeadStatus.siteVisit: return 'Site Visit';
      case LeadStatus.negotiation: return 'Negotiation';
      case LeadStatus.closed: return 'Closed';
      case LeadStatus.lost: return 'Lost';
    }
  }

  Color get color {
    switch (this) {
      case LeadStatus.newLead: return const Color(0xFFC9B8FF);
      case LeadStatus.contacted: return const Color(0xFFB8EEFF);
      case LeadStatus.siteVisit: return const Color(0xFFFFD4A8);
      case LeadStatus.negotiation: return const Color(0xFFFFB8D9);
      case LeadStatus.closed: return const Color(0xFFB8FFE4);
      case LeadStatus.lost: return const Color(0xFFE0E0E8);
    }
  }

  int get order {
    switch (this) {
      case LeadStatus.newLead: return 0;
      case LeadStatus.contacted: return 1;
      case LeadStatus.siteVisit: return 2;
      case LeadStatus.negotiation: return 3;
      case LeadStatus.closed: return 4;
      case LeadStatus.lost: return 5;
    }
  }
}

extension LeadSourceExt on LeadSource {
  String get label {
    switch (this) {
      case LeadSource.walkin: return 'Walk-In';
      case LeadSource.referral: return 'Referral';
      case LeadSource.website: return 'Website';
      case LeadSource.socialMedia: return 'Social Media';
      case LeadSource.portal: return 'Portal';
      case LeadSource.coldCall: return 'Cold Call';
      case LeadSource.exhibition: return 'Exhibition';
      case LeadSource.other: return 'Other';
    }
  }
}

extension PropertyTypeExt on PropertyType {
  String get label {
    switch (this) {
      case PropertyType.apartment: return 'Apartment';
      case PropertyType.villa: return 'Villa';
      case PropertyType.plot: return 'Plot';
      case PropertyType.commercial: return 'Commercial';
      case PropertyType.penthouse: return 'Penthouse';
      case PropertyType.studio: return 'Studio';
      case PropertyType.other: return 'Other';
    }
  }
}

extension ProjectStatusExt on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.active: return 'Active';
      case ProjectStatus.onHold: return 'On Hold';
      case ProjectStatus.completed: return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case ProjectStatus.active: return const Color(0xFFB8FFE4);
      case ProjectStatus.onHold: return const Color(0xFFFFD4A8);
      case ProjectStatus.completed: return const Color(0xFFC9B8FF);
    }
  }
}

extension SubscriptionPlanExt on SubscriptionPlan {
  String get label {
    switch (this) {
      case SubscriptionPlan.trial: return 'Free Trial';
      case SubscriptionPlan.starter: return 'Starter';
      case SubscriptionPlan.professional: return 'Professional';
      case SubscriptionPlan.enterprise: return 'Enterprise';
    }
  }

  String get price {
    switch (this) {
      case SubscriptionPlan.trial: return 'Free';
      case SubscriptionPlan.starter: return '₹2,999/mo';
      case SubscriptionPlan.professional: return '₹7,999/mo';
      case SubscriptionPlan.enterprise: return 'Custom';
    }
  }

  double get monthlyRevenue {
    switch (this) {
      case SubscriptionPlan.trial: return 0;
      case SubscriptionPlan.starter: return 2999;
      case SubscriptionPlan.professional: return 7999;
      case SubscriptionPlan.enterprise: return 25000;
    }
  }

  int get maxUsers {
    switch (this) {
      case SubscriptionPlan.trial: return 3;
      case SubscriptionPlan.starter: return 10;
      case SubscriptionPlan.professional: return 50;
      case SubscriptionPlan.enterprise: return 999;
    }
  }

  int get maxProjects {
    switch (this) {
      case SubscriptionPlan.trial: return 2;
      case SubscriptionPlan.starter: return 5;
      case SubscriptionPlan.professional: return 25;
      case SubscriptionPlan.enterprise: return 999;
    }
  }

  Color get color {
    switch (this) {
      case SubscriptionPlan.trial: return const Color(0xFFE0E0E8);
      case SubscriptionPlan.starter: return const Color(0xFFB8EEFF);
      case SubscriptionPlan.professional: return const Color(0xFFC9B8FF);
      case SubscriptionPlan.enterprise: return const Color(0xFFFFD4A8);
    }
  }

  bool get isPaid => this != SubscriptionPlan.trial;
}

extension ApprovalStatusExt on ApprovalStatus {
  String get label {
    switch (this) {
      case ApprovalStatus.pending: return 'Pending';
      case ApprovalStatus.approved: return 'Approved';
      case ApprovalStatus.rejected: return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case ApprovalStatus.pending: return const Color(0xFFFFD4A8);
      case ApprovalStatus.approved: return const Color(0xFFB8FFE4);
      case ApprovalStatus.rejected: return const Color(0xFFFFB8D9);
    }
  }
}

// ─── Approval Request Model ───────────────────────────────────────────────────

class ApprovalRequest {
  final String id;
  final ApprovalType type;
  ApprovalStatus status;
  final String applicantName;
  final String applicantEmail;
  final String? companyId;       // null for new company registrations
  final String? companyName;     // company name for registration, existing for employee
  final String? adminEmail;      // for company: intended admin email
  final String? phone;
  final String? password;        // hashed/stored temporarily for creation on approval
  final String? role;            // for employee: sales or admin
  final DateTime createdAt;
  DateTime updatedAt;
  String? reviewedBy;
  String? reviewNote;

  ApprovalRequest({
    String? id,
    required this.type,
    this.status = ApprovalStatus.pending,
    required this.applicantName,
    required this.applicantEmail,
    this.companyId,
    this.companyName,
    this.adminEmail,
    this.phone,
    this.password,
    this.role,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.reviewedBy,
    this.reviewNote,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'status': status.index,
        'applicantName': applicantName,
        'applicantEmail': applicantEmail,
        'companyId': companyId,
        'companyName': companyName,
        'adminEmail': adminEmail,
        'phone': phone,
        'password': password,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'reviewedBy': reviewedBy,
        'reviewNote': reviewNote,
      };

  factory ApprovalRequest.fromMap(Map<String, dynamic> map) => ApprovalRequest(
        id: map['id'],
        type: ApprovalType.values[map['type'] ?? 0],
        status: ApprovalStatus.values[map['status'] ?? 0],
        applicantName: map['applicantName'] ?? '',
        applicantEmail: map['applicantEmail'] ?? '',
        companyId: map['companyId'],
        companyName: map['companyName'],
        adminEmail: map['adminEmail'],
        phone: map['phone'],
        password: map['password'],
        role: map['role'],
        createdAt: DateTime.parse(map['createdAt']),
        updatedAt: DateTime.parse(map['updatedAt']),
        reviewedBy: map['reviewedBy'],
        reviewNote: map['reviewNote'],
      );
}

// ─── Email Log Model ──────────────────────────────────────────────────────────

class EmailLog {
  final String id;
  final String toEmail;
  final String toName;
  final String subject;
  final String body;
  final String triggerEvent; // e.g., 'company_registered', 'employee_approved', etc.
  final DateTime sentAt;
  final bool isSimulated; // always true in this web app (no real SMTP)

  EmailLog({
    String? id,
    required this.toEmail,
    required this.toName,
    required this.subject,
    required this.body,
    required this.triggerEvent,
    DateTime? sentAt,
    this.isSimulated = true,
  })  : id = id ?? _uuid.v4(),
        sentAt = sentAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'toEmail': toEmail,
        'toName': toName,
        'subject': subject,
        'body': body,
        'triggerEvent': triggerEvent,
        'sentAt': sentAt.toIso8601String(),
        'isSimulated': isSimulated,
      };

  factory EmailLog.fromMap(Map<String, dynamic> map) => EmailLog(
        id: map['id'],
        toEmail: map['toEmail'] ?? '',
        toName: map['toName'] ?? '',
        subject: map['subject'] ?? '',
        body: map['body'] ?? '',
        triggerEvent: map['triggerEvent'] ?? '',
        sentAt: DateTime.parse(map['sentAt']),
        isSimulated: map['isSimulated'] ?? true,
      );
}

// ─── Company Model ────────────────────────────────────────────────────────────

class Company {
  final String id;
  String name;
  String adminEmail;
  String adminName;
  String? phone;
  String? website;
  String? address;
  SubscriptionPlan plan;
  bool isActive;
  bool isApproved;           // NEW: requires master admin approval
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? trialStartDate;  // NEW: when trial started (on approval)
  int totalLeads;
  int totalUsers;

  static const int trialDurationDays = 14;

  Company({
    String? id,
    required this.name,
    required this.adminEmail,
    required this.adminName,
    this.phone,
    this.website,
    this.address,
    this.plan = SubscriptionPlan.trial,
    this.isActive = true,
    this.isApproved = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.trialStartDate,
    this.totalLeads = 0,
    this.totalUsers = 1,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get trialDaysLeft {
    if (trialStartDate == null) return trialDurationDays;
    final elapsed = DateTime.now().difference(trialStartDate!).inDays;
    return (trialDurationDays - elapsed).clamp(0, trialDurationDays);
  }

  int get daysElapsed {
    final start = trialStartDate ?? createdAt;
    return DateTime.now().difference(start).inDays;
  }

  bool get isTrialExpired =>
      plan == SubscriptionPlan.trial && trialDaysLeft <= 0;

  bool get isFirstLogin => false; // tracked separately in AppState

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'adminEmail': adminEmail,
        'adminName': adminName,
        'phone': phone,
        'website': website,
        'address': address,
        'plan': plan.index,
        'isActive': isActive,
        'isApproved': isApproved,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'trialStartDate': trialStartDate?.toIso8601String(),
        'totalLeads': totalLeads,
        'totalUsers': totalUsers,
      };

  factory Company.fromMap(Map<String, dynamic> map) => Company(
        id: map['id'],
        name: map['name'],
        adminEmail: map['adminEmail'] ?? '',
        adminName: map['adminName'] ?? '',
        phone: map['phone'],
        website: map['website'],
        address: map['address'],
        plan: SubscriptionPlan.values[map['plan'] ?? 0],
        isActive: map['isActive'] ?? true,
        isApproved: map['isApproved'] ?? true, // legacy data defaults to approved
        createdAt: DateTime.parse(map['createdAt']),
        updatedAt: DateTime.parse(map['updatedAt']),
        trialStartDate: map['trialStartDate'] != null
            ? DateTime.parse(map['trialStartDate'])
            : null,
        totalLeads: map['totalLeads'] ?? 0,
        totalUsers: map['totalUsers'] ?? 1,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── AppUser Model ────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  String name;
  final String email;
  String password;
  final UserRole role;
  bool isActive;
  bool isApproved;       // NEW: requires admin approval for employees
  bool hasLoggedInBefore; // NEW: for first-login trial popup
  final DateTime createdAt;
  final String? companyId;
  String? companyName;

  AppUser({
    String? id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.isActive = true,
    this.isApproved = true,
    this.hasLoggedInBefore = false,
    DateTime? createdAt,
    this.companyId,
    this.companyName,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role.index,
        'isActive': isActive,
        'isApproved': isApproved,
        'hasLoggedInBefore': hasLoggedInBefore,
        'createdAt': createdAt.toIso8601String(),
        'companyId': companyId,
        'companyName': companyName,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'],
        name: map['name'],
        email: map['email'],
        password: map['password'],
        role: UserRole.values[map['role'] ?? 1],
        isActive: map['isActive'] ?? true,
        isApproved: map['isApproved'] ?? true, // legacy defaults to approved
        hasLoggedInBefore: map['hasLoggedInBefore'] ?? true, // legacy already logged in
        createdAt: DateTime.parse(map['createdAt']),
        companyId: map['companyId'],
        companyName: map['companyName'],
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get roleLabel {
    switch (role) {
      case UserRole.masterAdmin: return 'Master Admin';
      case UserRole.companyAdmin: return 'Project Admin';
      case UserRole.sales: return 'Sales Team';
    }
  }
}

// ─── Project Model ────────────────────────────────────────────────────────────

class RealEstateProject {
  final String id;
  String name;
  String location;
  String description;
  String developerName;
  PropertyType propertyType;
  double? priceFrom;
  double? priceTo;
  ProjectStatus status;
  List<String> assignedSalesIds;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  DateTime updatedAt;
  int totalUnits;
  String? reraNumber;
  final String companyId;

  RealEstateProject({
    String? id,
    required this.name,
    required this.location,
    this.description = '',
    this.developerName = '',
    required this.propertyType,
    this.priceFrom,
    this.priceTo,
    this.status = ProjectStatus.active,
    List<String>? assignedSalesIds,
    required this.createdById,
    required this.createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.totalUnits = 0,
    this.reraNumber,
    required this.companyId,
  })  : id = id ?? _uuid.v4(),
        assignedSalesIds = assignedSalesIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get priceDisplay {
    if (priceFrom == null && priceTo == null) return 'Price on Request';
    if (priceFrom != null && priceTo != null) return '${_fmt(priceFrom!)} – ${_fmt(priceTo!)}';
    if (priceFrom != null) return '${_fmt(priceFrom!)} onwards';
    return 'Up to ${_fmt(priceTo!)}';
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    return '₹${v.toStringAsFixed(0)}';
  }

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'location': location,
        'description': description, 'developerName': developerName,
        'propertyType': propertyType.index,
        'priceFrom': priceFrom, 'priceTo': priceTo,
        'status': status.index,
        'assignedSalesIds': assignedSalesIds,
        'createdById': createdById, 'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'totalUnits': totalUnits, 'reraNumber': reraNumber,
        'companyId': companyId,
      };

  factory RealEstateProject.fromMap(Map<String, dynamic> map) => RealEstateProject(
        id: map['id'], name: map['name'],
        location: map['location'] ?? '',
        description: map['description'] ?? '',
        developerName: map['developerName'] ?? '',
        propertyType: PropertyType.values[map['propertyType'] ?? 0],
        priceFrom: map['priceFrom']?.toDouble(),
        priceTo: map['priceTo']?.toDouble(),
        status: ProjectStatus.values[map['status'] ?? 0],
        assignedSalesIds: List<String>.from(map['assignedSalesIds'] ?? []),
        createdById: map['createdById'] ?? '',
        createdByName: map['createdByName'] ?? '',
        createdAt: DateTime.parse(map['createdAt']),
        updatedAt: DateTime.parse(map['updatedAt']),
        totalUnits: map['totalUnits'] ?? 0,
        reraNumber: map['reraNumber'],
        companyId: map['companyId'] ?? '',
      );
}

// ─── Lead Model ───────────────────────────────────────────────────────────────

class LeadActivity {
  final String id;
  final String leadId;
  final String userId;
  final String userName;
  final String action;
  final String? note;
  final LeadStatus? fromStatus;
  final LeadStatus? toStatus;
  final DateTime timestamp;

  LeadActivity({
    String? id,
    required this.leadId,
    required this.userId,
    required this.userName,
    required this.action,
    this.note,
    this.fromStatus,
    this.toStatus,
    DateTime? timestamp,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'leadId': leadId, 'userId': userId, 'userName': userName,
        'action': action, 'note': note,
        'fromStatus': fromStatus?.index, 'toStatus': toStatus?.index,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LeadActivity.fromMap(Map<String, dynamic> map) => LeadActivity(
        id: map['id'], leadId: map['leadId'],
        userId: map['userId'], userName: map['userName'],
        action: map['action'], note: map['note'],
        fromStatus: map['fromStatus'] != null ? LeadStatus.values[map['fromStatus']] : null,
        toStatus: map['toStatus'] != null ? LeadStatus.values[map['toStatus']] : null,
        timestamp: DateTime.parse(map['timestamp']),
      );
}

class Lead {
  final String id;
  String name;
  String phone;
  String email;
  String projectId;
  String projectName;
  PropertyType propertyType;
  double? budgetMin;
  double? budgetMax;
  LeadSource source;
  LeadStatus status;
  String assignedToId;
  String assignedToName;
  String? notes;
  String? siteVisitDate;
  String? followUpDate;
  final DateTime createdAt;
  DateTime updatedAt;
  final String createdById;
  final String createdByName;
  List<LeadActivity> activities;
  final String companyId;

  Lead({
    String? id,
    required this.name,
    required this.phone,
    this.email = '',
    required this.projectId,
    required this.projectName,
    required this.propertyType,
    this.budgetMin,
    this.budgetMax,
    required this.source,
    this.status = LeadStatus.newLead,
    required this.assignedToId,
    required this.assignedToName,
    this.notes,
    this.siteVisitDate,
    this.followUpDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.createdById,
    required this.createdByName,
    List<LeadActivity>? activities,
    required this.companyId,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        activities = activities ?? [];

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get budgetDisplay {
    if (budgetMin == null && budgetMax == null) return 'Budget N/A';
    if (budgetMin != null && budgetMax != null) return '${_fmt(budgetMin!)} – ${_fmt(budgetMax!)}';
    if (budgetMin != null) return '${_fmt(budgetMin!)}+';
    return 'Up to ${_fmt(budgetMax!)}';
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    return '₹${v.toStringAsFixed(0)}';
  }

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'phone': phone, 'email': email,
        'projectId': projectId, 'projectName': projectName,
        'propertyType': propertyType.index,
        'budgetMin': budgetMin, 'budgetMax': budgetMax,
        'source': source.index, 'status': status.index,
        'assignedToId': assignedToId, 'assignedToName': assignedToName,
        'notes': notes, 'siteVisitDate': siteVisitDate, 'followUpDate': followUpDate,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdById': createdById, 'createdByName': createdByName,
        'activities': activities.map((a) => a.toMap()).toList(),
        'companyId': companyId,
      };

  factory Lead.fromMap(Map<String, dynamic> map) => Lead(
        id: map['id'], name: map['name'], phone: map['phone'],
        email: map['email'] ?? '',
        projectId: map['projectId'] ?? '',
        projectName: map['projectName'] ?? map['project'] ?? '',
        propertyType: PropertyType.values[map['propertyType'] ?? 0],
        budgetMin: map['budgetMin']?.toDouble(),
        budgetMax: map['budgetMax']?.toDouble(),
        source: LeadSource.values[map['source'] ?? 0],
        status: LeadStatus.values[map['status'] ?? 0],
        assignedToId: map['assignedToId'] ?? '',
        assignedToName: map['assignedToName'] ?? '',
        notes: map['notes'], siteVisitDate: map['siteVisitDate'],
        followUpDate: map['followUpDate'],
        createdAt: DateTime.parse(map['createdAt']),
        updatedAt: DateTime.parse(map['updatedAt']),
        createdById: map['createdById'] ?? '',
        createdByName: map['createdByName'] ?? '',
        activities: (map['activities'] as List?)?.map((a) => LeadActivity.fromMap(a)).toList() ?? [],
        companyId: map['companyId'] ?? '',
      );
}

// ─── Notification Model ───────────────────────────────────────────────────────

class CrmNotification {
  final String id;
  final String title;
  final String message;
  final String createdById;
  final String createdByName;
  final List<String> targetUserIds;
  final String? projectId;
  final String? projectName;
  final bool isForAll;
  final NotificationPriority priority;
  final DateTime createdAt;
  bool isRead;
  final String companyId;
  final bool isAlert; // true = show as popup alert

  CrmNotification({
    String? id,
    required this.title,
    required this.message,
    required this.createdById,
    required this.createdByName,
    this.targetUserIds = const [],
    this.projectId,
    this.projectName,
    this.isForAll = false,
    this.priority = NotificationPriority.medium,
    DateTime? createdAt,
    this.isRead = false,
    required this.companyId,
    this.isAlert = false,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'title': title, 'message': message,
        'createdById': createdById, 'createdByName': createdByName,
        'targetUserIds': targetUserIds,
        'projectId': projectId, 'projectName': projectName,
        'isForAll': isForAll, 'priority': priority.index,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead, 'companyId': companyId, 'isAlert': isAlert,
      };

  factory CrmNotification.fromMap(Map<String, dynamic> map) => CrmNotification(
        id: map['id'], title: map['title'], message: map['message'],
        createdById: map['createdById'], createdByName: map['createdByName'],
        targetUserIds: List<String>.from(map['targetUserIds'] ?? []),
        projectId: map['projectId'], projectName: map['projectName'],
        isForAll: map['isForAll'] ?? false,
        priority: NotificationPriority.values[map['priority'] ?? 1],
        createdAt: DateTime.parse(map['createdAt']),
        isRead: map['isRead'] ?? false,
        companyId: map['companyId'] ?? '',
        isAlert: map['isAlert'] ?? false,
      );
}
