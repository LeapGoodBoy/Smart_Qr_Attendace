import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({super.key});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  String filter = "All"; // All / Present / Late / Absent

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  bool _matchFilter(String status) {
    if (filter == "All") return true;
    return status.toLowerCase() == filter.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

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
                child: uid.isEmpty
                    ? _empty("Not logged in.")
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection("users")
                            .doc(uid)
                            .collection("history")
                            .orderBy("scannedAt", descending: true)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return _empty("Error: ${snap.error}");
                          }

                          final docs = snap.data?.docs ?? [];
                          final q = searchCtrl.text.trim().toLowerCase();

                          final filtered = docs.where((d) {
                            final data = d.data();
                            final title = (data["classTitle"] ?? "").toString().toLowerCase();
                            final code = (data["classCode"] ?? "").toString().toLowerCase();
                            final status = (data["status"] ?? "present").toString();
                            final matchText = q.isEmpty || title.contains(q) || code.contains(q);
                            return matchText && _matchFilter(status);
                          }).toList();

                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _searchRow(),
                                const SizedBox(height: 12),
                                _filterChips(),
                                const SizedBox(height: 12),

                                if (filtered.isEmpty)
                                  _empty("No history yet.")
                                else
                                  ...filtered.map((doc) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _historyCard(doc.data()),
                                      )),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              "History",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          TextButton(onPressed: () {}, child: const Text("Export")),
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
          hintText: "Search class...",
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

  Widget _historyCard(Map<String, dynamic> data) {
    final title = (data["classTitle"] ?? "Class").toString();
    final code = (data["classCode"] ?? "").toString();
    final status = (data["status"] ?? "present").toString();

    final ts = data["scannedAt"];
    final dt = ts is Timestamp ? ts.toDate() : null;

    final statusColor = status.toLowerCase() == "present"
        ? Colors.greenAccent
        : status.toLowerCase() == "late"
            ? Colors.orangeAccent
            : Colors.redAccent;

    final timeStr = dt == null ? "--" : "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.school_rounded, color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$code • $title",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 6),
                Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w700, fontSize: 11)),
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
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
