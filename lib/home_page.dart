import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Navigation state
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const TimerScreen(),
    const TodoListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFFF5B905),
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      type: BottomNavigationBarType.fixed,
      elevation: 10,
      items: [
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _currentIndex == 0 
                  ? const Color(0xFFF5B905).withOpacity(0.2) 
                  : Colors.transparent,
            ),
            child: const Icon(Icons.timer_outlined),
          ),
          activeIcon: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF5B905).withOpacity(0.2),
            ),
            child: const Icon(Icons.timer),
          ),
          label: 'Focus Timer',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _currentIndex == 1 
                  ? const Color(0xFFF5B905).withOpacity(0.2) 
                  : Colors.transparent,
            ),
            child: const Icon(Icons.list_outlined),
          ),
          activeIcon: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF5B905).withOpacity(0.2),
            ),
            child: const Icon(Icons.list),
          ),
          label: 'Todo List',
        ),
      ],
    );
  }
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  int points = 0;
  int todayScore = 0;
  Duration timerDuration = const Duration(hours: 3);
  bool isRunning = false;
  Timer? countdownTimer;
  Timer? pointsTimer;
  double progress = 1.0;
  double angle = 2 * pi;
  bool showExitConfirmation = false;
  int exitCountdown = 60;
  Timer? exitConfirmationTimer;
  DateTime? sessionStartTime;
  bool appInBackground = false;
  DateTime? lastBackgroundTime;
  Duration? backgroundDuration;
  bool penaltyApplied = false;
  Duration todayUsage = Duration.zero;
  Timer? usageTimer;
  DateTime? lastUsageUpdateTime;
  final ScrollController _scrollController = ScrollController();
  String userLanguage = 'english'; // Default language
  bool isAppInactive = false; // Track if app is inactive but not in background
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _fetchUserLanguage();
  }

  // Fetch user language from Firestore
  Future<void> _fetchUserLanguage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          userLanguage = userDoc.data()!['lang'] ?? 'english';
        });
      }
    } catch (e) {
      debugPrint('Error fetching user language: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    _endUsageTracking();
    _updateUserActiveStatus(false);
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    countdownTimer?.cancel();
    pointsTimer?.cancel();
    exitConfirmationTimer?.cancel();
    usageTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _handleAppBackground();
    } else if (state == AppLifecycleState.inactive) {
      // App is inactive (e.g., notification appears) but not fully in background
      _handleAppInactive();
    } else if (state == AppLifecycleState.resumed) {
      if (isAppInactive) {
        _handleAppResumeFromInactive();
      } else if (appInBackground) {
        _handleAppForeground();
      }
    }
  }

  Future<void> _handleAppInactive() async {
    if (!isRunning) return;
    
    setState(() {
      isAppInactive = true;
    });
    
    // Pause timers temporarily but don't apply penalty
    _cancelTimers();
    await _updateUsage();
    await _updateUserActiveStatus(false);
  }

  Future<void> _handleAppResumeFromInactive() async {
    if (!isAppInactive) return;
    
    setState(() {
      isAppInactive = false;
    });
    
    // Resume timers if app was just inactive (not in background)
    if (isRunning) {
      _startTimers();
      _startUsageTracking();
      await _updateUserActiveStatus(true);
    }
  }

  Future<void> _handleAppBackground() async {
    if (!isRunning) return;
    
    setState(() {
      appInBackground = true;
      lastBackgroundTime = DateTime.now();
    });

    await _updateUsage();
    
    if (!penaltyApplied) {
      await _applyPenalty();
      setState(() => penaltyApplied = true);
    }
    
    setState(() {
      isRunning = false;
      points = 0;
      progress = 1.0;
      angle = 2 * pi;
    });
    
    _cancelTimers();
    await _updateUserActiveStatus(false);
  }

  Future<void> _handleAppForeground() async {
    if (!appInBackground) return;
    
    setState(() {
      appInBackground = false;
      penaltyApplied = false;
      backgroundDuration = DateTime.now().difference(lastBackgroundTime!);
    });
    
    if (isRunning) {
      _startUsageTracking();
      await _updateUserActiveStatus(true);
    }
  }

  Future<void> _updateUserActiveStatus(bool isActive) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'IsActive': isActive,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating user active status: $e');
    }
  }

  Future<void> _startUsageTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      sessionStartTime = DateTime.now();
      lastUsageUpdateTime = DateTime.now();
    });

    usageTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _updateUsage();
    });
  }

  Future<void> _endUsageTracking() async {
    usageTimer?.cancel();
    await _updateUsage();
    
    setState(() {
      sessionStartTime = null;
      lastUsageUpdateTime = null;
    });
  }

  Future<void> _updateUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || sessionStartTime == null || lastUsageUpdateTime == null) return;

    final now = DateTime.now();
    final durationSinceLastUpdate = now.difference(lastUsageUpdateTime!);
    
    if (durationSinceLastUpdate.inMinutes < 1) return;

    final today = DateTime(now.year, now.month, now.day);
    final todayDocId = today.toString();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final usageDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .doc(todayDocId);

        final usageDoc = await transaction.get(usageDocRef);
        
        final minutesToAdd = durationSinceLastUpdate.inMinutes;

        if (usageDoc.exists) {
          transaction.update(usageDocRef, {
            'minutes': FieldValue.increment(minutesToAdd),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(usageDocRef, {
            'date': today,
            'minutes': minutesToAdd,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      setState(() {
        todayUsage += durationSinceLastUpdate;
        lastUsageUpdateTime = now;
      });
    } catch (e) {
      debugPrint('Error updating usage: $e');
    }
  }

  Future<void> _applyPenalty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || penaltyApplied) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDocId = today.toString();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final scoreDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('score')
            .doc(todayDocId);

        final scoreDoc = await transaction.get(scoreDocRef);

        if (scoreDoc.exists) {
          transaction.update(scoreDocRef, {
            'score': FieldValue.increment(-2),
            'lastUpdated': FieldValue.serverTimestamp(),
            'penalty': FieldValue.increment(1),
            'reason': 'Left app during session'
          });
        } else {
          transaction.set(scoreDocRef, {
            'score': -2,
            'date': today,
            'lastUpdated': FieldValue.serverTimestamp(),
            'penalty': 1,
            'reason': 'Left app during session',
            'sessions': 0
          });
        }
      });

      setState(() {
        todayScore -= 2;
        points = 0;
        penaltyApplied = true;
      });
    } catch (e) {
      debugPrint('Error applying penalty: $e');
    }
  }

  Future<void> _initializeData() async {
    await _fetchTodayScore();
    await _fetchTodayUsage();
  }

  Future<void> _fetchTodayScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDocId = today.toString();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('score')
          .doc(todayDocId)
          .get();

      if (doc.exists) {
        setState(() {
          todayScore = doc['score'] ?? 0;
        });
      } else {
        setState(() {
          todayScore = 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching today score: $e');
      setState(() {
        todayScore = 0;
      });
    }
  }

  Future<void> _fetchTodayUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDocId = today.toString();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc(todayDocId)
          .get();

      if (doc.exists) {
        setState(() {
          todayUsage = Duration(minutes: doc['minutes'] ?? 0);
        });
      }
    } catch (e) {
      debugPrint('Error fetching today usage: $e');
    }
  }

  Future<void> _createDailyScoreDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDocId = today.toString();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final scoreDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('score')
            .doc(todayDocId);

        final scoreDoc = await transaction.get(scoreDocRef);
        
        if (!scoreDoc.exists) {
          transaction.set(scoreDocRef, {
            'date': today,
            'score': 0,
            'sessions': 0,
            'lastUpdated': FieldValue.serverTimestamp(),
            'penalty': 0,
          });
        }
      });
    } catch (e) {
      debugPrint('Error creating daily score document: $e');
    }
  }

  void _startTimers() {
    if (timerDuration.inSeconds <= 0) return;

    setState(() {
      progress = timerDuration.inSeconds / 10800.0;
      angle = 2 * pi * progress;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timerDuration.inSeconds > 0) {
          timerDuration -= const Duration(seconds: 1);
          progress = timerDuration.inSeconds / 10800.0;
          angle = 2 * pi * progress;
        } else {
          timer.cancel();
          isRunning = false;
          _saveSession();
          _endUsageTracking();
          _updateUserActiveStatus(false);
        }
      });
    });

    pointsTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (isRunning) {
        setState(() => points += 1);
      } else {
        timer.cancel();
      }
    });
  }

  void startTimer() {
    if (isRunning || timerDuration.inSeconds <= 0) return;

    _createDailyScoreDocument();
    _startUsageTracking();
    _updateUserActiveStatus(true);

    setState(() {
      isRunning = true;
      sessionStartTime = DateTime.now();
      lastUsageUpdateTime = DateTime.now();
      progress = timerDuration.inSeconds / 10800.0;
      angle = 2 * pi * progress;
      penaltyApplied = false;
    });

    _cancelTimers();
    _startTimers();
  }

  Future<void> _saveSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || points <= 0) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDocId = today.toString();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final scoreDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('score')
            .doc(todayDocId);

        final scoreDoc = await transaction.get(scoreDocRef);

        if (scoreDoc.exists) {
          transaction.update(scoreDocRef, {
            'score': FieldValue.increment(points),
            'lastUpdated': FieldValue.serverTimestamp(),
            'sessions': FieldValue.increment(1),
          });
        } else {
          transaction.set(scoreDocRef, {
            'score': points,
            'date': today,
            'lastUpdated': FieldValue.serverTimestamp(),
            'sessions': 1,
            'penalty': 0
          });
        }
      });

      setState(() {
        todayScore += points;
        points = 0;
      });
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  void stopTimer() {
    if (!isRunning || showExitConfirmation) return;

    setState(() {
      isRunning = false;
      showExitConfirmation = true;
      exitCountdown = 60;
    });

    _cancelTimers();
    _endUsageTracking();
    _updateUserActiveStatus(false);

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
      points = 0;
      isRunning = false;
    });
    _applyPenalty();
  }

  void _cancelExit() {
    exitConfirmationTimer?.cancel();
    setState(() {
      showExitConfirmation = false;
      isRunning = true;
    });
    startTimer();
    _updateUserActiveStatus(true);
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  String formatUsageTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}h ${twoDigits(duration.inMinutes.remainder(60))}m";
  }

  // Helper method to get localized text
  String _getLocalizedText(String arabicText, String englishText) {
    return userLanguage == 'arabic' ? arabicText : englishText;
  }

  // Helper method to get appropriate font
  TextStyle _getFontStyle({double? fontSize, FontWeight? fontWeight, Color? color}) {
    return userLanguage == 'arabic' 
      ? GoogleFonts.tajawal(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        )
      : GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
  }

  @override
  Widget build(BuildContext context) {
    double size = min(250, MediaQuery.of(context).size.width * 0.7);
    double strokeWidth = 15;
    double radius = size / 2;
    double knobX = radius + (radius - strokeWidth / 2) * cos(angle - pi / 2);
    double knobY = radius + (radius - strokeWidth / 2) * sin(angle - pi / 2);

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getLocalizedText("مش يلا بقا ولا ايه", "Let's Get Started"),
                    style: _getFontStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
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
                      _getLocalizedText("النقاط: $points", "Points: $points"),
                      style: _getFontStyle(
                        fontSize: 20, 
                        color: const Color(0xFFF5B905),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                      _getLocalizedText("اليوم: ${formatUsageTime(todayUsage)}", "Today: ${formatUsageTime(todayUsage)}"),
                      style: _getFontStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onPanUpdate: (details) {
                      if (!isRunning) {
                        double dx = details.localPosition.dx - radius;
                        double dy = details.localPosition.dy - radius;
                        double newAngle = atan2(dy, dx) + pi / 2;
                        newAngle = newAngle < 0 ? newAngle + 2 * pi : newAngle;

                        double newProgress = min(newAngle / (2 * pi), 1.0);
                        int newSeconds = (newProgress * 10800).toInt();

                        setState(() {
                          timerDuration = Duration(seconds: newSeconds);
                          progress = newProgress;
                          angle = newAngle;
                        });
                      }
                    },
                    child: Stack(
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
                            value: progress,
                            strokeWidth: strokeWidth,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
                          ),
                        ),
                        if (!isRunning && !showExitConfirmation)
                          Positioned(
                            left: knobX - 12,
                            top: knobY - 12,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatTime(timerDuration),
                              style: _getFontStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isRunning 
                                ? _getLocalizedText("جاري التركيز...", "Focusing...") 
                                : showExitConfirmation 
                                  ? _getLocalizedText("متوقف", "Paused") 
                                  : _getLocalizedText("اسحب لضبط الوقت", "Drag to set time"),
                              style: _getFontStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
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
                          _getLocalizedText("ابدأ", "Start"), 
                          style: _getFontStyle(color: Colors.white)
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: isRunning ? stopTimer : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _getLocalizedText("توقف", "Stop"), 
                          style: _getFontStyle(color: Colors.white)
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
                      _getLocalizedText("نقاط اليوم: $todayScore", "Today Score: $todayScore"),
                      style: _getFontStyle(
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          if (showExitConfirmation)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  width: min(MediaQuery.of(context).size.width * 0.9, 400),
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
                        color: Color(0xFFF5B905),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _getLocalizedText("جلسة متوقفة", "Session Paused"),
                        style: _getFontStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        _getLocalizedText(
                          "لديك 60 ثانية للعودة أو ستفقد جميع النقاط المكتسبة في هذه الجلسة وتحصل على خصم نقطتين.",
                          "You have 60 seconds to return or you'll lose all points earned in this session and get a 2-point penalty."
                        ),
                        textAlign: TextAlign.center,
                        style: _getFontStyle(
                          fontSize: 16,
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
                          _getLocalizedText(
                            "متبقي $exitCountdown ثانية",
                            "$exitCountdown seconds remaining"
                          ),
                          style: _getFontStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF5B905),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _cancelExit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              _getLocalizedText("استمر", "Continue"),
                              style: _getFontStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _confirmExit,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: Text(
                              _getLocalizedText("انهاء", "End"),
                              style: _getFontStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
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
      ),
    );
  }
}