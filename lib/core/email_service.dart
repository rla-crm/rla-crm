import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// RLA CRM Email Service
// Uses EmailJS REST API (https://www.emailjs.com) — works from any platform.
// Set your credentials in the constants below.
// ─────────────────────────────────────────────────────────────────────────────

class EmailService {
  // ── EmailJS credentials ───────────────────────────────────────────────────
  // Sign up at https://www.emailjs.com (free: 200 emails/month)
  // 1. Create a service (Gmail, Outlook, etc.) → copy Service ID
  // 2. Create a template with these variables:
  //    {{to_email}}, {{to_name}}, {{subject}}, {{html_content}}, {{reply_to}}
  // 3. Copy your Public Key from Account → API Keys
  static const String _serviceId  = 'service_rlacrm';     // ← your Service ID
  static const String _templateId = 'template_rlacrm';    // ← your Template ID
  static const String _publicKey  = 'YOUR_EMAILJS_PUBLIC_KEY'; // ← your Public Key
  static const String _privateKey = 'YOUR_EMAILJS_PRIVATE_KEY'; // ← your Private Key (for server-side send)

  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // ── Send via EmailJS REST API ─────────────────────────────────────────────
  static Future<bool> send({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlContent,
    String replyTo = 'noreply@rlacrm.com',
  }) async {
    // Skip in debug if credentials not set
    if (_publicKey == 'YOUR_EMAILJS_PUBLIC_KEY') {
      if (kDebugMode) debugPrint('📧 [EMAIL SKIPPED – no EmailJS key] To: $toEmail | $subject');
      return true; // return true so flow is not blocked
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'https://rlacrm.com',
        },
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'accessToken': _privateKey,
          'template_params': {
            'to_email':    toEmail,
            'to_name':     toName,
            'subject':     subject,
            'html_content': htmlContent,
            'reply_to':    replyTo,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      final ok = response.statusCode == 200;
      if (kDebugMode) {
        debugPrint(ok
            ? '📧 [EMAIL SENT] To: $toEmail | $subject'
            : '📧 [EMAIL FAILED ${response.statusCode}] $toEmail | ${response.body}');
      }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('📧 [EMAIL ERROR] $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HTML EMAIL TEMPLATES  — minimalist, on-brand (lavender/navy palette)
  // ═══════════════════════════════════════════════════════════════════════════

  static String _wrap(String title, String body) => '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$title</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap');
  *{margin:0;padding:0;box-sizing:border-box;}
  body{background:#F4F4F8;font-family:'Inter',sans-serif;color:#1A1A2E;}
  .wrap{max-width:560px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.07);}
  .header{background:linear-gradient(135deg,#7C6FFF 0%,#9B8FFF 100%);padding:28px 32px;display:flex;align-items:center;gap:14px;}
  .logo-box{width:44px;height:44px;background:rgba(255,255,255,.18);border-radius:11px;display:flex;align-items:center;justify-content:center;font-size:22px;font-weight:900;color:#fff;flex-shrink:0;}
  .header-text{color:#fff;}
  .header-text h1{font-size:18px;font-weight:800;letter-spacing:.5px;}
  .header-text p{font-size:11px;opacity:.8;margin-top:2px;}
  .body{padding:32px;}
  .greeting{font-size:15px;font-weight:600;margin-bottom:6px;}
  .para{font-size:13px;color:#4A4A6A;line-height:1.7;margin-bottom:12px;}
  .card{background:#F8F8FA;border-radius:12px;padding:18px 20px;margin:20px 0;border:1px solid #EBEBF0;}
  .cred-row{display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #EBEBF0;font-size:13px;}
  .cred-row:last-child{border-bottom:none;}
  .cred-label{color:#888;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.4px;}
  .cred-value{font-weight:700;color:#1A1A2E;font-size:13px;}
  .otp-box{background:linear-gradient(135deg,#7C6FFF15,#FF9F7C0D);border:1.5px solid #7C6FFF40;border-radius:12px;padding:20px;text-align:center;margin:20px 0;}
  .otp-code{font-size:34px;font-weight:800;letter-spacing:8px;color:#7C6FFF;margin:8px 0;}
  .otp-note{font-size:11px;color:#888;}
  .btn{display:inline-block;background:linear-gradient(135deg,#7C6FFF,#9B8FFF);color:#fff;text-decoration:none;padding:12px 28px;border-radius:10px;font-weight:700;font-size:13px;margin:16px 0;}
  .tag{display:inline-block;background:#7C6FFF18;color:#7C6FFF;border-radius:6px;padding:3px 10px;font-size:11px;font-weight:700;}
  .footer{background:#F8F8FA;border-top:1px solid #EBEBF0;padding:18px 32px;font-size:11px;color:#AAA;text-align:center;line-height:1.6;}
  .footer a{color:#7C6FFF;text-decoration:none;}
  .divider{height:1px;background:#EBEBF0;margin:16px 0;}
  .highlight{color:#7C6FFF;font-weight:700;}
  .warn{font-size:11px;color:#D04060;margin-top:6px;}
</style>
</head>
<body>
<div class="wrap">
  <div class="header">
    <div class="logo-box">R</div>
    <div class="header-text">
      <h1>RLA CRM</h1>
      <p>Real Estate · Leads · Growth</p>
    </div>
  </div>
  <div class="body">$body</div>
  <div class="footer">
    This email was sent by <a href="https://rlacrm.com">RLA CRM</a>.<br>
    If you did not expect this email, please ignore it.
  </div>
</div>
</body>
</html>
''';

  // ── 1. Welcome / Account Created (with credentials) ─────────────────────
  static String welcomeEmail({
    required String name,
    required String email,
    required String password,
    required String role,
    required String projectName,
  }) {
    final body = '''
<p class="greeting">Welcome, $name! 👋</p>
<p class="para">Your RLA CRM account has been created. Here are your login credentials:</p>
<div class="card">
  <div class="cred-row"><span class="cred-label">Email</span><span class="cred-value">$email</span></div>
  <div class="cred-row"><span class="cred-label">Password</span><span class="cred-value">$password</span></div>
  <div class="cred-row"><span class="cred-label">Role</span><span class="cred-value">$role</span></div>
  <div class="cred-row"><span class="cred-label">Project</span><span class="cred-value">$projectName</span></div>
</div>
<p class="para">You can now log in to <a href="https://rlacrm.com" style="color:#7C6FFF;font-weight:600;">rlacrm.com</a> and start managing your leads.</p>
<p class="para warn">Please change your password after your first login for security.</p>
''';
    return _wrap('Welcome to RLA CRM', body);
  }

  // ── 2. Signup Request Received ───────────────────────────────────────────
  static String signupRequestEmail({
    required String name,
    required String projectName,
  }) {
    final body = '''
<p class="greeting">Hi $name,</p>
<p class="para">Your signup request for <span class="highlight">$projectName</span> on RLA CRM has been received.</p>
<div class="card">
  <p class="para" style="margin:0;">Your request is currently <span class="tag">Pending Approval</span>. Once the project admin reviews it, you will receive a confirmation email with your login credentials.</p>
</div>
<p class="para">If you have any questions, please contact your project manager.</p>
''';
    return _wrap('Signup Request Received – RLA CRM', body);
  }

  // ── 3. Signup Rejected ───────────────────────────────────────────────────
  static String signupRejectedEmail({
    required String name,
    required String projectName,
    String? reason,
  }) {
    final body = '''
<p class="greeting">Hi $name,</p>
<p class="para">We regret to inform you that your signup request for <span class="highlight">$projectName</span> was not approved.</p>
${reason != null ? '<div class="card"><span class="cred-label">Reason</span><p class="para" style="margin-top:6px;">$reason</p></div>' : ''}
<p class="para">Please contact your project manager for further assistance.</p>
''';
    return _wrap('Signup Request Update – RLA CRM', body);
  }

  // ── 4. Admin notified of new signup request ──────────────────────────────
  static String adminNewSignupEmail({
    required String adminName,
    required String applicantName,
    required String applicantEmail,
    required String projectName,
  }) {
    final body = '''
<p class="greeting">Hi $adminName,</p>
<p class="para">A new sales team member has requested to join <span class="highlight">$projectName</span>.</p>
<div class="card">
  <div class="cred-row"><span class="cred-label">Name</span><span class="cred-value">$applicantName</span></div>
  <div class="cred-row"><span class="cred-label">Email</span><span class="cred-value">$applicantEmail</span></div>
  <div class="cred-row"><span class="cred-label">Project</span><span class="cred-value">$projectName</span></div>
</div>
<p class="para">Log in to <a href="https://rlacrm.com" style="color:#7C6FFF;font-weight:600;">RLA CRM</a> → Team → Pending Approvals to approve or reject this request.</p>
''';
    return _wrap('New Signup Request – $projectName', body);
  }

  // ── 5. OTP / Forgot Password ─────────────────────────────────────────────
  static String otpEmail({
    required String name,
    required String otp,
  }) {
    final body = '''
<p class="greeting">Hi $name,</p>
<p class="para">You requested a password reset for your RLA CRM account. Use the OTP below:</p>
<div class="otp-box">
  <p style="font-size:12px;color:#888;font-weight:600;letter-spacing:.5px;text-transform:uppercase;">Your One-Time Password</p>
  <div class="otp-code">$otp</div>
  <p class="otp-note">This OTP expires in <strong>10 minutes</strong>.</p>
</div>
<p class="para">If you did not request a password reset, please ignore this email. Your password will remain unchanged.</p>
''';
    return _wrap('Password Reset OTP – RLA CRM', body);
  }

  // ── 6. Lead Update notification to admin ────────────────────────────────
  static String leadUpdateToAdminEmail({
    required String adminName,
    required String agentName,
    required String leadName,
    required String action,
    required String projectName,
    String? note,
  }) {
    final body = '''
<p class="greeting">Hi $adminName,</p>
<p class="para"><span class="highlight">$agentName</span> updated a lead in <span class="highlight">$projectName</span>.</p>
<div class="card">
  <div class="cred-row"><span class="cred-label">Lead</span><span class="cred-value">$leadName</span></div>
  <div class="cred-row"><span class="cred-label">Action</span><span class="cred-value">$action</span></div>
  <div class="cred-row"><span class="cred-label">Updated By</span><span class="cred-value">$agentName</span></div>
  <div class="cred-row"><span class="cred-label">Project</span><span class="cred-value">$projectName</span></div>
  ${note != null ? '<div class="cred-row"><span class="cred-label">Notes</span><span class="cred-value">$note</span></div>' : ''}
</div>
<p class="para"><a href="https://rlacrm.com" style="color:#7C6FFF;font-weight:600;">View in RLA CRM →</a></p>
''';
    return _wrap('Lead Update – $projectName', body);
  }

  // ── 7. Project update notification to sales team ─────────────────────────
  static String projectUpdateToTeamEmail({
    required String memberName,
    required String projectName,
    required String updateType,
    required String updatedBy,
    String? details,
  }) {
    final body = '''
<p class="greeting">Hi $memberName,</p>
<p class="para">There's an update in your project <span class="highlight">$projectName</span>.</p>
<div class="card">
  <div class="cred-row"><span class="cred-label">Update</span><span class="cred-value">$updateType</span></div>
  <div class="cred-row"><span class="cred-label">By</span><span class="cred-value">$updatedBy</span></div>
  <div class="cred-row"><span class="cred-label">Project</span><span class="cred-value">$projectName</span></div>
  ${details != null ? '<div class="cred-row"><span class="cred-label">Details</span><span class="cred-value">$details</span></div>' : ''}
</div>
<p class="para"><a href="https://rlacrm.com" style="color:#7C6FFF;font-weight:600;">View in RLA CRM →</a></p>
''';
    return _wrap('Project Update – $projectName', body);
  }

  // ── 8. Lead assigned to sales agent ─────────────────────────────────────
  static String leadAssignedEmail({
    required String agentName,
    required String leadName,
    required String leadPhone,
    required String projectName,
    required String assignedBy,
    String? notes,
  }) {
    final body = '''
<p class="greeting">Hi $agentName,</p>
<p class="para">A new lead has been assigned to you in <span class="highlight">$projectName</span>.</p>
<div class="card">
  <div class="cred-row"><span class="cred-label">Lead Name</span><span class="cred-value">$leadName</span></div>
  <div class="cred-row"><span class="cred-label">Phone</span><span class="cred-value">$leadPhone</span></div>
  <div class="cred-row"><span class="cred-label">Project</span><span class="cred-value">$projectName</span></div>
  <div class="cred-row"><span class="cred-label">Assigned By</span><span class="cred-value">$assignedBy</span></div>
  ${notes != null && notes.isNotEmpty ? '<div class="cred-row"><span class="cred-label">Notes</span><span class="cred-value">$notes</span></div>' : ''}
</div>
<p class="para"><a href="https://rlacrm.com" style="color:#7C6FFF;font-weight:600;">View Lead in RLA CRM →</a></p>
''';
    return _wrap('New Lead Assigned – $projectName', body);
  }

  // ── 9. Lead status changed to Closed ────────────────────────────────────
  static String leadClosedEmail({
    required String adminName,
    required String agentName,
    required String leadName,
    required String projectName,
    String? dealValue,
  }) {
    final body = '''
<p class="greeting">Hi $adminName,</p>
<p class="para">🎉 A deal has been closed in <span class="highlight">$projectName</span>!</p>
<div class="card">
  <div class="cred-row"><span class="cred-label">Client</span><span class="cred-value">$leadName</span></div>
  <div class="cred-row"><span class="cred-label">Closed By</span><span class="cred-value">$agentName</span></div>
  <div class="cred-row"><span class="cred-label">Project</span><span class="cred-value">$projectName</span></div>
  ${dealValue != null ? '<div class="cred-row"><span class="cred-label">Deal Value</span><span class="cred-value" style="color:#7C6FFF;font-size:15px;">$dealValue</span></div>' : ''}
</div>
<p class="para"><a href="https://rlacrm.com" style="color:#7C6FFF;font-weight:600;">View in RLA CRM →</a></p>
''';
    return _wrap('Deal Closed 🎉 – $projectName', body);
  }
}
