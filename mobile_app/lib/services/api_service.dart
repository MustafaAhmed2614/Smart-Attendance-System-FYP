import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Timeout ke liye zaroori hai
import 'package:http/http.dart' as http;
import '../models/attendance_model.dart';

class ApiService {
  // Demo se pehle terminal mein 'ipconfig getifaddr en0' karke IP check lazmi karein
  final String baseUrl = "http://192.168.0.198:8000";

  // Attendance Mark karne ka function (Optimized for RetinaFace)
  // markAttendance function ko update karein

  Future<AttendanceResponse> markAttendance(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect-attendance/'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // ⏳ Timeout ko 2 minutes (120 seconds) kar diya hai
      // Kyunke Facenet512 aur RetinaFace heavy scanning karte hain
      var streamedResponse = await request.send().timeout(
        const Duration(minutes: 2), // 👈 60 seconds se barha kar 2 minutes
      );

      var responseData = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        return AttendanceResponse.fromJson(jsonDecode(responseData));
      } else {
        var errorData = jsonDecode(responseData);
        throw Exception(errorData['message'] ?? "Server Error");
      }
    } on TimeoutException {
      // 📢 User ke liye behtar error message
      throw Exception(
        "Scan mein boht waqt lag raha hai. Aapka server heavy processing kar raha hai, thori dair baad dobara koshish karein.",
      );
    } on SocketException {
      throw Exception(
        "Connection Error: Server se rabta nahi ho raha. IP check karein.",
      );
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  // Naya Student Register karne ka function
  Future<bool> registerStudent(String name, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/register-student/'),
      );

      request.fields['name'] = name;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Registration fast hoti hai isliye 30s kaafi hain
      var response = await request.send().timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      print("Registration Error: $e");
      return false;
    }
  }
}
