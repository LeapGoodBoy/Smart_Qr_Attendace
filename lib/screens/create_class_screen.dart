import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_state.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _className = TextEditingController();
  final _courseCode = TextEditingController();
  final _room = TextEditingController();

  String? _semester;
  bool _saving = false;

  @override
  void dispose() {
    _className.dispose();
    _courseCode.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "";

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not logged in (FirebaseAuth). Please log in again.")),
      );
      return;
    }

    final name = _className.text.trim();
    final code = _courseCode.text.trim();
    final room = _room.text.trim();

    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill Class Name and Course Code")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection("classes").add({
        "name": name,
        "courseCode": code,
        "room": room.isEmpty ? "Not set" : room,
        "semester": _semester ?? "Not set",
        "lecturerId": uid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Class saved ✅")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save class: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // optional: lecturer-only
    if (AppState.role != UserRole.lecturer) {
      return const Scaffold(body: Center(child: Text("Lecturer only")));
    }

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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Fill in the details below to set up a new class.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _label("Class Name", required: true),
                      const SizedBox(height: 8),
                      _field(controller: _className, hint: "e.g., Mobile App Dev - Section A", icon: Icons.edit_outlined),

                      const SizedBox(height: 14),

                      _label("Subject / Course Code", required: true),
                      const SizedBox(height: 8),
                      _field(controller: _courseCode, hint: "e.g., CS304", icon: Icons.copy_all_outlined),

                      const SizedBox(height: 14),

                      _label("Semester", required: false),
                      const SizedBox(height: 8),
                      _dropdown(),

                      const SizedBox(height: 14),

                      _label("Room / Venue", required: false, optionalText: "(Optional)"),
                      const SizedBox(height: 8),
                      _field(controller: _room, hint: "e.g., Lab 3, Building B", icon: Icons.location_on_outlined),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              _bottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              "Create New Class",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              "Save",
              style: TextStyle(
                color: _saving ? Colors.white.withOpacity(0.35) : const Color(0xFF2D8CFF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {required bool required, String? optionalText}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text("*", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
        ],
        if (optionalText != null) ...[
          const SizedBox(width: 6),
          Text(optionalText, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
        ],
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: Icon(icon, color: Colors.white.withOpacity(0.45), size: 18),
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _semester,
          dropdownColor: const Color(0xFF081E2E),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.5)),
          hint: Text(
            "Select a semester",
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          ),
          items: const [
            DropdownMenuItem(value: "1", child: Text("Semester 1")),
            DropdownMenuItem(value: "2", child: Text("Semester 2")),
          ],
          onChanged: (v) => setState(() => _semester = v),
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _bottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.10),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1677FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Save Class", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    );
  }
}
