import 'package:flutter/material.dart';

class List extends StatelessWidget {
  const List({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // الخلفية بيضا
      appBar: AppBar(
        title: const Text('List Page'),
      ),
      body: const Center(
        child: Text(
          'Hello',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
