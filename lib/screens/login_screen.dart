import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _loading    = false;
  bool _rememberMe = false;
  String? _error;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    // Pre-fill if remembered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.rememberedEmail != null) {
        _emailCtrl.text = state.rememberedEmail!;
        _passCtrl.text  = state.rememberedPassword ?? '';
        setState(() => _rememberMe = true);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() { _error = 'Please enter your email and password.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    if (!mounted) return;
    final state = context.read<AppState>();

    // Use the async version which awaits a cloud sync before authenticating.
    // This ensures users created on web / another device are always found,
    // even on the very first login attempt on a fresh install.
    final err = await state.loginWithErrorAsync(email, pass);

    if (!mounted) return;
    if (err == null) {
      if (_rememberMe) {
        state.saveRememberMe(email, pass);
      } else {
        state.clearRememberMe();
      }
    }
    setState(() {
      _loading = false;
      if (err != null) _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BlobBg(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: isWide ? _buildWideLayout() : _buildMobileLayout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEEE8FF), Color(0xFFFFF0F5), Color(0xFFF0F8FF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RlaBrand(size: 32),
                  const SizedBox(height: 8),
                  Text('Real Estate Lead Management',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('Close More Deals,\nFaster.',
                      style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.15)),
                  const SizedBox(height: 16),
                  Text('The CRM built exclusively for real estate teams —\nfrom lead capture to deal closure.',
                      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 40),
                  _featureTile(Icons.apartment_outlined,       'Multi-Project Platform',     'Manage multiple real estate projects from one place'),
                  const SizedBox(height: 16),
                  _featureTile(Icons.insights_outlined,        'Advanced Analytics',         'Pipeline stages, lead sources, team leaderboards'),
                  const SizedBox(height: 16),
                  _featureTile(Icons.shield_outlined,          'Role-based Access',          'Master Admin → Project Admin → Sales Team'),
                  const SizedBox(height: 16),
                  _featureTile(Icons.notifications_outlined,   'Real-time Alerts',           'Approval workflows, team notifications, email logs'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _trustChip(Icons.business_outlined,   'Multi-tenant'),
                        const SizedBox(width: 16),
                        _trustChip(Icons.lock_outline_rounded, 'Secure'),
                        const SizedBox(width: 16),
                        _trustChip(Icons.star_outline_rounded, 'Free Trial'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 440,
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
            child: _buildForm(isWide: true),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: size.height * 0.10),
          const Center(child: RlaBrand(size: 28)),
          const SizedBox(height: 8),
          Center(
            child: Text('Real Estate Lead Management',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, letterSpacing: 0.5)),
          ),
          SizedBox(height: size.height * 0.06),
          _buildForm(isWide: false),
        ],
      ),
    );
  }

  Widget _buildForm({bool isWide = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide) ...[
          Text('Welcome back', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 4),
        ],
        Text('Sign In',
            style: GoogleFonts.inter(fontSize: isWide ? 28 : 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Access your RLA CRM dashboard',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 28),
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_emailCtrl, 'Email / Username', Icons.mail_outline_rounded),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: AppColors.textMuted),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 10),
              // ── Remember Me + Forgot Password row ─────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            gradient: _rememberMe ? AppColors.gradientCTA : null,
                            color:    _rememberMe ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _rememberMe ? Colors.transparent : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: _rememberMe
                              ? const Icon(Icons.check_rounded, size: 12, color: AppColors.textPrimary)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text('Remember me',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showForgotPassword(),
                    child: Text('Forgot password?',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lavender)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.pink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFD04060)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD04060)))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              GradientButton(label: 'Sign In', onTap: _login, isLoading: _loading, icon: Icons.login_rounded),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('New to RLA CRM?',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Contact your Master Admin to be added as a Project Admin, or join an existing project as a Sales Team member.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              _signupBtn(
                'Join Sales Team',
                'Request access to a project',
                Icons.person_add_outlined,
                AppColors.gradientTertiary,
                _showSalesTeamSignup,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _featureTile(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: AppColors.gradientPrimary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(sub,   style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trustChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
      ),
    );
  }

  Widget _signupBtn(String title, String sub, IconData icon, LinearGradient grad, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [grad.colors.first.withValues(alpha: 0.15), grad.colors.last.withValues(alpha: 0.1)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: grad.colors.first.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (b) => grad.createShader(b),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(sub,   style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  void _showSalesTeamSignup() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const _SalesTeamSignupSheet(),
    );
  }

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const _ForgotPasswordSheet(),
    );
  }
}

// ─── Sales Team Signup Sheet ──────────────────────────────────────────────────────
class _SalesTeamSignupSheet extends StatefulWidget {
  const _SalesTeamSignupSheet();
  @override
  State<_SalesTeamSignupSheet> createState() => _SalesTeamSignupSheetState();
}

