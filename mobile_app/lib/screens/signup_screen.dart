import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 1. Form ko validate karne ke liye key
  final _formKey = GlobalKey<FormState>();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String selectedRole = 'student';
  bool isLoading = false;

  // 2. Password chupane ya dikhane ke liye
  bool _isObscure = true;

  // 3. Strong Password check karne ka formula (Regex)
  bool _isPasswordStrong(String password) {
    final RegExp passwordRegex = RegExp(
      r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
    );
    return passwordRegex.hasMatch(password);
  }

  Future<void> signupUser() async {
    // 4. Sab se pehle check karein ke kya form ke saare rules follow hue hain?
    if (!_formKey.currentState!.validate()) {
      return; // Agar error hai toh API call mat karo
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/signup/'),
        headers: {"Content-Type": "application/json"},
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
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Wapas Login par le jayega
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Signup Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error! Check your network.'),
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
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            // FORM WIDGET ADD KIYA HAI
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_add_alt_1,
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Join Smart Attendance",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 30),

                // USERNAME FIELD
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username / Roll Number',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter Username or Roll Number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // PASSWORD FIELD (WITH STRONG VALIDATION & EYE ICON)
                TextFormField(
                  controller: passwordController,
                  obscureText: _isObscure,
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Type karte waqt error dikhaye
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Must be at least 8 characters';
                    }
                    if (!_isPasswordStrong(value)) {
                      return 'Needs 1 Uppercase, 1 Number & 1 Symbol (e.g. @#\$)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // ROLE SELECTION DROPDOWN
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.blueAccent,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text("👨‍🎓 I am a Student"),
                        ),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text("👨‍🏫 I am a Teacher"),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedRole = value!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // SUBMIT BUTTON
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: signupUser,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
