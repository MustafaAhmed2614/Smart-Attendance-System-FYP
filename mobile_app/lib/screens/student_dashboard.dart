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
                      child: myLogs.isEmpty
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
                              itemCount: myLogs.length,
                              itemBuilder: (context, index) {
                                var log = myLogs[index];
                                String statusText = log[0].toString();

                                // 🚀 FIX: Ab yeh check karega ke status mein "Present" ka lafz majood hai ya nahi
                                bool isPresent = statusText.contains("Present");

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: isPresent
                                          ? Colors.green.shade200
                                          : Colors.red.shade200,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isPresent
                                          ? Colors.green[100]
                                          : Colors.red[100],
                                      child: Icon(
                                        isPresent ? Icons.check : Icons.close,
                                        color: isPresent
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                      ),
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
                                    subtitle: Text("Date: ${log[1]}"),
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
