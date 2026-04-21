import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // Apne folder structure ke mutabiq path check karlein

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FYP Smart Attendance',
      debugShowCheckedModeBanner:
          false, // Top right se debug banner hatane ke liye
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Modern look ke liye
      ),
      // App start hote hi Home Screen khulegi
      home: const HomeScreen(),
    );
  }
}
