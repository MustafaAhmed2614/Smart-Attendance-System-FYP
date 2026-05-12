import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'login_screen.dart';

class StudentDashboard extends StatefulWidget {
  final String studentName;
  final String rollNumber;

  StudentDashboard({required this.studentName, required this.rollNumber});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final String backendUrl = AppConfig.backendUrl;

  // 🚀 NAYA VARIABLE: Grouped data store karne ke liye
  List<dynamic> attendanceData = [];
  String studentName = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyAttendance();
  }

  Future<void> fetchMyAttendance() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/my-attendance/${widget.rollNumber}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          studentName = data['student_name'];
          attendanceData = data['attendance_data']; // 🚀 Update kiya gaya
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, $studentName",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Roll Number: ${widget.rollNumber}",
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: fetchMyAttendance,
                      color: Colors.blueAccent,
                      child: attendanceData.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.3,
                                ),
                                const Center(
                                  child: Text(
                                    "No attendance records found.\nPull down to refresh.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: attendanceData.length,
                              itemBuilder: (context, index) {
                                var courseData = attendanceData[index];
                                String courseName = courseData['course_name'];
                                List records = courseData['records'];

                                // 🚀 NAYA DESIGN: Course ka Dropdown (Accordion)
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ExpansionTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.blueAccent,
                                      child: Icon(
                                        Icons.menu_book,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      courseName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${records.length} Classes Recorded",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),

                                    // 🚀 Is course ke andar mojood saari dates
                                    children: records.map<Widget>((record) {
                                      String statusText = record['status']
                                          .toString();
                                      bool isPresent = statusText.contains(
                                        "Present",
                                      );

                                      return Container(
                                        color: Colors
                                            .grey[50], // Andar wali list ka halka background
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 25,
                                              ),
                                          leading: Icon(
                                            isPresent
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: isPresent
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          title: Text(
                                            "Status: $statusText",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isPresent
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                          subtitle: Text(
                                            "Date: ${record['date']}",
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
