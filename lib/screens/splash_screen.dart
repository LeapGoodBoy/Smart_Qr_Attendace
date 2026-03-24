import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Keep splash visible a bit (your design), then route properly
    _timer = Timer(const Duration(seconds: 2), _routeFromSplash);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _routeFromSplash() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    // Not logged in → Login
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      // Logged in → read role from Firestore
      final uid = user.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();

      // If user exists in Auth but missing in Firestore, force re-login
      if (data == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final fullName = (data['fullName'] ?? 'User') as String;
      final roleString = (data['role'] ?? 'student') as String;

      AppState.uid = uid;
      AppState.fullName = fullName;
      AppState.role = roleString == 'lecturer' ? UserRole.lecturer : UserRole.student;

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppState.role == UserRole.lecturer ? '/lecturer' : '/student',
      );
    } catch (_) {
      // If anything goes wrong, go back to login (safe default)
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // your existing splash UI
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
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B4EA2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Icon(Icons.qr_code_2_rounded, size: 38, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Smart Attendance\nSystem",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Lecturer & Student Portal",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.75),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "LOADING RESOURCES...",
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: Colors.white.withOpacity(0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Colors.white.withOpacity(0.35)),
                    const SizedBox(width: 6),
                    Text(
                      "SECURE  V1.0.0",
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: Colors.white.withOpacity(0.35),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
