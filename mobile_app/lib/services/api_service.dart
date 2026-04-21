import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_model.dart';

class ApiService {
  // IP Address check karlein ke yahi hai ya change hui hai
  final String baseUrl = "http://192.168.0.198:8000";

  // Attendance Mark karne ka function
  Future<AttendanceResponse> markAttendance(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect-attendance/'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Timeout ko 60 seconds kar diya hai kyunke DeepFace processing mein time leta hai
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );

      var responseData = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        return AttendanceResponse.fromJson(jsonDecode(responseData));
      } else {
        throw Exception("Server Error: ${streamedResponse.statusCode}");
      }
    } on SocketException {
      throw Exception("Server tak pohnchna mumkin nahi. IP check karein.");
    } catch (e) {
      throw Exception("Attendance mark karne mein masla hua: $e");
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

      var response = await request.send().timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      print("Registration Error: $e");
      return false;
    }
  }
}
