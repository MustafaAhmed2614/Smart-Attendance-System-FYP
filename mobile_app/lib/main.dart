import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // Hum abhi ye file banayenge

void main() {
  runApp(
    const MaterialApp(home: HomeScreen(), debugShowCheckedModeBanner: false),
  );
}
