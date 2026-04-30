import 'package:flutter/material.dart';
import 'package:fyp_app/constants.dart';
import 'package:fyp_app/screens/home_screen.dart';
import 'package:fyp_app/screens/student_dashboard.dart';
import 'package:http/http.dart' as http;
import 'signup_screen.dart';
import 'dart:convert';
import 'teacher_dashboard.dart';
import '../constants.dart'; // Shuru mein 2 dots (..) aur ek slash Teacher ki screen
// import 'main.dart'; // Agar aapki purani main screen ka naam kuch aur hai toh yahan link karein

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Yahan apna FastAPI wala IP address lagayen
  final String backendUrl = AppConfig.backendUrl;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/login/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": usernameController.text,
          "password": passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'Success') {
        // Agar Teacher login kare:
        if (data['role'] == 'teacher') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
            // Note: Agar aap Teacher ko direct Home Screen par bhejna chahte hain, toh 'TeacherDashboard()' ki jagah apni purani screen ka naam likhein.
          );
        }
        // Agar Student login kare:
        else if (data['role'] == 'student') {
          // Abhi humne Student screen banani hai, filhal ek dummy message dikha dete hain
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StudentDashboard(rollNumber: usernameController.text),
            ),
          );
        }
      } else {
        // Password ya Username galat hone par error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Login Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Smart Attendance Login')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person, size: 100, color: Colors.blueAccent),
            SizedBox(height: 20),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username or Roll Number',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true, // Password chupane ke liye
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: loginUser,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
            SizedBox(height: 15),
            // Login button ke baad yeh lagayen:
            SizedBox(height: 10),
            TextButton(
              onPressed: () {
                // Signup Screen par le kar jaye
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignupScreen()),
                );
              },
              child: Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
