import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_state.dart';

class GenerateQrScreen extends StatefulWidget {
  const GenerateQrScreen({super.key});

  @override
  State<GenerateQrScreen> createState() => _GenerateQrScreenState();
}

class _GenerateQrScreenState extends State<GenerateQrScreen> {
  String? selectedClassId;
  String selectedClassName = "";
  String selectedCourseCode = "";
  String selectedRoom = "";
  int selectedDurationSec = 45;

  bool live = false;
  String sessionId = "";
  Timer? _timer;
  int remainingSec = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> _myClassesStream(String uid) {
    return FirebaseFirestore.instance
        .collection("classes")
        .where("lecturerId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (AppState.role != UserRole.lecturer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Only lecturers can access this page")),
        );
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "";
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not logged in (FirebaseAuth).")),
      );
      return;
    }

    if (selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a class")),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final expiresAt = now.add(Duration(seconds: selectedDurationSec));

      final docRef = await FirebaseFirestore.instance.collection("sessions").add({
        "classId": selectedClassId,
        "className": selectedClassName,
        "classCode": selectedCourseCode,
        "room": selectedRoom,
        "lecturerId": uid,
        "createdAt": FieldValue.serverTimestamp(),
        "expiresAt": Timestamp.fromDate(expiresAt),
        "active": true,
        "durationSec": selectedDurationSec,
      });

      sessionId = docRef.id;

      setState(() {
        live = true;
        remainingSec = selectedDurationSec;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) return;
        if (remainingSec <= 1) {
          t.cancel();
          await _endSession(auto: true);
          return;
        }
        setState(() => remainingSec--);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create session: $e")),
      );
    }
  }

  Future<void> _endSession({bool auto = false}) async {
    _timer?.cancel();

    if (sessionId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection("sessions").doc(sessionId).update({
          "active": false,
          "endedAt": FieldValue.serverTimestamp(),
          "endedBy": auto ? "auto" : "lecturer",
        });
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      live = false;
      remainingSec = 0;
    });
  }

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        "Start Session",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),

                _label("Select Class"),
                const SizedBox(height: 8),
                if (uid.isEmpty)
                  _boxText("Not logged in.")
                else
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _myClassesStream(uid),
                    builder: (context, snap) {
                      if (snap.hasError) return _boxText("Error loading classes");
                      if (snap.connectionState == ConnectionState.waiting) return _boxText("Loading classes...");

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) return _boxText("No classes yet. Create a class first.");

                      // auto select
                      if (selectedClassId == null) {
                        final first = docs.first;
                        final data = first.data();
                        selectedClassId = first.id;
                        selectedClassName = (data["name"] ?? "Class").toString();
                        selectedCourseCode = (data["courseCode"] ?? "").toString();
                        selectedRoom = (data["room"] ?? "").toString();
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedClassId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0B2033),
                            iconEnabledColor: Colors.white.withOpacity(0.7),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            items: docs.map((d) {
                              final data = d.data();
                              final name = (data["name"] ?? "Class").toString();
                              final code = (data["courseCode"] ?? "").toString();
                              final room = (data["room"] ?? "").toString();
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text("$name  •  $code  •  $room"),
                              );
                            }).toList(),
                            onChanged: live
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    final found = docs.firstWhere((x) => x.id == v);
                                    final data = found.data();
                                    setState(() {
                                      selectedClassId = v;
                                      selectedClassName = (data["name"] ?? "Class").toString();
                                      selectedCourseCode = (data["courseCode"] ?? "").toString();
                                      selectedRoom = (data["room"] ?? "").toString();
                                    });
                                  },
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 14),
                _label("Session Duration"),
                const SizedBox(height: 8),
                _durationRow(),

                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: live ? null : _startSession,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text("Generate QR Code", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1677FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1677FF).withOpacity(0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                if (sessionId.isNotEmpty) _liveSessionCard(),
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
      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w700),
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

  Widget _durationRow() {
    Widget pill(String label, int sec) {
      final selected = selectedDurationSec == sec;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: live ? null : () => setState(() => selectedDurationSec = sec),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0B4EA2) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.55),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          pill("30s", 30),
          const SizedBox(width: 6),
          pill("45s", 45),
          const SizedBox(width: 6),
          pill("60s", 60),
        ],
      ),
    );
  }

  Widget _liveSessionCard() {
    final total = selectedDurationSec <= 0 ? 1 : selectedDurationSec;
    final progress = (remainingSec / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: live ? const Color(0xFF13D38E).withOpacity(0.15) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: live ? const Color(0xFF13D38E).withOpacity(0.35) : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: live ? const Color(0xFF13D38E) : Colors.white.withOpacity(0.35)),
                const SizedBox(width: 6),
                Text(
                  live ? "LIVE SESSION" : "SESSION ENDED",
                  style: TextStyle(
                    color: live ? const Color(0xFF13D38E) : Colors.white.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Text(
            selectedClassName.isEmpty ? "Class" : selectedClassName,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text("Scan to mark your attendance", style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(
              data: sessionId, // QR contains ONLY sessionId
              size: 180,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        live ? const Color(0xFF1677FF) : Colors.white24,
                      ),
                    ),
                    Text("${remainingSec}s", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Remaining", style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text("Time Left", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: live ? () => _endSession(auto: false) : null,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text("Stop"),
                style: TextButton.styleFrom(
                  foregroundColor: live ? const Color(0xFFFF5A5A) : Colors.white24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
