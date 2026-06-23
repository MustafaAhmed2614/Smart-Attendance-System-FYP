import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'login_screen.dart';
import 'all_student_screen.dart';
import 'course_session_screen.dart';

class TeacherDashboard extends StatefulWidget {
  final String teacherUsername;

  TeacherDashboard({required this.teacherUsername});

  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final String backendUrl = AppConfig.backendUrl;
  List<dynamic> courses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCourses();
  }

  Future<void> fetchCourses() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/my-courses/${widget.teacherUsername}'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Success') {
          setState(() {
            courses = data['courses'];
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      print("Error fetching courses: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> addCourse(String courseName) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/add-course/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "course_name": courseName,
          "teacher_username": widget.teacherUsername,
        }),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (data['status'] == 'Success') {
        await fetchCourses();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Error adding course: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void showAddCourseDialog() {
    TextEditingController courseController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Create New Course"),
        content: TextField(
          controller: courseController,
          decoration: InputDecoration(hintText: "e.g. Software Engineering"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (courseController.text.isNotEmpty) {
                Navigator.pop(context);
                addCourse(courseController.text.trim());
              }
            },
            child: Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Courses'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.people_alt, color: Colors.white),
            tooltip: 'All Students Directory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AllStudentsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
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
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchCourses,
              color: Colors.blueAccent,
              child: courses.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Text(
                            "No courses found. Create one!\nPull down to refresh.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(15),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        String courseName = courses[index];
                        return GestureDetector(
                          onTap: () {
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CourseSessionsScreen(
                                  courseName: courseName,
                                  teacherUsername: widget.teacherUsername,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 5,
                            color: Colors.blueAccent.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  courseName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddCourseDialog,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text("Add Course", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
