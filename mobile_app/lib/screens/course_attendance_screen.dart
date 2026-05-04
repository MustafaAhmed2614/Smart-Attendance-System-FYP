import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';

class CourseAttendanceScreen extends StatefulWidget {
  final String courseName;
  final String teacherUsername;

  CourseAttendanceScreen({
    required this.courseName,
    required this.teacherUsername,
  });

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
    fetchPendingStudents();
  }

  // ==========================================
  // API: Backend se Pending Students mangwana
  // ==========================================
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

  // ==========================================
  // ➕ NAYA: App se naya Student Add Karne Ka Function (Testing ke liye)
  // ==========================================
  Future<void> addStudentToDatabase(String name, String rollNo) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Adding student to pending list...")),
      );

      final response = await http.post(
        Uri.parse('$backendUrl/admin/add-student/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "roll_number": rollNo,
          "course_name": widget.courseName,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Student Added!"),
            backgroundColor: Colors.green,
          ),
        );
        fetchPendingStudents(); // 🔄 Naya bacha aate hi list refresh karo
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to add student"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error adding student: $e");
    }
  }

  // Naya bacha add karne ka Popup Dialog
  void showAddStudentDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController rollNoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text("Add New Student"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Student Name",
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: rollNoController,
                decoration: InputDecoration(
                  labelText: "Roll Number",
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    rollNoController.text.isNotEmpty) {
                  Navigator.pop(context); // Popup band karo
                  await addStudentToDatabase(
                    nameController.text,
                    rollNoController.text,
                  ); // Backend par bhejo
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: Text("Add to List", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // 📸 UI: Face Register karne ka Popup
  // ==========================================
  void showRegistrationDialog(
    BuildContext context,
    String studentName,
    String rollNumber,
  ) {
    File? frontImage;
    File? leftImage;
    File? rightImage;
    final picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                "Register Face: $studentName",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Please capture all 3 angles to register.",
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    SizedBox(height: 15),

                    ListTile(
                      tileColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(Icons.face, color: Colors.blue),
                      title: Text("Front Face"),
                      trailing: Icon(
                        frontImage != null
                            ? Icons.check_circle
                            : Icons.camera_alt,
                        color: frontImage != null ? Colors.green : Colors.grey,
                      ),
                      onTap: () async {
                        final pic = await picker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (pic != null)
                          setDialogState(() => frontImage = File(pic.path));
                      },
                    ),
                    SizedBox(height: 10),

                    ListTile(
                      tileColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(Icons.turn_left, color: Colors.blue),
                      title: Text("Left Face"),
                      trailing: Icon(
                        leftImage != null
                            ? Icons.check_circle
                            : Icons.camera_alt,
                        color: leftImage != null ? Colors.green : Colors.grey,
                      ),
                      onTap: () async {
                        final pic = await picker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (pic != null)
                          setDialogState(() => leftImage = File(pic.path));
                      },
                    ),
                    SizedBox(height: 10),

                    ListTile(
                      tileColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(Icons.turn_right, color: Colors.blue),
                      title: Text("Right Face"),
                      trailing: Icon(
                        rightImage != null
                            ? Icons.check_circle
                            : Icons.camera_alt,
                        color: rightImage != null ? Colors.green : Colors.grey,
                      ),
                      onTap: () async {
                        final pic = await picker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (pic != null)
                          setDialogState(() => rightImage = File(pic.path));
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed:
                      (frontImage != null &&
                          leftImage != null &&
                          rightImage != null)
                      ? () {
                          Navigator.pop(context);
                          uploadFacesToAPI(
                            studentName,
                            rollNumber,
                            frontImage!,
                            leftImage!,
                            rightImage!,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text(
                    "Upload & Save",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // API: 3 Tasweerein Backend par bhejna
  // ==========================================
  Future<void> uploadFacesToAPI(
    String studentName,
    String rollNumber,
    File front,
    File left,
    File right,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Uploading faces for $studentName...")),
      );

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/register'),
      );
      request.fields['name'] = studentName;
      request.fields['roll_number'] = rollNumber;

      request.files.add(
        await http.MultipartFile.fromPath('front_image', front.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('left_image', left.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('right_image', right.path),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Face Registered Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        fetchPendingStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to save in Database."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Upload Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // API: Rozana Attendance Lagana (1 Picture)
  // ==========================================
  Future<void> markAttendance() async {
    final picker = ImagePicker();

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opening camera for attendance...")),
      );
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Analyzing face, please wait...")));

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/detect-attendance/'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);

      if (response.statusCode == 200 && data['status'] == 'Success') {
        List<dynamic> recognizedStudents = data['recognized_students'];

        if (recognizedStudents.isNotEmpty) {
          String names = recognizedStudents.join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Attendance Marked for: $names"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Unrecognized Face!"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${data['message']}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Attendance Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // TAB 1: DAILY ATTENDANCE
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
                      markAttendance();
                    },
                    icon: Icon(Icons.camera_alt),
                    label: Text(
                      "Start Face Recognition",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),

            // TAB 2: PENDING REGISTRATIONS
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
                        margin: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            student['name'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Roll No: ${student['roll_number']}"),
                          trailing: ElevatedButton(
                            onPressed: () {
                              showRegistrationDialog(
                                context,
                                student['name'],
                                student['roll_number'],
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

        // 🚀 NAYA: Testing ke liye Student Add karne ka Floating Button
        floatingActionButton: FloatingActionButton.extended(
          onPressed: showAddStudentDialog,
          icon: Icon(Icons.add, color: Colors.white),
          label: Text("Add Student", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blueAccent,
        ),
      ),
    );
  }
}
