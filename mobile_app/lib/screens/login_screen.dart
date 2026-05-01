import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  // 🚀 By default "student" select hoga
  String selectedRole = 'student';

  Future<void> loginUser() async {
    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter Username and Password!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/login/'),
        headers: {"Content-Type": "application/json"},
        // Hum backend ko role bhi bhej rahe hain
        body: jsonEncode({
          "username": usernameController.text,
          "password": passwordController.text,
          "role": selectedRole,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'Success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Successful!"),
            backgroundColor: Colors.green,
          ),
        );

        // 🚀 Role ke hisaab se Dashboard open karein
        if (selectedRole == 'teacher') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TeacherDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StudentDashboard(rollNumber: usernameController.text),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Login Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection Error!"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo ya Icon
              Icon(
                Icons.face_retouching_natural,
                size: 100,
                color: Colors.blueAccent,
              ),
              SizedBox(height: 20),
              Text(
                "Smart Attendance",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              SizedBox(height: 30),

              // 🚀 STUDENT AUR TEACHER KA TOGGLE BUTTON
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedRole = 'student'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          // Agar student select hai toh blue, warna grey
                          color: selectedRole == 'student'
                              ? Colors.blueAccent
                              : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "👨‍🎓 Student",
                            style: TextStyle(
                              color: selectedRole == 'student'
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedRole = 'teacher'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          // Agar teacher select hai toh blue, warna grey
                          color: selectedRole == 'teacher'
                              ? Colors.blueAccent
                              : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "👨‍🏫 Teacher",
                            style: TextStyle(
                              color: selectedRole == 'teacher'
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Username aur Password fields
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username / Roll Number',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 25),

              // Login Button
              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: loginUser,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),

              SizedBox(height: 15),

              // Signup Navigation
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignupScreen()),
                  );
                },
                child: Text(
                  "Don't have an account? Sign Up",
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
