import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medication Reminder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('老人吃药提醒应用'),
        ),
        body: const Center(
          child: Text(
            '应用运行成功！',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
