import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PrayerPage extends StatefulWidget {
  const PrayerPage({super.key});

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  final Map<String, String> prayerTimes = {
   'الفجْر': '4:47 ص',
    'الشروق': '6:20 ص',
    'الظُّهْر': '12:53 م',
    'العَصر': '4:29 م',
    'المَغرب': '7:27 م',
    'العِشاء': '8:50 م',
  };

  late String nextPrayer;
  late Duration timeRemaining;
  late Timer timer;
  late String backgroundImage;

  @override
  void initState() {
    super.initState();
    nextPrayer = '';
    timeRemaining = Duration.zero;
    backgroundImage = 'assets/default.jpg';
    _calculateNextPrayer();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateNextPrayer();
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  DateTime _parsePrayerTime(String timeStr, DateTime now) {
    try {
      String englishTime = timeStr.replaceAll('ص', 'AM').replaceAll('م', 'PM');
      final format = DateFormat('h:mm a');
      final dateTime = format.parse(englishTime);
      return DateTime(
        now.year,
        now.month,
        now.day,
        dateTime.hour,
        dateTime.minute,
      );
    } catch (e) {
      debugPrint('Error parsing time $timeStr: $e');
      return now.add(const Duration(hours: 1));
    }
  }

  void _calculateNextPrayer() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> prayerTimeList = prayerTimes.entries.map((entry) {
      return {
        'name': entry.key,
        'time': _parsePrayerTime(entry.value, now),
      };
    }).toList();

    prayerTimeList.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    Map<String, dynamic>? next;
    for (var prayer in prayerTimeList) {
      if ((prayer['time'] as DateTime).isAfter(now)) {
        next = prayer;
        break;
      }
    }

    if (next == null && prayerTimeList.isNotEmpty) {
      next = {
        'name': prayerTimeList[0]['name'],
        'time': (prayerTimeList[0]['time'] as DateTime).add(const Duration(days: 1)),
      };
    }

    if (next != null) {
      setState(() {
        nextPrayer = next!['name'] as String;
        timeRemaining = (next!['time'] as DateTime).difference(now);
        switch (nextPrayer) {
          case 'الفجْر':
            backgroundImage = 'assets/Fajr.png';
            break;
          case 'الظُّهْر':
            backgroundImage = 'assets/thohr.png';
            break;
          case 'العَصر':
            backgroundImage = 'assets/Asr.png';
            break;
          case 'المَغرب':
            backgroundImage = 'assets/Maghreb.png';
            break;
          case 'العِشاء':
            backgroundImage = 'assets/isha.png';
            break;
          default:
            backgroundImage = 'assets/default.jpg';
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey<String>(backgroundImage),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(backgroundImage),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'الوقت المتبقي لصلاة',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nextPrayer,
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _formatDuration(timeRemaining),
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Digital',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
