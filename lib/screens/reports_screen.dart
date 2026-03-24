import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String trendTab = "Month"; // Week / Month / Semester

  DateTime _startForTab(DateTime now) {
    if (trendTab == "Week") {
      return now.subtract(const Duration(days: 7));
    }
    if (trendTab == "Semester") {
      return now.subtract(const Duration(days: 120)); // simple semester window
    }
    // Month default
    return now.subtract(const Duration(days: 30));
  }

  Future<_ReportData> _loadReport() async {
    final now = DateTime.now();
    final start = _startForTab(now);

    // 1) Load sessions for this lecturer in date range
    // NOTE: You may need Firestore index for:
    // lecturerId == ... AND orderBy(createdAt)
    final sessionsSnap = await FirebaseFirestore.instance
        .collection("sessions")
        .where("lecturerId", isEqualTo: AppState.uid)
        .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy("createdAt", descending: true)
        .get();

    final sessions = sessionsSnap.docs;

    int sessionsCount = sessions.length;

    // 2) Load attendance subcollection for each session (Phase-1 client aggregation)
    int totalScans = 0;
    int presentScans = 0;

    // studentUid -> {presentCount, totalCount, name}
    final Map<String, _StudentAgg> studentAgg = {};

    // className -> {presentCount,totalCount}
    final Map<String, _ClassAgg> classAgg = {};

    for (final s in sessions) {
      final sData = s.data();
      final sessionId = s.id;

      final className = (sData["className"] ?? "Class").toString();

      final attSnap = await FirebaseFirestore.instance
          .collection("sessions")
          .doc(sessionId)
          .collection("attendance")
          .get();

      for (final a in attSnap.docs) {
        final d = a.data();
        totalScans++;

        final status = (d["status"] ?? "present").toString(); // present/late/absent
        final isPresent = status == "present";

        if (isPresent) presentScans++;

        // per-student
        final studentUid = (d["studentUid"] ?? d["studentId"] ?? a.id).toString();
        final studentName = (d["studentName"] ?? "Student").toString();

        studentAgg.putIfAbsent(studentUid, () => _StudentAgg(name: studentName));
        studentAgg[studentUid]!.total++;
        if (isPresent) studentAgg[studentUid]!.present++;

        // per-class
        classAgg.putIfAbsent(className, () => _ClassAgg());
        classAgg[className]!.total++;
        if (isPresent) classAgg[className]!.present++;
      }
    }

    final double avgAttendancePct =
        totalScans == 0 ? 0.0 : (presentScans / totalScans).toDouble();


    // At-risk (Phase-1):
    // We don't know absences unless you store a class roster.
    // So we treat "at risk" as lowest present ratio among students who scanned >= 3 times.
    final risky = studentAgg.entries
        .where((e) => e.value.total >= 3)
        .toList()
      ..sort((a, b) => a.value.ratio.compareTo(b.value.ratio));

    final atRiskTop3 = risky.take(3).toList();

    // subject performance (top 3 by ratio)
    final classPerf = classAgg.entries.toList()
      ..sort((a, b) => b.value.ratio.compareTo(a.value.ratio));
    final topClasses = classPerf.take(3).toList();

    return _ReportData(
      sessionsCount: sessionsCount,
      totalScans: totalScans,
      avgAttendancePct: avgAttendancePct,
      atRisk: atRiskTop3,
      topClasses: topClasses,
      rangeLabel: "${_fmtDate(start)} - ${_fmtDate(now)}",
    );
  }

  String _fmtDate(DateTime d) {
    return "${d.day}/${d.month}/${d.year}";
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
          child: FutureBuilder<_ReportData>(
            future: _loadReport(),
            builder: (context, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              final err = snap.hasError ? snap.error.toString() : null;
              final data = snap.data;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // top bar
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Analytics",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Share/Export")),
                            );
                          },
                          icon: Icon(Icons.ios_share, color: Colors.white.withOpacity(0.85)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        _dateChip(data?.rangeLabel ?? (loading ? "Loading..." : "No data")),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Export Report (Phase 2)")),
                            );
                          },
                          child: const Text("Export Report"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (err != null)
                      _errorCard(err)
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              icon: Icons.bar_chart_rounded,
                              iconBg: const Color(0xFF0B4EA2),
                              title: "Avg.\nAttendance",
                              big: loading ? "--" : "${((data!.avgAttendancePct) * 100).round()}%",
                              sub: "Based on scans",
                              subGood: null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricCard(
                              icon: Icons.layers_rounded,
                              iconBg: const Color(0xFF7C3AED),
                              title: "Classes\nHeld",
                              big: loading ? "--" : "${data!.sessionsCount}",
                              sub: "Total sessions",
                              subGood: null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricCard(
                              icon: Icons.warning_rounded,
                              iconBg: const Color(0xFFEF4444),
                              title: "At Risk",
                              big: loading ? "--" : "${data!.atRisk.length}",
                              sub: "Low ratio",
                              subGood: null,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 18),

                    Text(
                      "Attendance Trends",
                      style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    _segmentedTabs(),

                    const SizedBox(height: 10),

                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Center(
                        child: Text(
                          "Chart ($trendTab) — Phase 2 (use real chart lib later)",
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      "Subject Performance",
                      style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 10),

                    if (loading)
                      _boxText("Loading performance...")
                    else if (data == null || data.topClasses.isEmpty)
                      _boxText("No attendance data yet.")
                    else
                      ...data.topClasses.map((e) {
                        final pct = e.value.ratio; // 0..1
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _subjectRow(
                            e.key,
                            pct,
                            const Color(0xFF2D8CFF),
                          ),
                        );
                      }),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        const Text(
                          "At-Risk Students",
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (loading)
                      _boxText("Loading at-risk...")
                    else if (data == null || data.atRisk.isEmpty)
                      _boxText("No at-risk students (need more data).")
                    else
                      ...data.atRisk.map((e) {
                        final s = e.value;
                        final pct = (s.ratio * 100).round();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _riskStudent(
                            s.name,
                            "Scans: ${s.total} • Present: ${s.present}",
                            "$pct%",
                            Colors.redAccent,
                          ),
                        );
                      }),

                    const SizedBox(height: 90),
                  ],
                ),
              );
            },
          ),
        ),
      ),

      bottomNavigationBar: _downloadBar(context),
    );
  }

  Widget _dateChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded, color: Colors.white.withOpacity(0.75), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Text(
        "Report error: $text\n\nTip: Firestore may require an index for sessions query.",
        style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String big,
    required String sub,
    required bool? subGood,
  }) {
    Color subColor = Colors.white.withOpacity(0.55);
    if (subGood == true) subColor = Colors.greenAccent.withOpacity(0.9);
    if (subGood == false) subColor = Colors.redAccent.withOpacity(0.9);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconBg, size: 18),
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 10),
          Text(big, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: subColor, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _segmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(child: _tab("Week")),
          const SizedBox(width: 6),
          Expanded(child: _tab("Month")),
          const SizedBox(width: 6),
          Expanded(child: _tab("Semester")),
        ],
      ),
    );
  }

  Widget _tab(String text) {
    final selected = trendTab == text;
    return InkWell(
      onTap: () => setState(() => trendTab = text),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withOpacity(0.55),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _subjectRow(String title, double pct, Color barColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${(pct * 100).round()}% Present (based on scans)",
                  style: TextStyle(color: barColor.withOpacity(0.95), fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _riskStudent(String name, String sub, String pct, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.08),
            child: Text(
              name.trim().split(" ").take(2).map((e) => e[0]).join(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w700, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeColor.withOpacity(0.35)),
            ),
            child: Text(
              pct,
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boxText(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _downloadBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF061A2A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Download CSV Report (Phase 2)")),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text("Download CSV Report"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1677FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportData {
  final int sessionsCount;
  final int totalScans;
  final double avgAttendancePct;
  final List<MapEntry<String, _StudentAgg>> atRisk;
  final List<MapEntry<String, _ClassAgg>> topClasses;
  final String rangeLabel;

  _ReportData({
    required this.sessionsCount,
    required this.totalScans,
    required this.avgAttendancePct,
    required this.atRisk,
    required this.topClasses,
    required this.rangeLabel,
  });
}

class _StudentAgg {
  final String name;
  int present = 0;
  int total = 0;

  _StudentAgg({required this.name});

  double get ratio => total == 0 ? 0 : present / total;
}

class _ClassAgg {
  int present = 0;
  int total = 0;

  double get ratio => total == 0 ? 0 : present / total;
}
