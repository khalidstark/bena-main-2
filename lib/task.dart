import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskPage extends StatefulWidget {
  final String taskId;

  const TaskPage({super.key, required this.taskId});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<DocumentSnapshot> _taskFuture;
  late Future<String> _userLanguageFuture;
  
  // Timer state
  Duration timerDuration = Duration.zero;
  Timer? countdownTimer;
  bool isRunning = false;
  int points = 0;
  int minutes = 0;
  int todayScore = 0;
  bool showExitConfirmation = false;
  int exitCountdown = 60;
  Timer? exitConfirmationTimer;
  DateTime? sessionStartTime;
  bool taskCompleted = false;
  int totalDurationMinutes = 0;
  
  // Prayer break state
  bool isPrayerBreakActive = false;
  Duration prayerBreakDuration = const Duration(minutes: 20);
  Timer? prayerBreakTimer;
  int availablePrayerBreaks = 0;
  bool isMuslim = false;

  // Language state
  String userLanguage = 'english';
  Map<String, Map<String, String>> translations = {
    'english': {
      'taskDetails': 'Task Details',
      'points': 'Points',
      'minutes': 'Minutes',
      'focusing': 'Focusing...',
      'paused': 'Paused',
      'setYourFocusTime': 'Set your focus time',
      'prayerBreak': 'Prayer Break',
      'continueSession': 'Continue Session',
      'start': 'Start',
      'exit': 'Exit',
      'todayScore': 'Today Score',
      'description': 'Description',
      'sessionPaused': 'Session Paused',
      'returnWarning': "You have 60 seconds to return or you'll lose all points earned in this session.",
      'secondsRemaining': 'seconds remaining',
      'continue': 'Continue',
      'confirmExit': 'Exit',
      'taskNotFound': 'Task not found',
    },
    'arabic': {
      'taskDetails': 'تفاصيل المهمة',
      'points': 'النقاط',
      'minutes': 'الدقائق',
      'focusing': 'جاري التركيز...',
      'paused': 'متوقف',
      'setYourFocusTime': 'حدد وقت تركيزك',
      'prayerBreak': 'استراحة صلاة',
      'continueSession': 'استمر في الجلسة',
      'start': 'ابدأ',
      'exit': 'خروج',
      'todayScore': 'النقاط اليوم',
      'description': 'الوصف',
      'sessionPaused': 'تم إيقاف الجلسة مؤقتًا',
      'returnWarning': 'لديك 60 ثانية للعودة أو ستفقد جميع النقاط المكتسبة في هذه الجلسة.',
      'secondsRemaining': 'ثانية متبقية',
      'continue': 'استمر',
      'confirmExit': 'خروج',
      'taskNotFound': 'المهمة غير موجودة',
    },
  };

  // Math challenge state (removed functionality)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taskFuture = _firestore.collection('tasks').doc(widget.taskId).get();
    _userLanguageFuture = _getUserLanguage();
    _initializeData();
  }

  Future<String> _getUserLanguage() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['lang'] ?? 'english';
      }
    }
    return 'english';
  }

 

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    countdownTimer?.cancel();
    exitConfirmationTimer?.cancel();
    prayerBreakTimer?.cancel();
  }

  Future<void> _initializeData() async {
    final taskSnapshot = await _taskFuture;
    if (!taskSnapshot.exists) return;

    final taskData = taskSnapshot.data() as Map<String, dynamic>;
    final totalDuration = taskData['duration'] ?? 0;
    final completedMinutes = taskData['minutes'] ?? 0;
    
    // Get user language
    final language = await _userLanguageFuture;
    
    setState(() {
      userLanguage = language;
      totalDurationMinutes = totalDuration;
      timerDuration = Duration(minutes: totalDuration - completedMinutes);
      availablePrayerBreaks = taskData['prayerBreaks'] ?? 0;
      isMuslim = (taskData['prayers'] as List?)?.isNotEmpty ?? false;
      points = taskData['Points'] ?? 0;
      minutes = completedMinutes;
    });
  }

  void startPrayerBreak() {
    if (!isMuslim || availablePrayerBreaks <= 0 || isPrayerBreakActive) return;

    countdownTimer?.cancel();
    
    setState(() {
      isPrayerBreakActive = true;
      isRunning = false;
      availablePrayerBreaks--;
    });

    prayerBreakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (prayerBreakDuration.inSeconds > 0) {
          prayerBreakDuration -= const Duration(seconds: 1);
        } else {
          timer.cancel();
          _endPrayerBreak();
        }
      });
    });

    _firestore.collection('tasks').doc(widget.taskId).update({
      'prayerBreaks': FieldValue.increment(-1),
    });
  }

  void _endPrayerBreak() {
    prayerBreakTimer?.cancel();
    setState(() {
      isPrayerBreakActive = false;
      prayerBreakDuration = const Duration(minutes: 20);
    });
    startTimer();
  }

  void startTimer() {
    if (isRunning || timerDuration.inSeconds <= 0) return;

    _firestore.collection('tasks').doc(widget.taskId).update({
      'isStarted': true,
    });

    setState(() {
      isRunning = true;
      sessionStartTime = DateTime.now();
      taskCompleted = false;
    });

    _cancelTimers();

    int secondsSinceLastMinute = 0;
    
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timerDuration.inSeconds > 0) {
          timerDuration -= const Duration(seconds: 1);
          secondsSinceLastMinute++;
          
          if (secondsSinceLastMinute >= 60) {
            minutes++;
            points++;
            secondsSinceLastMinute = 0;
            _updateTaskStats();
          }
        } else {
          timer.cancel();
          isRunning = false;
          _markTaskComplete();
        }
      });
    });
  }

  Future<void> _updateTaskStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final todayDocId = DateFormat('yyyy-MM-dd').format(now) + ' 00:00:00.000';

    // Update task document
    await _firestore.collection('tasks').doc(widget.taskId).update({
      'Points': points,
      'minutes': minutes,
    });

    // Update usage collection
    await _firestore.runTransaction((transaction) async {
      final usageDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc(todayDocId);
      
      final usageDoc = await transaction.get(usageDocRef);
      
      if (usageDoc.exists) {
        transaction.update(usageDocRef, {
          'minutes': FieldValue.increment(1),
        });
      } else {
        transaction.set(usageDocRef, {
          'minutes': 1,
          'date': todayDocId,
        });
      }
    });
  }

  Future<void> _markTaskComplete() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final todayDocId = DateFormat('yyyy-MM-dd').format(now) + ' 00:00:00.000';

    await _firestore.collection('tasks').doc(widget.taskId).update({
      'complete': true,
      'completedAt': FieldValue.serverTimestamp(),
      'Points': points,
      'minutes': minutes,
    });

    await _firestore.runTransaction((transaction) async {
      final scoreDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('score')
          .doc(todayDocId);
      
      final scoreDoc = await transaction.get(scoreDocRef);
      
      if (scoreDoc.exists) {
        transaction.update(scoreDocRef, {
          'score': FieldValue.increment(points),
        });
      } else {
        transaction.set(scoreDocRef, {
          'score': points,
          'date': todayDocId,
        });
      }
    });

    setState(() {
      taskCompleted = true;
    });
  }

  void exitTimer() {
    if (!isRunning || showExitConfirmation) return;

    setState(() {
      isRunning = false;
      showExitConfirmation = true;
      exitCountdown = 60;
    });

    _cancelTimers();

    _firestore.collection('tasks').doc(widget.taskId).update({
      'entryCount': FieldValue.increment(-1),
    });

    exitConfirmationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (exitCountdown > 0) {
          exitCountdown--;
        } else {
          timer.cancel();
          _confirmExit();
        }
      });
    });
  }

  void _confirmExit() {
    setState(() {
      showExitConfirmation = false;
      isRunning = false;
    });
    Navigator.pop(context);
  }

  void _cancelExit() {
    exitConfirmationTimer?.cancel();
    setState(() {
      showExitConfirmation = false;
    });
    startTimer();
  }

  // App state monitoring
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App went to background
      if (isRunning) {
        exitTimer();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      // We could potentially resume here, but we'll keep it paused for safety
    }
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  // Helper method to get translated text
  String translate(String key) {
    return translations[userLanguage]?[key] ?? key;
  }

  // Helper method to get appropriate text style based on language
  TextStyle getTextStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    double height = 1.0,
  }) {
    if (userLanguage == 'arabic') {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    } else {
      return GoogleFonts.roboto(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double size = 250;
    double strokeWidth = 15;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          translate('taskDetails'),
          style: getTextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _taskFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(
              translate('taskNotFound'),
              style: getTextStyle(fontSize: 18),
            ));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final entryCount = data['entryCount'] ?? 0;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'No Name',
                      style: getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  data['name'] ?? 'Task',
                                  style: getTextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${translate('points')}: $points | ${translate('minutes')}: $minutes",
                                  style: getTextStyle(
                                    fontSize: 20, 
                                    color: const Color(0xFFF5B905),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: size + strokeWidth * 2,
                                height: size + strokeWidth * 2,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: size,
                                height: size,
                                child: CircularProgressIndicator(
                                  value: isPrayerBreakActive 
                                      ? prayerBreakDuration.inSeconds / 1200.0 
                                      : timerDuration.inSeconds / (totalDurationMinutes * 60.0),
                                  strokeWidth: strokeWidth,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isPrayerBreakActive 
                                        ? formatTime(prayerBreakDuration)
                                        : formatTime(timerDuration),
                                    style: getTextStyle(
                                      fontSize: 32, 
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isPrayerBreakActive ? translate('prayerBreak') :
                                    isRunning ? translate('focusing') : 
                                    showExitConfirmation ? translate('paused') : translate('setYourFocusTime'),
                                    style: getTextStyle(
                                      color: const Color.fromARGB(255, 147, 147, 147),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          
                          if (isMuslim && availablePrayerBreaks > 0 && (isRunning || isPrayerBreakActive))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: ElevatedButton(
                                onPressed: isPrayerBreakActive ? _endPrayerBreak : startPrayerBreak,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPrayerBreakActive ? Colors.green : Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  isPrayerBreakActive 
                                      ? translate('continueSession') 
                                      : "${translate('prayerBreak')} ($availablePrayerBreaks)",
                                  style: getTextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: !isRunning && !showExitConfirmation && timerDuration.inSeconds > 0 
                                    ? startTimer
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  translate('start'), 
                                  style: getTextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: isRunning && entryCount > 0 ? exitTimer : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  "${translate('exit')} ($entryCount)", 
                                  style: getTextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              "${translate('todayScore')}: $todayScore",
                              style: getTextStyle(fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    if (data['start'] != null && data['start'].isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${data['start'] ?? ''} - ${data['end'] ?? ''}',
                                style: getTextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(DateTime.parse(data['date'] ?? '')),
                          style: getTextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    if (data['description'] != null && data['description'].isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${translate('description')}:',
                            style: getTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['description'],
                            style: getTextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              if (showExitConfirmation)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            size: 50,
                            color: Color(0xFFF5B905)),
                          
                        
                          Text(
                            translate('sessionPaused'),
                            style: getTextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            translate('returnWarning'),
                            textAlign: TextAlign.center,
                            style: getTextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "$exitCountdown ${translate('secondsRemaining')}",
                              style: getTextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _cancelExit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  translate('continue'),
                                  style: getTextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              ElevatedButton(
                                onPressed: _confirmExit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  translate('confirmExit'),
                                  style: getTextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}