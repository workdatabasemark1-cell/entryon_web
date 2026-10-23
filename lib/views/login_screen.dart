import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_Provider.dart';
import '../utils/responsive.dart';
import 'navBarScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isHoveringBtn = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.alertCircle, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  authProvider.errorMessage ?? 'Invalid credentials. Please try again.',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDesktop = Responsive.isDesktop(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek deep slate
      body: Stack(
        children: [
          // Background ambient gradient blobs
          Positioned(
            top: -120,
            right: isDesktop ? size.width * 0.35 : -100,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0D9488).withValues(alpha: 0.35),
                    const Color(0xFF065F46).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withValues(alpha: 0.22),
                    const Color(0xFF0D9488).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: isDesktop
                        ? _buildDesktopLayout(authProvider)
                        : _buildMobileLayout(authProvider),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop / Web Dual-Column Layout ────────────────────────────────────────

  Widget _buildDesktopLayout(AuthProvider authProvider) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1040),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Brand Banner
              Expanded(
                flex: 5,
                child: _buildBrandHeroSection(),
              ),

              // Divider line
              Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),

              // Right Form Container
              Expanded(
                flex: 5,
                child: Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                  padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
                  child: _buildLoginForm(authProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile / Tablet Single Column Layout ───────────────────────────────────

  Widget _buildMobileLayout(AuthProvider authProvider) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Logo & Branding
            _buildLogoBadge(),
            const SizedBox(height: 18),
            Text(
              'Entry On',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to access your business hub',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),

            // Form
            _buildLoginForm(authProvider),
          ],
        ),
      ),
    );
  }

  // ── Brand Hero (Left Side on Desktop) ──────────────────────────────────────

  Widget _buildBrandHeroSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F766E).withValues(alpha: 0.6),
            const Color(0xFF0D9488).withValues(alpha: 0.25),
            const Color(0xFF0F172A).withValues(alpha: 0.95),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildLogoBadge(size: 44, iconSize: 22),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entry On',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Enterprise Service Management',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5EEAD4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                'Manage Services,\nCustomers & Finances with Precision.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unified platform for service entries, branch operations, transaction receipts, and audit intelligence.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: const Color(0xFFCBD5E1),
                  height: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Feature highlights
          Column(
            children: [
              _buildFeatureItem(
                icon: LucideIcons.building2,
                title: 'Customer & Branch Scope',
                description: 'Organize central customers and distinct branch networks seamlessly.',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: LucideIcons.receipt,
                title: 'Transaction & Receipt Records',
                description: 'Real-time payment receipt tracking with user accountability.',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: LucideIcons.shieldCheck,
                title: 'ZATCA & Security Ready',
                description: 'Enterprise grade authentication and audit tracking for all actions.',
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Footer version & author
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Cloud System Online • v1.0',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF5EEAD4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Login Form (Username, Password, Submit) ────────────────────────────────

  Widget _buildLoginForm(AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome back',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please enter your credentials to continue',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 28),

          // Username Field
          _buildFieldLabel('Username'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: _buildInputDecoration(
              hintText: 'Enter your username',
              icon: LucideIcons.user,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter username';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Password Field
          _buildFieldLabel('Password'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: _buildInputDecoration(
              hintText: 'Enter your password',
              icon: LucideIcons.lock,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  color: const Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                splashRadius: 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter password';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Remember Me Checkbox
          InkWell(
            onTap: () {
              setState(() => _rememberMe = !_rememberMe);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (val) {
                        setState(() => _rememberMe = val ?? true);
                      },
                      activeColor: const Color(0xFF0D9488),
                      checkColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Stay logged in on this device',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringBtn = true),
            onExit: (_) => setState(() => _isHoveringBtn = false),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: _isHoveringBtn
                        ? [const Color(0xFF14B8A6), const Color(0xFF0F766E)]
                        : [const Color(0xFF0D9488), const Color(0xFF0F766E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(
                        alpha: _isHoveringBtn ? 0.45 : 0.25,
                      ),
                      blurRadius: _isHoveringBtn ? 16 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sign In',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(LucideIcons.arrowRight, size: 16),
                          ],
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Security / Copyright Notice
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.shieldCheck, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Encrypted & Protected by Entry On Security',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE2E8F0),
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: const Color(0xFF64748B),
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF5EEAD4), size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1E293B).withValues(alpha: 0.7),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
      ),
      errorStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        color: const Color(0xFFF87171),
      ),
    );
  }

  Widget _buildLogoBadge({double size = 52, double iconSize = 26}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Icon(LucideIcons.keySquare, size: iconSize, color: Colors.white),
      ),
    );
  }
}