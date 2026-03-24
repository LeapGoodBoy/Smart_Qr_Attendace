import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';
import 'create_class_screen.dart';
import 'attendance_list_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'generate_qr_screen.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  int navIndex = 0;

  // ✅ Option A (uses Firestore composite index)
  // If you don't want to create an index, use Option B below.
  Stream<QuerySnapshot<Map<String, dynamic>>> _classesStream() {
    return FirebaseFirestore.instance
        .collection("classes")
        .where("lecturerId", isEqualTo: AppState.uid)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  // ✅ Option B (no index needed)
  // Stream<QuerySnapshot<Map<String, dynamic>>> _classesStream() {
  //   return FirebaseFirestore.instance
  //       .collection("classes")
  //       .where("lecturerId", isEqualTo: AppState.uid)
  //       .snapshots();
  // }

  Future<void> _deleteClass(BuildContext context, String classId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete class?"),
        content: const Text(
          "This will delete the class.\nSessions/attendance may remain unless you delete them too.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection("classes").doc(classId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Class deleted ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AppState.fullName.isEmpty ? "Lecturer" : AppState.fullName;

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
                // Header row
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=3"),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Dashboard",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Notifications (coming soon)")),
                        );
                      },
                      icon: Icon(Icons.notifications_none, color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  "Good Morning,\n$name.",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _topButton(
                        label: "Create Class",
                        icon: Icons.add_circle_outline,
                        filled: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateClassScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _topButton(
                        label: "Generate QR",
                        icon: Icons.qr_code_2_rounded,
                        filled: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GenerateQrScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Weekly attendance card (UI only)
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Weekly Attendance",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Last 7 Days",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "—",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                "",
                                style: TextStyle(
                                  color: Colors.greenAccent.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _fakeChart(),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Classes header
                Row(
                  children: [
                    Text(
                      "Your Classes",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text("View All"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Firestore list
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _classesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final err = snapshot.error.toString();

                      // 🔥 If it's the index error, show a nicer message
                      final isIndexError = err.contains("FAILED_PRECONDITION") ||
                          err.contains("failed-precondition") ||
                          err.contains("requires an index");

                      return _card(
                        child: Text(
                          isIndexError
                              ? "This query needs a Firestore index.\n\nFix:\nCreate composite index for:\nclasses(lecturerId ASC, createdAt DESC)"
                              : "Error: $err",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _card(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Text(
                              "Loading classes...",
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // ✅ If you used Option B (no orderBy), sort locally:
                    // docs.sort((a, b) {
                    //   final ta = (a.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    //   final tb = (b.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    //   return tb.compareTo(ta);
                    // });

                    if (docs.isEmpty) {
                      return _card(
                        child: Text(
                          "No classes yet.\nTap 'Create Class' to add.",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Column(
                      children: List.generate(docs.length, (index) {
                        final doc = docs[index];
                        final data = doc.data();

                        final title = (data["name"] ?? "Untitled").toString();
                        final code = (data["courseCode"] ?? "—").toString();
                        final room = (data["room"] ?? "—").toString();
                        final semester = (data["semester"] ?? "—").toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AttendanceListScreen(
                                      classId: doc.id,
                                      className: title,
                                    ),
                                  ),
                                );
                              },
                              child: _classItem(
                                title: title,
                                subtitle: "$code • $room",
                                time: "Semester: $semester",
                                statusText: "Active",
                                statusColor: Colors.green,
                                icon: Icons.class_,
                                onDelete: () => _deleteClass(context, doc.id),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
            return;
          }
          if (i == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            return;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: "Reports"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }

  // ---------- UI widgets ----------
  Widget _topButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF1677FF) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _fakeChart() {
    final bars = [0.35, 0.55, 0.45, 0.65, 0.80];
    final labels = ["MON", "TUE", "WED", "THU", "FRI"];

    return Column(
      children: [
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(bars.length, (i) {
              final v = bars[i];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    height: 110 * v,
                    decoration: BoxDecoration(
                      color: i == bars.length - 1 ? const Color(0xFF1677FF) : Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _classItem({
    required String title,
    required String subtitle,
    required String time,
    required String statusText,
    required Color statusColor,
    required IconData icon,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                time,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.9)),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
