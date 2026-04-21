import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'registration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  // Attendance lene ka main function
  void _takeAttendance() async {
    final picker = ImagePicker();

    // Camera se photo lena
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality:
          50, // Size chota rakhne ke liye taake backend jaldi process kare
    );

    if (pickedFile != null) {
      setState(() => _isLoading = true);

      try {
        // API ko photo bhejna
        final response = await _apiService.markAttendance(
          File(pickedFile.path),
        );

        if (!mounted) return;

        // Kamyabi ka message dikhana
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              response.status == "Success" ? "Success ✅" : "Notice ℹ️",
            ),
            content: Text(response.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } catch (e) {
        // Agar koi error aaye (Timeout, IP change, etc.)
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error ❌"),
            content: Text(e.toString().replaceAll("Exception:", "")),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } finally {
        // Yeh block har haal mein chalega, chahe success ho ya error
        // Is se loader ruk jayega
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("FYP Smart Attendance"),
        centerTitle: true,
        elevation: 2,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.face_retouching_natural,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            const Text(
              "Smart Attendance System",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Capture your photo to mark attendance",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 50),

            // Agar loading ho rahi ho toh indicator dikhayein warna button
            _isLoading
                ? Column(
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 15),
                      Text("AI is processing... Please wait"),
                    ],
                  )
                : SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _takeAttendance,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Mark Attendance"),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 15),
            // Mark Attendance button ke niche ye add karein:
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegistrationScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text("Go to Registration"),
            ),
          ],
        ),
      ),
    );
  }
}
