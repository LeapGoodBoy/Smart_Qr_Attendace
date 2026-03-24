import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_state.dart';
import 'profile_screen.dart';
import 'student_history_screen.dart';
import 'student_scan_attendance.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "";

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 14),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentScanAttendanceScreen()));
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text("Scan Attendance"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1677FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Text(
                      "Recent Attendance",
                      style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentHistoryScreen()));
                      },
                      child: const Text("See All"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: uid.isEmpty
                      ? _emptyCard("Not logged in.\nPlease log in again.")
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection("users")
                              .doc(uid)
                              .collection("history")
                              .orderBy("scannedAt", descending: true)
                              .limit(5)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) return _loadingList();

                            if (snap.hasError) {
                              return _emptyCard("Error loading history:\n${snap.error}");
                            }

                            final docs = snap.data?.docs ?? [];
                            if (docs.isEmpty) return _emptyCard("No attendance yet.\nScan a QR to record attendance.");

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final data = docs[i].data();

                                final title = (data["classTitle"] ?? "Class").toString();
                                final code = (data["classCode"] ?? "").toString();
                                final status = (data["status"] ?? "present").toString();

                                final ts = data["scannedAt"];
                                final scannedAt = ts is Timestamp ? ts.toDate() : null;

                                return _attendanceTile(title: title, code: code, status: status, scannedAt: scannedAt);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        backgroundColor: const Color(0xFF061A2A),
        selectedItemColor: const Color(0xFF2D8CFF),
        unselectedItemColor: Colors.white.withOpacity(0.45),
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          setState(() => navIndex = i);
          if (i == 0) return;
          if (i == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentHistoryScreen()));
            return;
          }
          if (i == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            return;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final name = AppState.fullName.isEmpty ? "Student" : AppState.fullName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome,", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(color: Color(0xFF2D8CFF), fontWeight: FontWeight.w900, fontSize: 22)),
              const SizedBox(height: 6),
              Text("Student Dashboard", style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications (coming soon)"))),
          icon: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(Icons.notifications_none, color: Colors.white.withOpacity(0.85)),
          ),
        ),
      ],
    );
  }

  Widget _attendanceTile({
    required String title,
    required String code,
    required String status,
    required DateTime? scannedAt,
  }) {
    final s = status.toLowerCase();
    final isPresent = s == "present";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isPresent ? Colors.green : Colors.orange).withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (isPresent ? Colors.green : Colors.orange).withOpacity(0.25)),
            ),
            child: Icon(isPresent ? Icons.check_circle_outline : Icons.access_time,
                color: isPresent ? Colors.greenAccent : Colors.orangeAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                Text(code.isEmpty ? "—" : code, style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w700, fontSize: 12)),
                if (scannedAt != null) ...[
                  const SizedBox(height: 4),
                  Text("Scanned: ${_fmt(scannedAt)}", style: TextStyle(color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w600, fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(isPresent ? "Present" : status,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _loadingList() {
    return ListView.separated(
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}";
  }
}
