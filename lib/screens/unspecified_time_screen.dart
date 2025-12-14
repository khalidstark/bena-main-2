import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'players_list_screen.dart';

class UnspecifiedTimeScreen extends StatefulWidget {
  final String challengeId;
  final String challengeName;
  final int days;
  final DateTime startTime;

  const UnspecifiedTimeScreen({
    super.key,
    required this.challengeId,
    required this.challengeName,
    required this.days,
    required this.startTime,
  });

  @override
  _UnspecifiedTimeScreenState createState() => _UnspecifiedTimeScreenState();
}

class _UnspecifiedTimeScreenState extends State<UnspecifiedTimeScreen> 
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;
  Timer? _minuteTimer;
  Timer? _countdownTimer;
  Duration _elapsedTime = Duration.zero;
  Duration _remainingTime = Duration.zero;
  int _score = 0;
  int _savedScore = 0;
  int _unsavedPoints = 0;
  int _minutesParticipated = 0;
  int _pendingMinutes = 0; // الدقائق التي لم يتم تسجيلها بعد
  bool _isRunning = false;
  bool _isInitialized = false;
  bool _isExiting = false;
  bool _isBackground = false;
  bool _isChallengeEnded = false;
  Set<String> _recordedMinutes = {}; // لتتبع الدقائق المسجلة بالفعل

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChallengeAndPlayerData();
    _calculateRemainingTime();
    _startCountdownTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isBackground = true;
      _pauseTimer();
      _saveUnsavedPoints();
      _saveMinutesToFirestore();
      _updateIsActiveStatus(false); // Update IsActive when app goes to background
    } else if (state == AppLifecycleState.resumed) {
      _isBackground = false;
      if (_isInitialized && !_isExiting && !_isRunning && !_isChallengeEnded) {
        _resumeTimer();
      }
    }
  }

  @override
  void dispose() {
    _isExiting = true;
    _timer?.cancel();
    _minuteTimer?.cancel();
    _countdownTimer?.cancel();
    _saveUnsavedPoints();
    _saveMinutesToFirestore();
    _updateIsActiveStatus(false); // Update IsActive when screen is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _updateIsActiveStatus(bool isActive) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'IsActive': isActive,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating IsActive status: $e');
    }
  }

  void _calculateRemainingTime() {
    final endTime = widget.startTime.add(Duration(days: widget.days));
    final now = DateTime.now();
    
    if (now.isAfter(endTime)) {
      setState(() {
        _remainingTime = Duration.zero;
        _isChallengeEnded = true;
      });
      _pauseTimer();
    } else {
      setState(() {
        _remainingTime = endTime.difference(now);
        _isChallengeEnded = false;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isBackground) {
        _calculateRemainingTime();
        if (mounted) setState(() {});
      }
    });
  }

  String _formatFirestoreDate(DateTime date) {
    return '${DateFormat('yyyy-MM-dd').format(date)} 00:00:00.000';
  }

  String _formatMinuteKey(DateTime date) {
    return DateFormat('yyyy-MM-dd-HH-mm').format(date);
  }

  Future<void> _saveMinutesToFirestore() async {
    final user = _auth.currentUser;
    if (user == null || _pendingMinutes == 0) return;

    try {
      final currentDate = _formatFirestoreDate(DateTime.now());
      final minutesToSave = _pendingMinutes;
      
      final userUsageRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc(currentDate);

      await userUsageRef.set({
        'minutes': FieldValue.increment(minutesToSave),
        'date': currentDate,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final playerRef = _firestore.collection('challenges')
          .doc(widget.challengeId)
          .collection('players')
          .doc(user.uid);

      await playerRef.update({
        'minutes': FieldValue.increment(minutesToSave),
        'lastActive': FieldValue.serverTimestamp(),
      });

      print('Saved $minutesToSave minutes to usage collection');

      if (mounted) {
        setState(() {
          _minutesParticipated += minutesToSave;
          _pendingMinutes = 0;
        });
      }
    } catch (e) {
      print('Error saving minutes: $e');
    }
  }

  Future<void> _initializeChallengeAndPlayerData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to participate')),
        );
      }
      return;
    }

    if (widget.challengeId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid challenge')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final playerRef = _firestore.collection('challenges')
          .doc(widget.challengeId)
          .collection('players')
          .doc(user.uid);

      final playerDoc = await playerRef.get();

      if (playerDoc.exists) {
        final savedScore = playerDoc.data()?['score'] ?? 0;
        final unsaved = playerDoc.data()?['unsavedPoints'] ?? 0;
        final minutes = playerDoc.data()?['minutes'] ?? 0;
        
        setState(() {
          _score = savedScore + unsaved;
          _savedScore = savedScore;
          _unsavedPoints = unsaved;
          _minutesParticipated = minutes;
          _elapsedTime = Duration(minutes: minutes);
        });
      } else {
        await playerRef.set({
          'score': 0,
          'minutes': 0,
          'unsavedPoints': 0,
          'username': user.displayName ?? 'Anonymous',
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'userId': user.uid,
        });
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: ${e.toString()}')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveUnsavedPoints() async {
    if (_unsavedPoints == 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final currentDate = _formatFirestoreDate(DateTime.now());
      final pointsToSave = _unsavedPoints;
      
      final playerRef = _firestore.collection('challenges')
          .doc(widget.challengeId)
          .collection('players')
          .doc(user.uid);

      await playerRef.update({
        'score': FieldValue.increment(pointsToSave),
        'unsavedPoints': 0,
        'lastActive': FieldValue.serverTimestamp(),
      });

      final userScoreRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('score')
          .doc(currentDate);

      await userScoreRef.set({
        'score': FieldValue.increment(pointsToSave),
        'date': currentDate,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _savedScore += pointsToSave;
          _unsavedPoints = 0;
        });
      }

      print('Saved $pointsToSave points');
    } catch (e) {
      print('Error saving points: $e');
    }
  }

  void _startTimer() {
    if (_isRunning || _isChallengeEnded) return;

    setState(() {
      _isRunning = true;
    });

    // Update IsActive status in Firebase when starting
    _updateIsActiveStatus(true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isBackground && mounted) {
        setState(() {
          _elapsedTime = _elapsedTime + const Duration(seconds: 1);
        });
      }
    });

    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isBackground) {
        _recordMinuteParticipation();
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;

    _timer?.cancel();
    _minuteTimer?.cancel();
    
    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }

    // Update IsActive status in Firebase when pausing
    _updateIsActiveStatus(false);
    _updateLastActiveTime();
  }

  void _resumeTimer() {
    if (_isRunning || _isBackground || _isChallengeEnded) return;
    _startTimer();
  }

  Future<void> _recordMinuteParticipation() async {
    final now = DateTime.now();
    final minuteKey = _formatMinuteKey(now);
    
    // تجنب تسجيل نفس الدقيقة أكثر من مرة
    if (_recordedMinutes.contains(minuteKey)) {
      return;
    }

    _recordedMinutes.add(minuteKey);
    
    // زيادة النقاط والدقائق المؤقتة
    if (mounted) {
      setState(() {
        _score++;
        _unsavedPoints++;
        _pendingMinutes++;
      });
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final playerRef = _firestore.collection('challenges')
          .doc(widget.challengeId)
          .collection('players')
          .doc(user.uid);

      await playerRef.update({
        'unsavedPoints': _unsavedPoints,
        'lastActive': FieldValue.serverTimestamp(),
      });

      // حفظ كل 5 دقائق أو عند الخروج
      if (_unsavedPoints >= 5) {
        await _saveUnsavedPoints();
      }

      // حفظ الدقائق كل 10 دقائق أو عند الخروج
      if (_pendingMinutes >= 10) {
        await _saveMinutesToFirestore();
      }
    } catch (e) {
      print('Error recording minute: $e');
    }
  }

  Future<void> _updateLastActiveTime() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final playerRef = _firestore.collection('challenges')
          .doc(widget.challengeId)
          .collection('players')
          .doc(user.uid);

      await playerRef.update({
        'lastActive': FieldValue.serverTimestamp(),
        'unsavedPoints': _unsavedPoints,
      });
    } catch (e) {
      print('Error updating last active: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatCountdown(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '$days days ${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildTimeCard(String title, String time, String subtitle, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'Monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = widget.days > 0 
        ? (widget.days - _remainingTime.inDays) / widget.days
        : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Challenge Progress',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.black.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellow),
                  minHeight: 20,
                  borderRadius: BorderRadius.circular(10),
                ),
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.days - _remainingTime.inDays} of ${widget.days} days completed',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Your Stats',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Total Points', '$_score', Icons.emoji_events),
                _buildStatItem('Unsaved Points', '$_unsavedPoints', Icons.save_alt),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Saved Points', '$_savedScore', Icons.check_circle),
                _buildStatItem('Minutes', '$_minutesParticipated', Icons.timer),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Pending Mins', '$_pendingMinutes', Icons.access_time),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.yellow[600], size: 30),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isRunning && !_isChallengeEnded)
            ElevatedButton(
              onPressed: _startTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Start',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (_isRunning && !_isChallengeEnded)
            ElevatedButton(
              onPressed: _pauseTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Pause',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _isExiting = true;
              });
              _pauseTimer();
              await _saveUnsavedPoints();
              await _saveMinutesToFirestore();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.exit_to_app, size: 24),
                SizedBox(width: 8),
                Text(
                  'Exit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 4,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading Challenge...',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.challengeName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayersListScreen(
                    challengeId: widget.challengeId,
                    challengeName: widget.challengeName, 
                    playerIds: [],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildTimeCard(
              'Time Remaining',
              _formatCountdown(_remainingTime),
              'Ends: ${DateFormat('MMM d, yyyy').format(widget.startTime.add(Duration(days: widget.days)))}',
              Colors.white,
            ),
            _buildTimeCard(
              'Elapsed Time',
              _formatDuration(_elapsedTime),
              'Started: ${DateFormat('MMM d, yyyy').format(widget.startTime)}',
              Colors.white,
            ),
            _buildProgressCard(),
            _buildScoreCard(),
            _buildControlButtons(),
            if (_isChallengeEnded)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Challenge has ended!',
                  style: TextStyle(
                    color: Colors.yellow[600],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'Note: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: 'You earn 1 point for every minute the timer is running. '
                                'Make sure to pause when not actively participating. '
                                'Minutes are saved every 10 minutes or when you exit.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}