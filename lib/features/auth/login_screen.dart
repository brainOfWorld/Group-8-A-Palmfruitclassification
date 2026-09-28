import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import '../../core/theme/colors.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'signup_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LoginScreen({super.key, required this.cameras});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  String? _fingerprintEmail;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    if (!mounted) return;
    setState(() => _isBiometricAvailable = available);

    if (available) {
      final email = await AuthService.getFingerprintUser();
      if (mounted) {
        setState(() => _fingerprintEmail = email);
      }
    }
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Fields cannot be empty.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await AuthService.verifyCredentials(email, password);

      if (isValid) {
        await AuthService.saveSession(email);
        if (!mounted) return;
        await _offerFingerprintEnroll(email);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(cameras: widget.cameras),
          ),
        );
      } else {
        setState(() => _isLoading = false);
        _showError("Invalid email or password.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Database connection failed. Please restart the app.");
    }
  }

  Future<void> _handleFingerprintLogin() async {
    final ok = await BiometricService.authenticate(
      "Authenticate to access Palmfruit Grader",
    );
    if (!ok || !mounted) return;

    final email = await AuthService.getFingerprintUser();
    if (email == null || !mounted) return;

    await AuthService.saveSession(email);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(cameras: widget.cameras),
      ),
    );
  }

  Future<void> _offerFingerprintEnroll(String email) async {
    if (!_isBiometricAvailable || _fingerprintEmail != null) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.containerBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Quick Login",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "Enable fingerprint to skip typing your credentials next time?",
          style: TextStyle(color: Color(0xFF9E9E9E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("SKIP",
                style: TextStyle(color: Color(0xFF757575))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ENABLE",
                style: TextStyle(color: AppColors.neonOrange)),
          ),
        ],
      ),
    );

    if (enable == true) {
      final ok = await BiometricService.authenticate(
        "Register your fingerprint for quick login",
      );
      if (ok) {
        await AuthService.enableFingerprint(email);
        if (mounted) {
          setState(() => _fingerprintEmail = email);
        }
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.containerBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Access Denied",
            style: TextStyle(color: Colors.white)),
        content: Text(message,
            style: const TextStyle(color: Color(0xFF9E9E9E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK",
                style: TextStyle(color: AppColors.neonOrange)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                _buildForm(),
                const SizedBox(height: 32),
                _buildLoginButton(),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SignUpScreen(cameras: widget.cameras),
                      ),
                    );
                  },
                  child: const Text(
                    "New here? Create an Account",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neonOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.neonOrange.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.eco_rounded,
            size: 48,
            color: AppColors.neonOrange,
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text(
          "PALMFRUIT GRADER",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          "Secured Analyst Access",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Email Address",
              labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
              prefixIcon: const Icon(Icons.email_outlined,
                  color: Color(0xFF757575)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.neonOrange),
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Password",
              labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
              prefixIcon: const Icon(Icons.lock_outlined,
                  color: Color(0xFF757575)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.neonOrange),
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
            ),
          ),
          if (_fingerprintEmail != null) ...[
            const SizedBox(height: 16),
            _buildFormFingerprintOption(),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildFormFingerprintOption() {
    return GestureDetector(
      onTap: _handleFingerprintLogin,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.neonOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fingerprint,
                  color: AppColors.neonOrange, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "USE FINGERPRINT",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF757575), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTap: _isLoading ? null : _handleLogin,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.neonOrange,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "SIGN IN",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

}
