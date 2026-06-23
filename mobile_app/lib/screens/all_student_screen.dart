import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class AllStudentsScreen extends StatefulWidget {
  @override
  _AllStudentsScreenState createState() => _AllStudentsScreenState();
}

class _AllStudentsScreenState extends State<AllStudentsScreen> {
  final String backendUrl = AppConfig.backendUrl;
  List<dynamic> studentsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllStudentsData();
  }

  // Fetch data from the backend API
  Future<void> fetchAllStudentsData() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/admin/all-students-info/'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Success') {
          setState(() {
            studentsList = data['data'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching all students: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directory & Enrollments'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchAllStudentsData,
              color: Colors.blueAccent,
              child: studentsList.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        const Center(
                          child: Text(
                            "No students found in the database.\nPull down to refresh.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      itemCount: studentsList.length,
                      itemBuilder: (context, index) {
                        var student = studentsList[index];
                        List enrollments = student['enrollments'];

                        
                        String faceStatus = student['face_status'] ?? 'Pending';
                        // Determine color based on status
                        bool isPending = faceStatus.toLowerCase() == 'pending';

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent.withOpacity(
                                0.2,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.blueAccent,
                              ),
                            ),
                            title: Text(
                              student['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Roll No: ${student['roll_number']}"),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        isPending
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle,
                                        size: 16,
                                        color: isPending
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Face Data: $faceStatus",
                                        style: TextStyle(
                                          color: isPending
                                              ? Colors.orange
                                              : Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            
                            children: [
                              const Divider(),
                              enrollments.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(15.0),
                                      child: Text(
                                        "Not enrolled in any course yet.",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: enrollments.length,
                                      itemBuilder: (context, courseIndex) {
                                        var courseInfo =
                                            enrollments[courseIndex];
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.menu_book,
                                            color: Colors.green,
                                          ),
                                          title: Text(
                                            courseInfo['course_name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            "Teacher: ${courseInfo['teacher']}",
                                          ),
                                        );
                                      },
                                    ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
