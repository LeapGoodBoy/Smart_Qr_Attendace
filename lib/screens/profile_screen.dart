import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // Clear local state
    AppState.uid = "";
    AppState.fullName = "User";
    AppState.role = UserRole.student;

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, "/login", (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLecturer = AppState.role == UserRole.lecturer;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(context),

                const SizedBox(height: 14),

                _profileHeader(isLecturer),

                const SizedBox(height: 14),

                _quickButtons(context, isLecturer, onLogout: () => _logout(context)),

                const SizedBox(height: 16),

                _sectionTitle("Personal Information"),
                const SizedBox(height: 10),

                _infoTile(
                  icon: Icons.badge_outlined,
                  title: isLecturer ? "Staff ID" : "Student ID",
                  value: isLecturer ? "STF-03412" : "STD-12345",
                ),
                const SizedBox(height: 10),

                _infoTile(
                  icon: Icons.school_outlined,
                  title: isLecturer ? "Department" : "Program",
                  value: isLecturer ? "Computer Science" : "Software Engineering",
                  trailingArrow: true,
                ),
                const SizedBox(height: 10),

                _infoTile(
                  icon: Icons.account_balance_outlined,
                  title: isLecturer ? "Faculty" : "Year",
                  value: isLecturer ? "Engineering & Technology" : "Year 4",
                ),

                const SizedBox(height: 18),

                _sectionTitle(isLecturer ? "Lecturer Actions" : "Student Actions"),
                const SizedBox(height: 10),

                _actionTile(
                  icon: Icons.settings_outlined,
                  title: "Settings",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Settings")),
                    );
                  },
                ),
                const SizedBox(height: 10),

                _actionTile(
                  icon: Icons.help_outline,
                  title: "Help & Support",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Help & Support")),
                    );
                  },
                ),

                const SizedBox(height: 20),

                Text(
                  "APP VERSION 1.0.0",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= TOP BAR =================
  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            Navigator.pop(context); // ✅ go back to dashboard
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Expanded(
          child: Text(
            "Profile",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Edit Profile (coming soon)")),
            );
          },
          icon: Icon(Icons.settings_outlined, color: Colors.white.withOpacity(0.85)),
        ),
      ],
    );
  }

  // ================= PROFILE HEADER =================
  Widget _profileHeader(bool isLecturer) {
    final name = AppState.fullName.isEmpty ? "User" : AppState.fullName;

    final displayName =
        isLecturer ? (name.startsWith("Dr.") ? name : "Dr. $name") : name;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=47"),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: const TextStyle(
              color: Color.fromARGB(255, 196, 204, 194),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isLecturer ? "Lecturer Account" : "Student Account",
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1677FF).withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF1677FF).withOpacity(0.30)),
            ),
            child: Text(
              isLecturer ? "Lecturer & Attendance Admin" : "Student • Attendance Tracking",
              style: const TextStyle(
                color: Color(0xFF2D8CFF),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= QUICK BUTTONS (3 buttons) =================
  Widget _quickButtons(
    BuildContext context,
    bool isLecturer, {
    required VoidCallback onLogout,
  }) {
    return Row(
      children: [
        Expanded(
          child: _primaryBtn(
            text: isLecturer ? "View Classes" : "Scan Attendance",
            onTap: () {
              // optional: route to scan/classes later
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isLecturer ? "View Classes (use dashboard)" : "Scan Attendance (use dashboard)"),
                ),
              );
            },
          ),
        ),
 
        const SizedBox(width: 10),

        Expanded(
          child: _secondaryBtn(
            text: "Edit Profile",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Edit Profile (coming soon)")),
              );
            },
          ),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: _dangerBtn(
            text: "Log out",
            onTap: onLogout,
          ),
        ),
      ],
    );
  }

  // ================= BUTTON STYLES =================
  Widget _primaryBtn({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1677FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _secondaryBtn({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _dangerBtn({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ================= INFO =================
  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.45),
        fontWeight: FontWeight.w900,
        fontSize: 11,
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    bool trailingArrow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (trailingArrow)
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
