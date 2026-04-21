import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _takeAttendance() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      final response = await _apiService.markAttendance(File(pickedFile.path));
      setState(() => _isLoading = false);

      // Result dikhane ke liye popup
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(response.status),
          content: Text(response.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FYP Smart Attendance")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _takeAttendance,
                child: const Text("Mark Attendance"),
              ),
      ),
    );
  }
}