class _SalesTeamSignupSheetState extends State<_SalesTeamSignupSheet> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool   _obscure  = true;
  bool   _loading  = false;
  String? _error;
  String? _selectedCompanyId;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  void _signup() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'All fields are required'); return;
    }
    if (_selectedCompanyId == null) {
      setState(() => _error = 'Please select your project'); return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters'); return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final result = context.read<AppState>().submitEmployeeSignup(
      name:      _nameCtrl.text.trim(),
      email:     _emailCtrl.text.trim(),
      password:  _passCtrl.text.trim(),
      companyId: _selectedCompanyId!,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() { _loading = false; _error = result.error; });
    } else {
      Navigator.pop(context);
      String msg; Color color;
      if (result.pendingApproval) {
        msg   = 'Request submitted! The Project Admin will review your signup request. You\'ll receive an email once approved.';
        color = const Color(0xFF3B7A8A);
      } else if (result.promotedToAdmin) {
        msg   = 'Admin access granted! Your email matched the registered project admin email.';
        color = const Color(0xFF5B3FBF);
      } else {
        msg   = 'Account created! You can now sign in.';
        color = const Color(0xFF3B8A6E);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: color,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use projects list — in the project-centric flow, sales reps join a project directly.
    // Only show projects that have an assigned admin (companyId != 'rla_platform') or all projects.
    final projects = context.watch<AppState>().projects
        .where((p) => p.status == ProjectStatus.active)
        .toList();
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 36, height: 36,
                    decoration: BoxDecoration(gradient: AppColors.gradientTertiary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add_outlined, size: 18, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Join as Sales Team', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('Request access · Project Admin approves', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sky.withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2090A0)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Your request will be sent to the Project Admin for approval. You\'ll be notified by email.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2090A0)),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Select Your Project *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.peach.withValues(alpha: 0.3))),
                child: Text('No active projects available. Please contact the master admin.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _selectedCompanyId == null ? AppColors.border : AppColors.lavender,
                      width: _selectedCompanyId == null ? 1 : 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCompanyId,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('-- Choose project --', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    ),
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    borderRadius: BorderRadius.circular(14),
                    items: projects.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(width: 30, height: 30,
                              decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(p.location, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCompanyId = v),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _sheetField(_nameCtrl, 'Your Full Name *', Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _sheetField(_emailCtrl, 'Email Address *', Icons.mail_outline_rounded, TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl, obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password *',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18, color: AppColors.textMuted),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD04060))),
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(
              label: 'Submit Request', onTap: _signup, isLoading: _loading,
              icon: Icons.send_outlined, gradient: AppColors.gradientTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController c, String label, IconData icon, [TextInputType? type]) {
    return TextField(
      controller: c, keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted)),
    );
  }
}

// ─── Forgot Password Sheet ────────────────────────────────────────────────────
enum _FpStep { email, otp, newPassword, done }

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();
  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  _FpStep _step = _FpStep.email;

  final _emailCtrl    = TextEditingController();
  final _otpCtrl      = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool   _obscureNew     = true;
  bool   _obscureConfirm = true;
  bool   _loading        = false;
  String? _error;
  String? _otpForDisplay; // shown in-app since no real SMTP

  @override
  void dispose() {
    _emailCtrl.dispose(); _otpCtrl.dispose();
    _passCtrl.dispose();  _confirmCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { setState(() => _error = 'Enter your email address'); return; }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final state = context.read<AppState>();
    if (!state.emailExists(email)) {
      setState(() { _loading = false; _error = 'No account found with this email.'; });
      return;
    }
    final otp = state.generatePasswordResetOtp(email);
    setState(() { _loading = false; _step = _FpStep.otp; _otpForDisplay = otp; });
  }

  void _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) { setState(() => _error = 'Enter the OTP'); return; }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final err = context.read<AppState>().verifyOtp(_emailCtrl.text.trim(), otp);
    setState(() { _loading = false; });
    if (err != null) { setState(() => _error = err); return; }
    setState(() { _step = _FpStep.newPassword; _error = null; });
  }

  void _resetPassword() async {
    final pass    = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pass.isEmpty)     { setState(() => _error = 'Enter a new password'); return; }
    if (pass.length < 6)  { setState(() => _error = 'Password must be at least 6 characters'); return; }
    if (pass != confirm)  { setState(() => _error = 'Passwords do not match'); return; }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final err = context.read<AppState>().resetPassword(_emailCtrl.text.trim(), pass);
    setState(() { _loading = false; });
    if (err != null) { setState(() => _error = err); return; }
    setState(() { _step = _FpStep.done; });
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
            // Header
            Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(gradient: AppColors.gradientSecondary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_reset_rounded, size: 18, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset Password', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(_stepSubtitle(), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              )),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 20),
            // Step indicator
            _buildStepDots(),
            const SizedBox(height: 20),
            // Content
            if (_step == _FpStep.email)   _buildEmailStep()
            else if (_step == _FpStep.otp) _buildOtpStep()
            else if (_step == _FpStep.newPassword) _buildNewPasswordStep()
            else _buildDoneStep(),
          ],
        ),
      ),
    );
  }

  String _stepSubtitle() {
    switch (_step) {
      case _FpStep.email:       return 'Enter your registered email';
      case _FpStep.otp:         return 'Enter the OTP sent to your email';
      case _FpStep.newPassword: return 'Create a new password';
      case _FpStep.done:        return 'Password reset successful';
    }
  }

  Widget _buildStepDots() {
    final steps = [_FpStep.email, _FpStep.otp, _FpStep.newPassword, _FpStep.done];
    final labels = ['Email', 'OTP', 'Password', 'Done'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isPast    = steps.indexOf(_step) > i;
        final isCurrent = steps[i] == _step;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (isPast || isCurrent) ? AppColors.gradientCTA : null,
                      color: (isPast || isCurrent) ? null : AppColors.border,
                    ),
                    child: Center(
                      child: isPast
                          ? const Icon(Icons.check_rounded, size: 12, color: AppColors.textPrimary)
                          : Text('${i + 1}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                                color: isCurrent ? AppColors.textPrimary : AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: GoogleFonts.inter(fontSize: 9, color: isCurrent ? AppColors.textPrimary : AppColors.textMuted, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(child: Container(height: 1, margin: const EdgeInsets.only(bottom: 14), color: (steps.indexOf(_step) > i) ? AppColors.lavender : AppColors.border)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmailStep() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.mail_outlined, size: 16, color: AppColors.lavender),
          const SizedBox(width: 10),
          Expanded(child: Text('We\'ll send a 6-digit OTP to your registered email address.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
        ]),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Registered Email Address',
          prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textMuted),
        ),
        onSubmitted: (_) => _sendOtp(),
      ),
      _errorWidget(),
      const SizedBox(height: 20),
      GradientButton(label: 'Send OTP', onTap: _sendOtp, isLoading: _loading, icon: Icons.send_rounded),
    ]);
  }

  Widget _buildOtpStep() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.sky.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sky.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF2090A0)),
            const SizedBox(width: 8),
            Text('OTP sent to ${_emailCtrl.text.trim()}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2090A0))),
          ]),
          const SizedBox(height: 6),
          if (_otpForDisplay != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('Demo OTP: ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                Text(_otpForDisplay!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 2)),
                Text(' (no real email in demo)', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'Enter 6-digit OTP',
          counterText: '',
          prefixIcon: Icon(Icons.pin_outlined, size: 18, color: AppColors.textMuted),
        ),
        onSubmitted: (_) => _verifyOtp(),
      ),
      _errorWidget(),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          final otp = context.read<AppState>().generatePasswordResetOtp(_emailCtrl.text.trim());
          setState(() { _otpForDisplay = otp; _error = null; });
        },
        child: Text('Resend OTP', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lavender)),
      ),
      const SizedBox(height: 20),
      GradientButton(label: 'Verify OTP', onTap: _verifyOtp, isLoading: _loading, icon: Icons.verified_outlined),
    ]);
  }

  Widget _buildNewPasswordStep() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFB8FFE4).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF40C080).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF3B8A6E)),
          const SizedBox(width: 8),
          Text('OTP verified successfully!',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF3B8A6E))),
        ]),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _passCtrl, obscureText: _obscureNew,
        decoration: InputDecoration(
          labelText: 'New Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscureNew = !_obscureNew),
            child: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18, color: AppColors.textMuted),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _confirmCtrl, obscureText: _obscureConfirm,
        decoration: InputDecoration(
          labelText: 'Confirm New Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18, color: AppColors.textMuted),
          ),
        ),
        onSubmitted: (_) => _resetPassword(),
      ),
      _errorWidget(),
      const SizedBox(height: 20),
      GradientButton(label: 'Reset Password', onTap: _resetPassword, isLoading: _loading, icon: Icons.lock_reset_rounded),
    ]);
  }

  Widget _buildDoneStep() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.gradientSuccess.colors.first.withValues(alpha: 0.15), AppColors.gradientSuccess.colors.last.withValues(alpha: 0.08)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gradientSuccess.colors.first.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Container(width: 60, height: 60,
            decoration: BoxDecoration(gradient: AppColors.gradientSuccess, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 30, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Text('Password Reset Successfully!',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('You can now sign in with your new password.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
      const SizedBox(height: 20),
      GradientButton(
        label: 'Back to Sign In',
        onTap: () => Navigator.pop(context),
        icon: Icons.login_rounded,
      ),
    ]);
  }

  Widget _errorWidget() {
    if (_error == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFD04060)),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD04060)))),
        ]),
      ),
    );
  }
}

// ─── Blob background ─────────────────────────────────────────────────────────
class _BlobBg extends StatelessWidget {
  const _BlobBg();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(top: -60, right: -60,
          child: Container(width: 220, height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.lavender.withValues(alpha: 0.25), Colors.transparent])),
          )),
        Positioned(bottom: 60, left: -80,
          child: Container(width: 260, height: 260,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.peach.withValues(alpha: 0.2), Colors.transparent])),
          )),
        Positioned(top: 300, right: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.sky.withValues(alpha: 0.2), Colors.transparent])),
          )),
      ],
    );
  }
}
