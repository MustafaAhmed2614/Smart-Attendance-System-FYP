import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // Text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNoController =
      TextEditingController(); // Naya Roll No field

  // 3 alag alag angles ki tasveerein
  File? _frontImage;
  File? _leftImage;
  File? _rightImage;

  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  // Smart function jo angle ke hisaab se tasveer set karega
  Future<void> _captureFace(String angle) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        if (angle == 'front') {
          _frontImage = File(pickedFile.path);
        } else if (angle == 'left') {
          _leftImage = File(pickedFile.path);
        } else if (angle == 'right') {
          _rightImage = File(pickedFile.path);
        }
      });
    }
  }

  void _handleRegister() async {
    // 1. Text fields ki validation
    if (_nameController.text.isEmpty || _rollNoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name aur Roll Number dono zaroori hain!"),
        ),
      );
      return;
    }

    // 2. Tasveeron ki validation
    if (_frontImage == null || _leftImage == null || _rightImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Teeno angles ki photos (Front, Left, Right) zaroori hain!",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Yahan hum ApiService ko naya data bhej rahe hain
    bool success = await _apiService.registerStudent(
      name: _nameController.text,
      rollNo: _rollNoController.text, // Naya parameter
      frontImage: _frontImage!, // Naye parameters
      leftImage: _leftImage!,
      rightImage: _rightImage!,
    );

    setState(() => _isLoading = false);

    if (success) {
      _showDialog("Success ✅", "Student register ho gaya hai!");
      // Form saaf kar dein
      _nameController.clear();
      _rollNoController.clear();
      setState(() {
        _frontImage = null;
        _leftImage = null;
        _rightImage = null;
      });
    } else {
      _showDialog("Error ❌", "Registration nahi ho saki. Server check karein.");
    }
  }

  void _showDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Tasveer dikhane ka UI block
  Widget _buildImagePicker(String label, String angle, File? imgFile) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _captureFace(angle),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[200],
            backgroundImage: imgFile != null ? FileImage(imgFile) : null,
            child: imgFile == null
                ? const Icon(Icons.camera_alt, size: 30, color: Colors.grey)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Student Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _rollNoController,
              decoration: const InputDecoration(
                labelText: "Roll Number (e.g. SP23-CS-001)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            // Teeno tasveerein ek Row mein
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePicker("Front", "front", _frontImage),
                _buildImagePicker("Left", "left", _leftImage),
                _buildImagePicker("Right", "right", _rightImage),
              ],
            ),

            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleRegister,
                      icon: const Icon(Icons.upload),
                      label: const Text(
                        "Register & Train AI",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
