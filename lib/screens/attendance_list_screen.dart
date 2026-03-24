import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceListScreen extends StatefulWidget {
  final String classId;
  final String className;

  const AttendanceListScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  String filter = "All"; // All / Present / Late / Absent

  String? selectedSessionId; // ✅ choose session

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsStream() {
    return FirebaseFirestore.instance
        .collection("sessions")
        .where("classId", isEqualTo: widget.classId)
        .orderBy("createdAt", descending: true)
        .limit(20)
        .snapshots();
  }

  String _statusText(String s) {
    if (s == "present") return "Present";
    if (s == "late") return "Late";
    if (s == "absent") return "Absent";
    return "Present";
  }

  Color _statusColor(String s) {
    if (s == "present") return Colors.greenAccent;
    if (s == "late") return Colors.orangeAccent;
    if (s == "absent") return Colors.redAccent;
    return Colors.greenAccent;
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
          child: Column(
            children: [
              _topBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sessionDropdown(),
                      const SizedBox(height: 12),

                      if (selectedSessionId == null)
                        _emptyNoSession()
                      else
                        _attendanceBlock(selectedSessionId!),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sessionsStream(),
      builder: (context, snap) {
        if (snap.hasError) return _card(child: _muted("Error loading sessions."));
        if (snap.connectionState == ConnectionState.waiting) return _card(child: _muted("Loading sessions..."));

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          selectedSessionId = null;
          return _emptyNoSession();
        }

        // auto-select first session
        selectedSessionId ??= docs.first.id;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSessionId,
              isExpanded: true,
              dropdownColor: const Color(0xFF0B2033),
              iconEnabledColor: Colors.white.withOpacity(0.7),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              items: docs.map((d) {
                final data = d.data();
                final createdAt = data["createdAt"];
                DateTime? dt;
                if (createdAt is Timestamp) dt = createdAt.toDate();

                final label = dt == null
                    ? "Session ${d.id.substring(0, 6)}"
                    : "Session • ${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
                      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

                return DropdownMenuItem(
                  value: d.id,
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (v) => setState(() => selectedSessionId = v),
            ),
          ),
        );
      },
    );
  }

  Widget _attendanceBlock(String sessionId) {
    final attendanceStream = FirebaseFirestore.instance
        .collection("sessions")
        .doc(sessionId)
        .collection("attendance")
        .orderBy("scannedAt", descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: attendanceStream,
      builder: (context, snap) {
        if (snap.hasError) return _card(child: _muted("Error loading attendance."));
        if (snap.connectionState == ConnectionState.waiting) return _card(child: _muted("Loading attendance..."));

        final docs = snap.data?.docs ?? [];

        int present = 0, late = 0, absent = 0;
        for (final d in docs) {
          final s = (d.data()["status"] ?? "present").toString();
          if (s == "present") present++;
          if (s == "late") late++;
          if (s == "absent") absent++;
        }

        // search + filter
        final q = searchCtrl.text.trim().toLowerCase();
        final filtered = docs.where((d) {
          final data = d.data();
          final name = (data["studentName"] ?? "").toString().toLowerCase();
          final sid = (data["studentId"] ?? "").toString().toLowerCase();
          final status = (data["status"] ?? "present").toString();

          final matchText = q.isEmpty || name.contains(q) || sid.contains(q);
          final matchStatus = filter == "All" || status == filter.toLowerCase();
          return matchText && matchStatus;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Selected Session",
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _statCard("Present", present, Colors.greenAccent)),
                const SizedBox(width: 10),
                Expanded(child: _statCard("Late", late, Colors.orangeAccent)),
                const SizedBox(width: 10),
                Expanded(child: _statCard("Absent", absent, Colors.redAccent)),
              ],
            ),

            const SizedBox(height: 14),
            _searchRow(),
            const SizedBox(height: 12),
            _filterChips(),
            const SizedBox(height: 12),

            if (docs.isEmpty)
              _emptyState()
            else
              Column(
                children: List.generate(filtered.length, (i) {
                  final doc = filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _studentTile(doc),
                  );
                }),
              ),
          ],
        );
      },
    );
  }

  // ================= UI PARTS =================

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.className,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      "Live Syncing",
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ],
                )
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Export (phase 2)")),
              );
            },
            icon: const Icon(Icons.upload_rounded),
            label: const Text("Export"),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2D8CFF),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, Color dotColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text("$value", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search student name or ID...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.55)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return Row(
      children: [
        _chip("All"),
        const SizedBox(width: 8),
        _chip("Present"),
        const SizedBox(width: 8),
        _chip("Late"),
        const SizedBox(width: 8),
        _chip("Absent"),
      ],
    );
  }

  Widget _chip(String text) {
    final selected = filter == text;
    return InkWell(
      onTap: () => setState(() => filter = text),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1677FF) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _studentTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data["studentName"] ?? "Unknown").toString();
    final studentId = (data["studentId"] ?? "—").toString();
    final status = (data["status"] ?? "present").toString();
    final scannedAt = data["scannedAt"];

    String timeStr = "--:--";
    if (scannedAt is Timestamp) {
      final dt = scannedAt.toDate();
      timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    final statusColor = _statusColor(status);

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
            radius: 22,
            backgroundColor: Colors.white.withOpacity(0.08),
            child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  "ID: $studentId • $timeStr",
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withOpacity(0.35)),
            ),
            child: Text(
              _statusText(status),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return _card(
      child: Column(
        children: [
          Icon(Icons.qr_code_2_rounded, color: Colors.white.withOpacity(0.7), size: 44),
          const SizedBox(height: 10),
          Text(
            "No students yet.\nThey will appear after scanning the QR.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700),
          )
        ],
      ),
    );
  }

  Widget _emptyNoSession() {
    return _card(
      child: Column(
        children: [
          Icon(Icons.event_busy, color: Colors.white.withOpacity(0.7), size: 44),
          const SizedBox(height: 10),
          Text(
            "No QR session found for this class.\nGenerate a QR code first.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700),
          )
        ],
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

  Widget _muted(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r"\s+"));
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
