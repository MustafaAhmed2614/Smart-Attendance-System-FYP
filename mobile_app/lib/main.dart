import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FYPApp());
}

class FYPApp extends StatelessWidget {
  const FYPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FYP Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AttendanceScreen(),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  File? _image;
  String _statusMessage = "Camera se picture click karein";
  bool _isLoading = false;

  // Camera se picture lene ka function
  Future<void> takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _statusMessage = "Picture le li gayi hai. Server par bhej rahe hain...";
      });
      // Picture lene ke fauran baad API ko bhej do
      uploadImageToServer(_image!);
    }
  }

  // API ko picture bhejne ka function
  Future<void> uploadImageToServer(File imageFile) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ⚠️ DHYAN DEIN: Yahan apne server ka IP address likhna hai!
      // Agar Android Emulator hai toh: 10.0.2.2
      // Agar iOS Simulator hai toh: 127.0.0.1
      String serverUrl = "http://192.168.0.198:8000/detect-attendance/";

      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var data = jsonDecode(responseData);

        setState(() {
          _statusMessage =
              "✅ Success!\nFaces: ${data['faces_detected']}\nEyes: ${data['eyes_detected']}";
        });
      } else {
        setState(() {
          _statusMessage = "❌ Server Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            "❌ Error: API se connect nahi ho paya.\nCheck karein ke server ON hai.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Attendance System')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Picture dikhane ki jagah
            _image == null
                ? const Icon(Icons.camera_alt, size: 100, color: Colors.grey)
                : Image.file(_image!, height: 300),

            const SizedBox(height: 20),

            // Server ka result dikhane ki jagah
            _isLoading
                ? const CircularProgressIndicator()
                : Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

            const SizedBox(height: 40),

            // Camera Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : takePicture,
              icon: const Icon(Icons.camera),
              label: const Text("Take Picture & Mark Attendance"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
