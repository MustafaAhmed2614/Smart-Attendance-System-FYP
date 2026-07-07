import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
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
  // ✨ FutureBuilder ki jagah manual state variables
  List<String> sessions = [];
  bool isLoading = true;
  final String backendUrl = AppConfig.backendUrl;

  @override
  void initState() {
    super.initState();
    fetchCourseSessions();
  }

  // ✨ Naya Fetch Logic
  Future<void> fetchCourseSessions() async {
    final url = Uri.parse(
      '$backendUrl/course-sessions/${Uri.encodeComponent(widget.courseName)}',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'Success') {
          setState(() {
            sessions = List<String>.from(data['sessions']);
            isLoading = false; // Data aane ke baad loading off
          });
          return;
        }
      }

      // Agar status success nahi hai
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      print('Error fetching sessions: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  String getFormattedDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      List<String> months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      List<String> weekdays = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
      ];

      String dayName = weekdays[dt.weekday - 1];
      String dayNum = dt.day.toString().padLeft(2, '0');
      String monthName = months[dt.month - 1];

      return "$dayName, $dayNum $monthName ${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  String getDay(String dateStr) {
    try {
      return DateTime.parse(dateStr).day.toString().padLeft(2, '0');
    } catch (e) {
      return "00";
    }
  }

  String getMonth(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      List<String> months = [
        "JAN",
        "FEB",
        "MAR",
        "APR",
        "MAY",
        "JUN",
        "JUL",
        "AUG",
        "SEP",
        "OCT",
        "NOV",
        "DEC",
      ];
      return months[dt.month - 1];
    } catch (e) {
      return "MTH";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.courseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header hamesha show hoga
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 25, top: 10),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  "Total Sessions Conducted",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  isLoading
                      ? "-"
                      : "${sessions.length}", // Loading ke waqt dash show karega
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ✨ Main List area
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : RefreshIndicator(
                    // ✨ Pull to Refresh lag gaya
                    onRefresh: fetchCourseSessions,
                    color: Colors.blueAccent,
                    child: sessions.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.15,
                              ),
                              Icon(
                                Icons.event_note,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No attendance records found.\nStart your first session today!\n(Pull down to refresh)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(15),
                            itemCount: sessions.length,
                            itemBuilder: (context, index) {
                              final date = sessions[index];
                              int sessionNumber = sessions.length - index;

                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(15),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CourseAttendanceScreen(
                                              courseName: widget.courseName,
                                              teacherUsername:
                                                  widget.teacherUsername,
                                              date: date,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                getMonth(date),
                                                style: const TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                getDay(date),
                                                style: const TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Session #$sessionNumber",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.blueAccent,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                getFormattedDate(date),
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          String todayDate = DateTime.now().toString().substring(0, 10);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseAttendanceScreen(
                courseName: widget.courseName,
                teacherUsername: widget.teacherUsername,
                date: todayDate,
              ),
            ),
          ).then((_) {
            // ✨ Screen wapas aane par automatically reload ho jayega
            setState(() {
              isLoading = true;
            });
            fetchCourseSessions();
          });
        },
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
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
