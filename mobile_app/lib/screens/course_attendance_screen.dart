import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart'; // Apni constants file ka path zaroor check kar lijiye ga

class CourseAttendanceScreen extends StatefulWidget {
  final String courseName;
  final String teacherUsername;

  CourseAttendanceScreen({required this.courseName, required this.teacherUsername});

  @override
  _CourseAttendanceScreenState createState() => _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<CourseAttendanceScreen> {
  final String backendUrl = AppConfig.backendUrl; 
  List<dynamic> pendingStudents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPendingStudents(); // Screen khulte hi pending bache mangwao
  }

  // 🚀 Backend se Pending Students ki API call
  Future<void> fetchPendingStudents() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/pending-students/${widget.courseName}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Success') {
          setState(() {
            pendingStudents = data['pending_students'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching pending students: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController humein asani se 2 tabs banane deta hai
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.courseName),
          backgroundColor: Colors.blueAccent,
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.how_to_reg), text: "Take Attendance"),
              Tab(icon: Icon(Icons.person_add_alt_1), text: "Pending Faces"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ==========================================
            // TAB 1: DAILY ATTENDANCE (Camera Wala)
            // ==========================================
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_alt, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 20),
                  Text(
                    "Mark today's attendance for\n${widget.courseName}",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Yahan hum baad mein camera open karne ka code lagayenge
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Camera opening soon...")),
                      );
                    },
                    icon: Icon(Icons.camera_alt),
                    label: Text("Start Face Recognition", style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      backgroundColor: Colors.blueAccent,
                    ),
                  )
                ],
              ),
            ),

            // ==========================================
            // TAB 2: PENDING REGISTRATIONS (Admin Flow)
            // ==========================================
            isLoading
                ? Center(child: CircularProgressIndicator())
                : pendingStudents.isEmpty
                    ? Center(
                        child: Text(
                          "No pending registrations! 🎉",
                          style: TextStyle(fontSize: 18, color: Colors.green),
                        ),
                      )
                    : ListView.builder(
                        itemCount: pendingStudents.length,
                        itemBuilder: (context, index) {
                          var student = pendingStudents[index];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                child: Icon(Icons.warning_amber_rounded, color: Colors.white),
                              ),
                              title: Text(student['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Roll No: ${student['roll_number']}"),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Yahan hum student ki picture lene ka code lagayenge
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Scanning face for ${student['name']}...")),
                                  );
                                },
                                child: Text("Scan Face"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}