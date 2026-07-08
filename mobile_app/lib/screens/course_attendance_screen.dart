import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import 'dart:typed_data';

class CourseAttendanceScreen extends StatefulWidget {
  final String courseName;
  final String teacherUsername;
  final String date;

  CourseAttendanceScreen({
    required this.courseName,
    required this.teacherUsername,
    required this.date,
  });

  @override
  _CourseAttendanceScreenState createState() => _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<CourseAttendanceScreen> {
  final String backendUrl = AppConfig.backendUrl;

  List<dynamic> pendingStudents = [];
  bool isLoadingPending = true;

  List<dynamic> todayAttendanceList = [];
  bool isLoadingAttendance = true;
  String todayDate = "";
  bool isScanning = false;

  bool isUploadingFaces = false;

  @override
  void initState() {
    super.initState();
    fetchPendingStudents();
    fetchTodayAttendance();
  }

  // API: Get Pending Students
  Future<void> fetchPendingStudents() async {
    setState(() => isLoadingPending = true);
    try {
      final response = await http.get(
        Uri.parse(
          '$backendUrl/pending-students/${Uri.encodeComponent(widget.courseName)}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Success') {
          setState(() {
            pendingStudents = data['pending_students'];
            isLoadingPending = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching pending students: $e");
      setState(() => isLoadingPending = false);
    }
  }

  Future<void> fetchTodayAttendance() async {
    setState(() => isLoadingAttendance = true);
    try {
      final response = await http.get(
        Uri.parse(
          '$backendUrl/attendance-by-date/${Uri.encodeComponent(widget.courseName)}/${widget.date}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Success') {
          setState(() {
            todayAttendanceList = data['attendance_list'];
            todayDate = data['date'];
            isLoadingAttendance = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching attendance: $e");
      setState(() => isLoadingAttendance = false);
    }
  }

  // API: Manual Toggle Attendance
  Future<void> toggleManualAttendance(
    String rollNumber,
    String currentStatus,
  ) async {
    String newStatus = currentStatus == "Present" ? "Absent" : "Present";

    setState(() {
      for (var student in todayAttendanceList) {
        if (student['roll_number'] == rollNumber) {
          student['status'] = newStatus;
        }
      }
    });

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/toggle-attendance/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roll_number": rollNumber,
          "course_name": widget.courseName,
          "status": newStatus,
          "date": widget.date,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          fetchTodayAttendance();
        }
      }
    } catch (e) {
      fetchTodayAttendance();
    }
  }

  // API: Add Student
  Future<void> addStudentToDatabase(String name, String rollNo) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Adding student to pending list...")),
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

      if (!mounted) return;
      var data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'Success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Student Added!"),
            backgroundColor: Colors.green,
          ),
        );
        fetchPendingStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: ${data['message']}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ App Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

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
          title: const Text("Add New Student"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Student Name",
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rollNoController,
                decoration: const InputDecoration(
                  labelText: "Roll Number",
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    rollNoController.text.isNotEmpty) {
                  Navigator.pop(context);
                  await addStudentToDatabase(
                    nameController.text,
                    rollNoController.text,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text(
                "Add to List",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFaceTile(String title, File? image, VoidCallback onTap) {
    return ListTile(
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: image != null
          ? CircleAvatar(backgroundImage: FileImage(image))
          : CircleAvatar(
              backgroundColor: Colors.blue[50],
              child: const Icon(Icons.face, color: Colors.blue),
            ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Icon(
        image != null ? Icons.check_circle : Icons.camera_alt,
        color: image != null ? Colors.green : Colors.grey,
        size: 28,
      ),
      onTap: onTap,
    );
  }

  void showRegistrationDialog(
    BuildContext context,
    String studentName,
    String rollNumber,
  ) {
    File? frontImage;
    File? leftImage;
    File? rightImage;
    File? upImage;
    File? smileImage;
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
                "Register: $studentName",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Capture all 5 variations for best AI accuracy.",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    _buildFaceTile("1. Front Face", frontImage, () async {
                      final pic = await picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (pic != null)
                        setDialogState(() => frontImage = File(pic.path));
                    }),
                    const SizedBox(height: 10),
                    _buildFaceTile("2. Left Profile", leftImage, () async {
                      final pic = await picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (pic != null)
                        setDialogState(() => leftImage = File(pic.path));
                    }),
                    const SizedBox(height: 10),
                    _buildFaceTile("3. Right Profile", rightImage, () async {
                      final pic = await picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (pic != null)
                        setDialogState(() => rightImage = File(pic.path));
                    }),
                    const SizedBox(height: 10),
                    _buildFaceTile("4. Look Slightly Up", upImage, () async {
                      final pic = await picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (pic != null)
                        setDialogState(() => upImage = File(pic.path));
                    }),
                    const SizedBox(height: 10),
                    _buildFaceTile("5. Random / Smile", smileImage, () async {
                      final pic = await picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (pic != null)
                        setDialogState(() => smileImage = File(pic.path));
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      (frontImage != null &&
                          leftImage != null &&
                          rightImage != null &&
                          upImage != null &&
                          smileImage != null)
                      ? () {
                          Navigator.pop(context);
                          uploadFacesToAPI(
                            studentName,
                            rollNumber,
                            frontImage!,
                            leftImage!,
                            rightImage!,
                            upImage!,
                            smileImage!,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
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

  Future<void> uploadFacesToAPI(
    String studentName,
    String rollNumber,
    File front,
    File left,
    File right,
    File up,
    File smile,
  ) async {
    setState(() {
      isUploadingFaces = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Uploading 5 faces for $studentName...")),
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
      request.files.add(await http.MultipartFile.fromPath('up_image', up.path));
      request.files.add(
        await http.MultipartFile.fromPath('smile_image', smile.path),
      );

      var response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ All 5 Faces Registered!"),
            backgroundColor: Colors.green,
          ),
        );
        fetchPendingStudents();
        fetchTodayAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Failed to save in Database."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          isUploadingFaces = false;
        });
      }
    }
  }

  Future<void> markAttendance() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 100,
      maxWidth: 1920,
    );
    if (image == null) return;

    setState(() => isScanning = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/detect-attendance/'),
      );
      request.fields['course_name'] = widget.courseName;
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);

      if (!mounted) return;

      setState(() => isScanning = false);

      if (response.statusCode == 200 && data['status'] == 'Success') {
        List<dynamic> recognizedStudents = data['recognized_students'];
        Uint8List? annotatedImageBytes;
        if (data['image'] != null) {
          annotatedImageBytes = base64Decode(data['image']);
        }

        if (recognizedStudents.isNotEmpty) {
          int count = recognizedStudents.length;
          String namesList = recognizedStudents.join('\n• ');

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                "$count Students Marked!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (annotatedImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          annotatedImageBytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 15),
                    Text(
                      "Successfully marked present:\n\n• $namesList",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        fetchTodayAttendance();
                        markAttendance();
                      },
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.blueAccent,
                      ),
                      label: const Text(
                        "Scan More",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        fetchTodayAttendance();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        "Finish",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.error, color: Colors.red, size: 60),
              title: const Text(
                "No Faces Recognized",
                textAlign: TextAlign.center,
              ),
              content: const Text(
                "The AI could not recognize any registered students.",
              ),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Try Again"),
                  ),
                ),
              ],
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
      setState(() => isScanning = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    }
  }

  // ✨ NAYA WIDGET: Helper function for the Summary Card Columns
  Widget _buildStatColumn(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✨ NAYI LOGIC: Real-time calculation for the Summary Card
    int totalStudents = todayAttendanceList.length;
    int presentCount = todayAttendanceList
        .where((student) => student['status'] == "Present")
        .length;
    int absentCount = totalStudents - presentCount;

    return WillPopScope(
      onWillPop: () async => !isUploadingFaces,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.courseName),
            backgroundColor: Colors.blueAccent,
            bottom: const TabBar(
              indicatorColor: Colors.white,
              tabs: [
                Tab(icon: Icon(Icons.how_to_reg), text: "Daily Status"),
                Tab(icon: Icon(Icons.person_add_alt_1), text: "Pending Faces"),
              ],
            ),
          ),

          body: Stack(
            children: [
              TabBarView(
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        width: double.infinity,
                        color: Colors.blue[50],
                        child: ElevatedButton.icon(
                          onPressed: isScanning ? null : markAttendance,
                          icon: isScanning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(
                            isScanning
                                ? "Scanning Faces... Please wait"
                                : "Scan Class for Attendance",
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: isScanning
                                ? Colors.grey
                                : Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Today's Roster",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              todayDate,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),

                      // ✨ NAYA UI: Summary Card (Sirf tab dikhega jab data hoga)
                      if (!isLoadingAttendance &&
                          todayAttendanceList.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          margin: const EdgeInsets.only(
                            left: 15,
                            right: 15,
                            bottom: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn(
                                "Total",
                                totalStudents,
                                Colors.blueAccent,
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              _buildStatColumn(
                                "Present",
                                presentCount,
                                Colors.green,
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              _buildStatColumn(
                                "Absent",
                                absentCount,
                                Colors.redAccent,
                              ),
                            ],
                          ),
                        ),

                      Expanded(
                        child: isLoadingAttendance
                            ? const Center(child: CircularProgressIndicator())
                            : todayAttendanceList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.group_off,
                                      size: 60,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      "No registered students found.",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: todayAttendanceList.length,
                                itemBuilder: (context, index) {
                                  var student = todayAttendanceList[index];
                                  bool isPresent =
                                      student['status'] == "Present";

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
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
                                        student['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "Roll No: ${student['roll_number']}",
                                      ),
                                      trailing: GestureDetector(
                                        onTap: () {
                                          toggleManualAttendance(
                                            student['roll_number'],
                                            student['status'],
                                          );
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPresent
                                                ? Colors.green
                                                : Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    (isPresent
                                                            ? Colors.green
                                                            : Colors.red)
                                                        .withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                student['status'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.touch_app,
                                                color: Colors.white,
                                                size: 15,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  isLoadingPending
                      ? const Center(child: CircularProgressIndicator())
                      : pendingStudents.isEmpty
                      ? const Center(
                          child: Text(
                            "No pending registrations!",
                            style: TextStyle(fontSize: 18, color: Colors.green),
                          ),
                        )
                      : ListView.builder(
                          itemCount: pendingStudents.length,
                          itemBuilder: (context, index) {
                            var student = pendingStudents[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                title: Text(
                                  student['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "Roll No: ${student['roll_number']}",
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    showRegistrationDialog(
                                      context,
                                      student['name'],
                                      student['roll_number'],
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text("Scan Face"),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),

              if (isUploadingFaces)
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.6),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.blueAccent),
                        SizedBox(height: 16),
                        Text(
                          'Uploading Images\nPlease wait, do not close the app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          floatingActionButton: FloatingActionButton.extended(
            onPressed: showAddStudentDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Add Student",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blueAccent,
          ),
        ),
      ),
    );
  }
}
