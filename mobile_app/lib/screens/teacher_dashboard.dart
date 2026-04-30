import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart'; // Shuru mein 2 dots (..) aur ek slash

class TeacherDashboard extends StatefulWidget {
  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  // Yahan apna IP address lagayen jo aap api ke liye use kar rahe hain
  final String backendUrl = AppConfig.backendUrl;

  List<dynamic> attendanceLogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  // 1. Backend se List mangwane ka function
  Future<void> fetchAttendance() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/view-attendance/'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Hamari API {"logs": [...]} bhej rahi hai
          attendanceLogs = data['logs'];
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // 2. Excel Download karne ka function
  Future<void> downloadExcelReport() async {
    final Uri excelUrl = Uri.parse('$backendUrl/export-attendance/');
    if (await canLaunchUrl(excelUrl)) {
      await launchUrl(excelUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download file. Check server connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Dashboard'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchAttendance();
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : attendanceLogs.isEmpty
          ? Center(child: Text("No attendance marked yet."))
          : ListView.builder(
              itemCount: attendanceLogs.length,
              itemBuilder: (context, index) {
                // API Format: [id, name, status, timestamp]
                var log = attendanceLogs[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.check, color: Colors.white),
                    ),
                    title: Text(
                      log[1],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ), // Name
                    subtitle: Text("Time: ${log[3]}"), // Timestamp
                    trailing: Text(
                      log[2], // Status (Present)
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: downloadExcelReport,
        icon: Icon(Icons.download),
        label: Text("Export Excel"),
        backgroundColor: Colors.green,
      ),
    );
  }
}
