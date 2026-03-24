import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { student, lecturer }

class AppState {
  static String uid = "";
  static String fullName = "";
  static UserRole role = UserRole.student;

  /// Call this after login AND also in app start (auth listener).
  static Future<void> syncFromAuth(User? user) async {
    uid = user?.uid ?? "";
    if (uid.isEmpty) {
      fullName = "";
      role = UserRole.student;
      return;
    }

    // Load profile from Firestore: /users/{uid}
    final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final data = doc.data();

    fullName = (data?["fullName"] ?? data?["name"] ?? user?.email ?? "User").toString();

    final roleStr = (data?["role"] ?? "student").toString().toLowerCase();
    role = roleStr == "lecturer" ? UserRole.lecturer : UserRole.student;
  }
}
