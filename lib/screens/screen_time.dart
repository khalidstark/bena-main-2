import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  static const platform = MethodChannel('com.zamo.proft/screentime');
  String screenTime = "Fetching...";

  /// استرجاع وقت استخدام الهاتف كما هو
  Future<void> getScreenTime() async {
    try {
      final result = await platform.invokeMethod('getScreenTime');
      int totalMinutes = (result as int?) ?? 0;

      final int hours = totalMinutes ~/ 60;
      final int minutes = totalMinutes % 60;

      setState(() {
        screenTime = "$hours hours $minutes minutes";
      });
    } on PlatformException catch (e) {
      print("🔥 Error getting screen time: ${e.message}");
      setState(() {
        screenTime = "Error fetching screen time";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getScreenTime();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Screen Time',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5B905),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: const Color(0xFFF5B905),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer,
                size: 80,
                color: Color.fromARGB(
                    255, 255, 255, 255), // تغيير الأيقونة إلى الأسود
              ),
              const SizedBox(height: 20),
              const Text(
                "Your Screen Time Today:",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                screenTime,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: getScreenTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(
                      255, 255, 255, 255), // الزر بلون أسود
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Refresh Screen Time",
                  style: TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 0, 0, 0)), // النص بالأبيض
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
