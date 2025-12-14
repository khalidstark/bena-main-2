import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class MyStreakScreen extends StatefulWidget {
  const MyStreakScreen({super.key});

  @override
  _MyStreakScreenState createState() => _MyStreakScreenState();
}

class _MyStreakScreenState extends State<MyStreakScreen> {
  DateTime today = DateTime.now();
  List<DateTime> completedDays = [];
  int streakCount = 0;
  String userName = "Loading...";
  String? userId;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user signed in.");
        return;
      }
      userId = user.uid;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userName = userDoc["name"] ?? "Unknown";
        });
      }

      QuerySnapshot usageDocs = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("usage")
          .get();

      List<DateTime> streakDays = [];

      for (var doc in usageDocs.docs) {
        String dateString = doc.id;
        int minutes = (doc.data() as Map<String, dynamic>)["minutes"] ?? 0;

        if (minutes > 120) {
          streakDays.add(DateTime.parse(dateString));
        }
      }

      streakDays.sort((a, b) => a.compareTo(b));

      // Calculate streak
      int currentStreak = 0;
      DateTime currentDate = DateTime.now();
      DateTime previousDate = currentDate.subtract(const Duration(days: 1));
      
      if (streakDays.isNotEmpty && isSameDay(streakDays.last, currentDate)) {
        currentStreak++;
        currentDate = previousDate;
        previousDate = currentDate.subtract(const Duration(days: 1));
      }
      
      for (int i = streakDays.length - 1; i >= 0; i--) {
        DateTime day = streakDays[i];
        
        if (isSameDay(day, currentDate)) {
          currentStreak++;
          currentDate = previousDate;
          previousDate = currentDate.subtract(const Duration(days: 1));
        } else if (day.isBefore(currentDate)) {
          break;
        }
      }

      setState(() {
        completedDays = streakDays;
        streakCount = currentStreak;
      });

      await FirebaseFirestore.instance.collection("users").doc(userId).update({
        "streakCount": streakCount,
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Streak', 
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            )),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Streak Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF5B905).withOpacity(0.8),
                  const Color(0xFFF5B905).withOpacity(0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$streakCount',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Day Streak',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Calendar Section
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Activity Calendar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Track your learning progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: TableCalendar(
                      focusedDay: today,
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      calendarFormat: CalendarFormat.month,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.grey),
                        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.grey),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                        weekendStyle: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFFF5B905).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        weekendTextStyle: const TextStyle(color: Colors.black),
                        defaultTextStyle: const TextStyle(color: Colors.black),
                        outsideTextStyle: TextStyle(color: Colors.grey[400]),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          bool isCompleted = completedDays.any((completedDay) =>
                              isSameDay(completedDay, day));

                          bool isToday = isSameDay(day, today);

                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted ? const Color(0xFFF5B905) : null,
                              border: isToday
                                  ? Border.all(
                                      color: const Color(0xFFF5B905),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isCompleted ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}