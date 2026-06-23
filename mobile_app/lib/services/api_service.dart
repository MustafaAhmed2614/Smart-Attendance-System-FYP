import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Timeout ke liye zaroori hai
import 'package:http/http.dart' as http;
import '../models/attendance_model.dart';

class ApiService {
  final String baseUrl = "http://192.168.0.199:8000";

  Future<AttendanceResponse> markAttendance(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect-attendance/'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
      );

      var responseData = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        return AttendanceResponse.fromJson(jsonDecode(responseData));
      } else {
        var errorData = jsonDecode(responseData);
        throw Exception(errorData['message'] ?? "Server Error");
      }
    } on TimeoutException {
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

  Future<bool> registerStudent({
    required String name,
    required String rollNo,
    required File frontImage,
    required File leftImage,
    required File rightImage,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/register');
      var request = http.MultipartRequest('POST', uri);

      // 1. Text Data add karein
      request.fields['name'] = name;
      request.fields['roll_number'] = rollNo;

      request.files.add(
        await http.MultipartFile.fromPath('front_image', frontImage.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('left_image', leftImage.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('right_image', rightImage.path),
      );
      var response = await request.send();

      if (response.statusCode == 200) {
        print("Registration Successful!");
        return true;
      } else {
        print("Registration Failed with status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error calling API: $e");
      return false;
    }
  }
}
