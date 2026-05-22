import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(EGXApp());
}

class EGXApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EGX Fair Value',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(),
    );
  }
}
