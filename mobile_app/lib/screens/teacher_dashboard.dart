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

  // ⚙️ LOGIC: Bilkul wahi hai jo aapka tha
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

  // ⚙️ LOGIC: Bilkul wahi hai jo aapka tha
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

  // ⚙️ LOGIC: Bilkul wahi hai jo aapka tha
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
            prefixIcon: Icon(Icons.book, color: Colors.blueAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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

  // ✨ NAYA UI WIDGET: Chotay Stats Box ke liye
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
      backgroundColor: Colors.grey[100], // Halka sa grey background
      appBar: AppBar(
        elevation: 0, // Appbar flat kar diya taake header ke sath mix ho jaye
        title: Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
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
          ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                // ✨ NAYA UI: Dashboard Header Area
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 30,
                    top: 10,
                  ),
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
                        style: TextStyle(color: Colors.white70, fontSize: 16),
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
                      Row(
                        children: [
                          _buildStatCard(
                            "Total Courses",
                            courses.length.toString(),
                            Icons.library_books,
                          ),
                          SizedBox(width: 15),
                          _buildStatCard(
                            "Status",
                            "Active",
                            Icons.verified_user,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // My Courses Title
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Your Active Courses",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                // ✨ NAYA UI: List of Courses
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchCourses,
                    color: Colors.blueAccent,
                    child: courses.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.1,
                              ),
                              Icon(
                                Icons.folder_open,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 10),
                              Center(
                                child: Text(
                                  "No courses found. Create one!\nPull down to refresh.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            itemCount: courses.length,
                            itemBuilder: (context, index) {
                              String courseName = courses[index];
                              return Card(
                                elevation: 2,
                                margin: EdgeInsets.only(bottom: 15),
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
                                            CourseSessionsScreen(
                                              courseName: courseName,
                                              teacherUsername:
                                                  widget.teacherUsername,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(15.0),
                                    child: Row(
                                      children: [
                                        // Course Icon
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.class_,
                                            color: Colors.blueAccent,
                                            size: 28,
                                          ),
                                        ),
                                        SizedBox(width: 15),

                                        // Course Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                courseName,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              Text(
                                                "Tap to manage attendance",
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Arrow Icon
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.grey[400],
                                          size: 18,
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
        onPressed: showAddCourseDialog,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          "Add Course",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
    );
  }
}
