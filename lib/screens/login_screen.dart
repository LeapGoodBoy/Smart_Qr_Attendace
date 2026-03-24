import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool hidePassword = true;
  bool loading = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$").hasMatch(email.trim());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    // Firebase recently uses "invalid-credential" for wrong password in many cases
    final code = e.code;

    if (code == "invalid-credential" || code == "wrong-password") {
      return "Wrong password. Please try again.";
    }
    if (code == "user-not-found") {
      return "No account found with this email.";
    }
    if (code == "invalid-email") {
      return "Invalid email format.";
    }
    if (code == "user-disabled") {
      return "This account has been disabled.";
    }
    if (code == "too-many-requests") {
      return "Too many attempts. Please try again later.";
    }
    if (code == "network-request-failed") {
      return "No internet connection. Please check your network.";
    }

    // fallback
    return e.message ?? "Login failed. Please try again.";
  }

  Future<void> _onLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _toast("Please enter email and password");
      return;
    }

    if (!_isValidEmail(email)) {
      _toast("Please enter a valid email");
      return;
    }

    setState(() => loading = true);

    try {
      // 1) Sign in (Auth)
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid ?? "";
      if (uid.isEmpty) {
        await FirebaseAuth.instance.signOut();
        throw Exception("Login failed. Please try again.");
      }

      // 2) Read profile (Firestore)
      final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
      final data = doc.data();

      if (data == null) {
        // Auth user exists but Firestore profile missing
        await FirebaseAuth.instance.signOut();
        throw Exception("User profile not found. Please register again.");
      }

      final fullName = (data["fullName"] ?? "User").toString();
      final roleString = (data["role"] ?? "student").toString();

      // 3) Save to AppState
      AppState.uid = uid;
      AppState.fullName = fullName;
      AppState.role = roleString == "lecturer" ? UserRole.lecturer : UserRole.student;

      // 4) Route
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppState.role == UserRole.lecturer ? "/lecturer" : "/student",
      );
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthMessage(e));
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) {
      _toast("Enter your email first");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _toast("Password reset email sent");
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF061A2A), Color(0xFF031019)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B4EA2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Smart Attendance",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Please sign in to continue",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),

                _label("Email"),
                const SizedBox(height: 8),
                _input(
                  controller: _emailCtrl,
                  hint: "student@university.edu",
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !loading,
                ),

                const SizedBox(height: 14),

                _label("Password"),
                const SizedBox(height: 8),
                _input(
                  controller: _passwordCtrl,
                  hint: "Enter your password",
                  icon: Icons.lock_outline,
                  obscure: hidePassword,
                  enabled: !loading,
                  trailing: IconButton(
                    onPressed: loading ? null : () => setState(() => hidePassword = !hidePassword),
                    icon: Icon(
                      hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading ? null : _forgotPassword,
                    child: Text(
                      "Forgot password?",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : _onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1677FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text(
                            "Log In",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: loading ? null : () => Navigator.pushNamed(context, "/register"),
                      child: const Text(
                        "Create account",
                        style: TextStyle(
                          color: Color(0xFF2D8CFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.75),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        enabled: enabled,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.55), size: 20),
          suffixIcon: trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
