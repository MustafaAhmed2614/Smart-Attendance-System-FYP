import 'package:flutter/material.dart';
import 'package:fyp_app/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'login_screen.dart'; // Shuru mein 2 dots (..) aur ek slash

class StudentDashboard extends StatefulWidget {
  final String rollNumber; // Login ke waqt jo username/roll number dala tha
  StudentDashboard({required this.rollNumber});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final String backendUrl = AppConfig.backendUrl; // Apna IP check kar lein
  List<dynamic> myLogs = [];
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
          myLogs = data['logs'];
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
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              // 🚀 PRO TIP: pushAndRemoveUntil saari pichli screens ko delete kar deta hai.
              // Is se user mobile ka back button daba kar wapas andar nahi aa sakta.
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) =>
                    false, // Saari history false (clear) kar do
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, $studentName",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Roll Number: ${widget.rollNumber}",
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: myLogs.isEmpty
                        ? Center(child: Text("No attendance records found."))
                        : ListView.builder(
                            itemCount: myLogs.length,
                            itemBuilder: (context, index) {
                              var log = myLogs[index];
                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.event_available,
                                    color: Colors.green,
                                  ),
                                  title: Text("Status: ${log[0]}"), // Present
                                  subtitle: Text(
                                    "Date: ${log[1]}",
                                  ), // Timestamp
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
