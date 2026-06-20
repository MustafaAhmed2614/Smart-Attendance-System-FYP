import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart'; // 🚀 YEH IMPORT LAZMI HAI
import 'course_attendance_screen.dart';

class CourseSessionsScreen extends StatefulWidget {
  final String courseName;
  final String teacherUsername;

  const CourseSessionsScreen({
    Key? key,
    required this.courseName,
    required this.teacherUsername,
  }) : super(key: key);

  @override
  _CourseSessionsScreenState createState() => _CourseSessionsScreenState();
}

class _CourseSessionsScreenState extends State<CourseSessionsScreen> {
  late Future<List<String>> _sessionsFuture;
  final String backendUrl = AppConfig.backendUrl; // 🚀 CENTRALIZED URL

  @override
  void initState() {
    super.initState();
    _sessionsFuture = fetchCourseSessions(widget.courseName);
  }

  // Backend se Dates mangwane ka function
  Future<List<String>> fetchCourseSessions(String courseName) async {
    // 🚀 Ab hardcoded IP ke bajaye dynamic URL use hoga
    final url = Uri.parse(
      '$backendUrl/course-sessions/${Uri.encodeComponent(courseName)}',
    );
    try {
      print("Calling API: $url"); // Terminal mein print hoga
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10)); // 10 sec timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'Success') {
          return List<String>.from(data['sessions']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching sessions: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('${widget.courseName} - Sessions'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: FutureBuilder<List<String>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          // Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }
          // Error State
          else if (snapshot.hasError) {
            return const Center(
              child: Text('Error loading dates! Check backend connection.'),
            );
          }
          // Empty State (Koi attendance nahi hui ab tak)
          else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No attendance records found.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Success State - Dates ki List Dikhana
          final sessions = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final date = sessions[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: Colors.blueAccent,
                  ),
                  title: Text(
                    date, // E.g., "2026-06-18"
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseAttendanceScreen(
                          courseName: widget.courseName,
                          teacherUsername: widget.teacherUsername,
                          date: date,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 1. System se Aaj ki date nikalna (Format: YYYY-MM-DD)
          String todayDate = DateTime.now().toString().substring(0, 10);

          // 2. Teacher ko Attendance wali screen par bhejna (Aaj ki date ke sath)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseAttendanceScreen(
                courseName: widget.courseName,
                teacherUsername: widget.teacherUsername,
                date: todayDate, // Aaj ki date paas kar di
              ),
            ),
          ).then((_) {
            // 3. Jab teacher attendance laga kar wapis back aaye, toh list refresh ho jaye
            setState(() {
              _sessionsFuture = fetchCourseSessions(widget.courseName);
            });
          });
        },
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text(
          "Take Attendance",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
    );
  }
}
