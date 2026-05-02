import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'login_screen.dart';
import 'course_attendance_screen.dart';
// Note: Hum agli screen mein CourseAttendance wali file banayenge

class TeacherDashboard extends StatefulWidget {
  final String teacherUsername; // Teacher ka username yahan aayega

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

  // 1. Backend se Courses mangwane ka function
  Future<void> fetchCourses() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/my-courses/${widget.teacherUsername}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Success') {
          setState(() {
            courses = data['courses'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching courses: $e");
      setState(() => isLoading = false);
    }
  }

  // 2. Naya Course Add karne ka function
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
      final data = jsonDecode(response.body);
      if (data['status'] == 'Success') {
        fetchCourses(); // List ko refresh karein
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error adding course: $e");
    }
  }

  // 3. Add Course ka Pop-up Dialog
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
                Navigator.pop(context); // Dialog band karein
                addCourse(courseController.text); // Course save karein
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
            icon: Icon(Icons.logout),
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
          : courses.isEmpty
          ? Center(child: Text("No courses found. Create one!"))
          : GridView.builder(
              padding: EdgeInsets.all(15),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Ek line mein 2 boxes
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
              ),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                String courseName = courses[index];
                return GestureDetector(
                  onTap: () {
                    // YAHAN HUM AGLI SCREEN PAR JAYENGE
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseAttendanceScreen(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddCourseDialog,
        icon: Icon(Icons.add),
        label: Text("Add Course"),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
