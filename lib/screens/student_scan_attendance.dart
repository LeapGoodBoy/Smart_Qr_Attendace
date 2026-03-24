import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_state.dart';

class StudentScanAttendanceScreen extends StatefulWidget {
  const StudentScanAttendanceScreen({super.key});

  @override
  State<StudentScanAttendanceScreen> createState() => _StudentScanAttendanceScreenState();
}

class _StudentScanAttendanceScreenState extends State<StudentScanAttendanceScreen> {
  // ✅ QR only
  final MobileScannerController _scannerCtrl = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _isProcessing = false;
  bool _flashOn = false;
  bool _frontCamera = false;

  // ✅ Set this to your real campus SSID
  static const String campusSsid = "CAMPUS_WIFI";

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// ✅ Android 10+ often needs Location permission + Location ON to read SSID
  Future<void> _ensureWifiSsidPermissions() async {
    if (!Platform.isAndroid) return;

    // Request location permission (needed for Wi-Fi SSID)
    final loc = await Permission.locationWhenInUse.request();
    if (!loc.isGranted) {
      throw Exception("Location permission is required to read Wi-Fi name (SSID).");
    }
  }

  Future<String> _readWifiName() async {
    final ssid = await NetworkInfo().getWifiName();
    final clean = (ssid ?? "").replaceAll('"', '').trim();
    return clean;
  }

  Future<void> _toggleFlash() async {
    await _scannerCtrl.toggleTorch();
    setState(() => _flashOn = !_flashOn);
  }

  Future<void> _switchCamera() async {
    await _scannerCtrl.switchCamera();
    setState(() => _frontCamera = !_frontCamera);
  }

  Future<void> _handleQr(String sessionId) async {
    // ✅ stop double triggers
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // ✅ pause camera while writing
    await _scannerCtrl.stop();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? "";
      if (uid.isEmpty) throw Exception("You are not logged in.");

      // ✅ Wi-Fi SSID check
      await _ensureWifiSsidPermissions();
      final cleanSsid = await _readWifiName();

      if (cleanSsid.isEmpty) {
        throw Exception(
          "Wi-Fi name not detected.\n\n"
          "• Turn ON Location\n"
          "• Connect to campus Wi-Fi\n"
          "• Then try again",
        );
      }

      if (cleanSsid != campusSsid) {
        throw Exception("Connect to campus Wi-Fi ($campusSsid).\nCurrent: $cleanSsid");
      }

      // ✅ Load session
      final sessionRef = FirebaseFirestore.instance.collection("sessions").doc(sessionId);
      final sessionDoc = await sessionRef.get();
      final data = sessionDoc.data();
      if (data == null) throw Exception("Invalid QR (session not found).");

      final active = (data["active"] == true);
      if (!active) throw Exception("This session is no longer active.");

      final expiresAt = data["expiresAt"];
      if (expiresAt is Timestamp) {
        if (DateTime.now().isAfter(expiresAt.toDate())) {
          throw Exception("This session has expired.");
        }
      } else {
        throw Exception("Session missing expiresAt.");
      }

      // ✅ Try to read class info (safe)
      final className = (data["className"] ?? "Class").toString();

      // If you don't store classCode in sessions, this will be empty. That's OK.
      final classCode = (data["classCode"] ?? "").toString();

      // ✅ 1) Write attendance (one per student)
      await sessionRef.collection("attendance").doc(uid).set({
        "studentUid": uid,
        "studentId": uid,
        "studentName": AppState.fullName.isEmpty ? "Student" : AppState.fullName,
        "status": "present",
        "scannedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ 2) Write history for student dashboard
      await FirebaseFirestore.instance.collection("users").doc(uid).collection("history").add({
        "sessionId": sessionId,
        "classTitle": className,
        "classCode": classCode,
        "status": "present",
        "scannedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attendance marked ✅")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );

      // ✅ allow scan again
      setState(() => _isProcessing = false);
      await _scannerCtrl.start();
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        "Scan Attendance",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  "Connect to campus Wi-Fi ($campusSsid) then scan the QR.",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600, fontSize: 12),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Stack(
                      children: [
                        FutureBuilder<bool>(
                          future: _ensureCameraPermission(),
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return Center(child: CircularProgressIndicator(color: Colors.white.withOpacity(0.7)));
                            }
                            if (snap.data != true) {
                              return Center(
                                child: Text(
                                  "Camera permission denied",
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700),
                                ),
                              );
                            }

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: MobileScanner(
                                controller: _scannerCtrl,
                                onDetect: (capture) {
                                  if (_isProcessing) return;

                                  final barcodes = capture.barcodes;
                                  if (barcodes.isEmpty) return;

                                  final raw = barcodes.first.rawValue;
                                  if (raw == null || raw.trim().isEmpty) return;

                                  _handleQr(raw.trim()); // QR = sessionId
                                },
                              ),
                            );
                          },
                        ),

                        Align(
                          alignment: Alignment.center,
                          child: IgnorePointer(
                            child: Container(
                              width: 260,
                              height: 260,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF2D8CFF).withOpacity(0.8), width: 2),
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.white.withOpacity(0.75), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isProcessing ? "Processing..." : "Make sure the QR is clear and inside the frame.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _toggleFlash,
                        icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
                        label: const Text("Flash"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.18)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _switchCamera,
                        icon: Icon(_frontCamera ? Icons.camera_front : Icons.camera_rear),
                        label: const Text("Switch"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.18)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
