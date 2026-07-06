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
  bool isLoading = true; // ✨ Initial load ke liye

  @override
  void initState() {
    super.initState();
    fetchCourses();
  }

  Future<void> fetchCourses() async {
    // RefreshIndicator ke waqt hum 'isLoading' true nahi karenge taake screen na bhare
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
      if (mounted) setState(() => isLoading = false);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "Create New Course",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: courseController,
          decoration: InputDecoration(
            hintText: "e.g. Software Engineering",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (courseController.text.isNotEmpty) {
                Navigator.pop(context);
                addCourse(courseController.text.trim());
              }
            },
            child: Text("Create", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                count,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.people_alt),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AllStudentsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
              (route) => false,
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 30),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome back,",
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        widget.teacherUsername.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildStatCard(
                        "Total Courses",
                        courses.length.toString(),
                        Icons.library_books,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchCourses,
                    child: courses.isEmpty
                        ? ListView(
                            physics: AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 100),
                              Icon(
                                Icons.folder_open,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              Center(
                                child: Text(
                                  "No courses found.\nPull down to refresh.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(15),
                            itemCount: courses.length,
                            itemBuilder: (context, index) {
                              String courseName = courses[index];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.class_,
                                    color: Colors.blueAccent,
                                  ),
                                  title: Text(
                                    courseName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CourseSessionsScreen(
                                        courseName: courseName,
                                        teacherUsername: widget.teacherUsername,
                                      ),
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
        onPressed: showAddCourseDialog,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          "Add Course",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
