import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_model.dart';

class ApiService {
  // Apne Mac ka current IP yahan likhein
  final String baseUrl = "http://192.168.0.198:8000";

  // Attendance Mark karne ka function
  Future<AttendanceResponse> markAttendance(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/detect-attendance/'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    return AttendanceResponse.fromJson(jsonDecode(responseData));
  }

  // Naya Student Register karne ka function
  Future<bool> registerStudent(String name, File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/register-student/'),
    );
    request.fields['name'] = name;
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    var response = await request.send();
    return response.statusCode == 200;
  }
}
