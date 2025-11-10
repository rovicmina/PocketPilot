import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketPilot Sample',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SampleHomePage(),
    );
  }
}

class SampleHomePage extends StatelessWidget {
  const SampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketPilot Sample'),
      ),
      body: const Center(
        child: Text('PocketPilot Sample Code'),
      ),
    );
  }
}