import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:proft/screens/players_list_screen.dart';

class CompleteObjectiveScreen extends StatefulWidget {
  final String challengeId;
  final String challengeName;
  
  const CompleteObjectiveScreen({
    super.key, 
    required this.challengeId, 
    required this.challengeName,
  });

  @override
  _CompleteObjectiveScreenState createState() => _CompleteObjectiveScreenState();
}

class _CompleteObjectiveScreenState extends State<CompleteObjectiveScreen> with WidgetsBindingObserver {
  late Future<DocumentSnapshot> _challengeFuture;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;
  Timer? _appStateTimer;
  Timer? _syncTimer;
  Timer? _pointsTimer;
  Duration _duration = Duration.zero;
  Duration _selectedDuration = Duration.zero;
  bool _isAdmin = false;
  bool _isStarted = false;
  DateTime? _startTime;
  bool _isSurrendering = false;
  bool _isAppInForeground = true;
  bool _isPlayerBlocked = false;
  bool _challengeCompleted = false;
  int _earnedPoints = 0;
  StreamSubscription<DocumentSnapshot>? _challengeSubscription;
  int _playerCount = 0;
  final TextEditingController _objectiveNameController = TextEditingController();
  String _currentObjectiveName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChallenge();
    _startSyncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _appStateTimer?.cancel();
    _syncTimer?.cancel();
    _pointsTimer?.cancel();
    _challengeSubscription?.cancel();
    _objectiveNameController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeChallenge() async {
    _challengeFuture = _getChallengeData();
    await _checkIfPlayerBlocked();
    if (!_isPlayerBlocked) {
      await _checkAdminStatus();
      await _addPlayerToChallenge();
      _listenToChallengeUpdates();
    }
    _startAppStateMonitor();
  }

  void _listenToChallengeUpdates() {
    _challengeSubscription = _firestore
        .collection('challenges')
        .doc(widget.challengeId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        final isActive = data['isActive'] ?? false;
        final duration = data['duration'] ?? 0;
        final startTime = data['startTime']?.toDate();
        final players = List<String>.from(data['players'] ?? []);
        final objectiveName = data['objectiveName'] ?? '';
        
        setState(() {
          _playerCount = players.length;
          _currentObjectiveName = objectiveName;
        });

        if (isActive && !_isStarted && startTime != null) {
          final now = DateTime.now();
          final elapsed = now.difference(startTime);
          final remaining = Duration(seconds: duration) - elapsed;

          if (remaining.inSeconds > 0) {
            setState(() {
              _isStarted = true;
              _duration = remaining;
              _startTime = startTime;
            });

            _startTimer();
            _startPointsTimer();
          }
        }
      }
    });
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isStarted && mounted) {
        _syncChallengeTime();
      }
    });
  }

  void _startPointsTimer() {
    _pointsTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_isStarted && !_challengeCompleted && mounted) {
        final user = _auth.currentUser;
        if (user == null) return;

        setState(() {
          _earnedPoints += 1;
        });

        await _firestore.collection('users').doc(user.uid).update({
          'tempChallengePoints': FieldValue.increment(1),
        });
      }
    });
  }

  Future<void> _syncChallengeTime() async {
    final challengeRef = _firestore.collection('challenges').doc(widget.challengeId);
    final challengeDoc = await challengeRef.get();
    
    if (challengeDoc.exists && mounted) {
      final data = challengeDoc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] ?? false;
      final duration = data['duration'] ?? 0;
      final startTime = data['startTime']?.toDate();

      if (isActive && startTime != null) {
        final now = DateTime.now();
        final elapsed = now.difference(startTime);
        final remaining = Duration(seconds: duration) - elapsed;

        if (remaining.inSeconds <= 0 && !_challengeCompleted) {
          await _completeChallenge();
        } else if (remaining.inSeconds > 0) {
          setState(() {
            _duration = remaining;
          });
        }
      }
    }
  }

  Future<void> _completeChallenge() async {
    if (_challengeCompleted) return;
    
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'score': FieldValue.increment(_earnedPoints),
      'tempChallengePoints': FieldValue.delete(),
      'Challenges completed': FieldValue.increment(1),
    });

    await _removePlayerFromChallenge();

    if (mounted) {
      setState(() {
        _challengeCompleted = true;
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _checkIfPlayerBlocked() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final challengeDoc = await _getChallengeData();
    if (!challengeDoc.exists) return;

    final data = challengeDoc.data() as Map<String, dynamic>;
    final blockPlayers = List<String>.from(data['blockPlayers'] ?? []);
    
    if (blockPlayers.contains(user.uid) && mounted) {
      setState(() {
        _isPlayerBlocked = true;
      });
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (mounted) {
      setState(() {
        _isAppInForeground = state == AppLifecycleState.resumed;
      });
    }

    if (state != AppLifecycleState.resumed && _isStarted) {
      _handleAppBackgrounded();
    }
  }

  void _startAppStateMonitor() {
    _appStateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isAppInForeground && _isStarted && mounted) {
        _handleAppBackgrounded();
      }
    });
  }

  Future<void> _handleAppBackgrounded() async {
    if (_isSurrendering || !mounted || _challengeCompleted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!_isAppInForeground && mounted && _isStarted) {
      await _penalizeAndExit();
    }
  }

  Future<DocumentSnapshot> _getChallengeData() async {
    return await _firestore
        .collection('challenges')
        .doc(widget.challengeId)
        .get();
  }

  Future<void> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final challengeDoc = await _getChallengeData();
    if (!challengeDoc.exists) return;

    final data = challengeDoc.data() as Map<String, dynamic>;
    if (mounted) {
      setState(() {
        _isAdmin = data['createdBy'] == user.uid;
      });
    }
  }

  Future<void> _addPlayerToChallenge() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final challengeRef = _firestore
        .collection('challenges')
        .doc(widget.challengeId);

    await _firestore.runTransaction((transaction) async {
      final challengeDoc = await transaction.get(challengeRef);
      if (!challengeDoc.exists) return;

      final data = challengeDoc.data() as Map<String, dynamic>;
      final players = List<String>.from(data['players'] ?? []);
      final blockPlayers = List<String>.from(data['blockPlayers'] ?? []);

      if (blockPlayers.contains(user.uid)) {
        if (mounted) {
          setState(() {
            _isPlayerBlocked = true;
          });
        }
        return;
      }

      if (!players.contains(user.uid)) {
        players.add(user.uid);
        transaction.update(challengeRef, {
          'players': players,
        });
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (mounted) {
        setState(() {
          if (_duration.inSeconds > 0) {
            _duration = Duration(seconds: _duration.inSeconds - 1);
          } else {
            _timer?.cancel();
            if (!_challengeCompleted) {
              _completeChallenge();
            }
          }
        });
      }
    });
  }

  Future<void> _startChallenge() async {
    if (_selectedDuration.inSeconds <= 0 || _objectiveNameController.text.isEmpty) return;
    
    if (mounted) {
      setState(() {
        _isStarted = true;
        _duration = _selectedDuration;
        _startTime = DateTime.now();
        _currentObjectiveName = _objectiveNameController.text;
      });
    }

    final challengeRef = _firestore
        .collection('challenges')
        .doc(widget.challengeId);

    await challengeRef.update({
      'startTime': FieldValue.serverTimestamp(),
      'duration': _selectedDuration.inSeconds,
      'isActive': true,
      'objectiveName': _objectiveNameController.text,
    });

    _startTimer();
    _startPointsTimer();
  }

  Future<void> _addToBlockList() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final challengeRef = _firestore
        .collection('challenges')
        .doc(widget.challengeId);

    await _firestore.runTransaction((transaction) async {
      final challengeDoc = await transaction.get(challengeRef);
      if (!challengeDoc.exists) return;

      final data = challengeDoc.data() as Map<String, dynamic>;
      final blockPlayers = List<String>.from(data['blockPlayers'] ?? []);
      
      if (!blockPlayers.contains(user.uid)) {
        blockPlayers.add(user.uid);
        transaction.update(challengeRef, {
          'blockPlayers': blockPlayers,
        });
      }
    });
  }

  Future<void> _removePlayerFromChallenge() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final challengeRef = _firestore
        .collection('challenges')
        .doc(widget.challengeId);

    await _firestore.runTransaction((transaction) async {
      final challengeDoc = await transaction.get(challengeRef);
      if (!challengeDoc.exists) return;

      final data = challengeDoc.data() as Map<String, dynamic>;
      final players = List<String>.from(data['players'] ?? []);
      
      if (players.contains(user.uid)) {
        players.remove(user.uid);
        transaction.update(challengeRef, {
          'players': players,
        });
      }
    });
  }

  Future<void> _penalizeAndExit() async {
    if (_isSurrendering || !mounted || _challengeCompleted) return;
    
    if (mounted) {
      setState(() {
        _isSurrendering = true;
      });
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'tempChallengePoints': FieldValue.delete(),
        'Challenges withdrawn': FieldValue.increment(1),
        'score': FieldValue.increment(-10),
      });

      await _addToBlockList();
      await _removePlayerFromChallenge();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Error in penalizeAndExit: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSurrendering = false;
        });
      }
    }
  }

  Future<void> _surrenderChallenge() async {
    await _penalizeAndExit();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Widget _buildDurationPicker() {
    return TimePickerSpinner(
      is24HourMode: true,
      normalTextStyle: const TextStyle(
        fontSize: 24,
        color: Colors.grey,
        fontWeight: FontWeight.w300,
      ),
      highlightedTextStyle: const TextStyle(
        fontSize: 28,
        color: Color(0xFFF5B905),
        fontWeight: FontWeight.bold,
      ),
      spacing: 30,
      itemHeight: 60,
      isForce2Digits: true,
      minutesInterval: 1,
      onTimeChange: (time) {
        if (mounted) {
          setState(() {
            final hours = time.hour.clamp(0, 9);
            _selectedDuration = Duration(
              hours: hours,
              minutes: time.minute,
              seconds: 0,
            );
          });
        }
      },
    );
  }

  Future<List<String>> _getPlayerIds() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .get();
      
      final players = doc.data()?['players'] as List<dynamic>? ?? [];
      return players.map((id) => id.toString()).toList();
    } catch (e) {
      debugPrint('Error fetching player IDs: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlayerBlocked) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Access Denied',
            style: TextStyle(color: Colors.black)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  size: 50,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'You are blocked from this challenge',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please contact the challenge admin',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (_isStarted && !_isSurrendering && !_challengeCompleted) {
          await _penalizeAndExit();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
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
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5B905).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group),
              ),
              onPressed: () async {
                final playerIds = await _getPlayerIds();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlayersListScreen(
                      challengeId: widget.challengeId,
                      playerIds: playerIds,
                      challengeName: widget.challengeName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: _challengeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFF5B905)),
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 50, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text(
                      'Challenge not found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5B905),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              );
            }

            final challenge = snapshot.data!;
            final data = challenge.data() as Map<String, dynamic>;
            final isActive = data['isActive'] ?? false;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isAdmin && !_isStarted) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.flag,
                            size: 40,
                            color: Color(0xFFF5B905),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Set Your Objective',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Define what you want to achieve',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _objectiveNameController,
                      decoration: InputDecoration(
                        labelText: 'Objective Name',
                        labelStyle: const TextStyle(color: Colors.black54),
                        prefixIcon: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.edit,
                            color: Color(0xFFF5B905),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFF5B905),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.timer,
                            size: 40,
                            color: Color(0xFFF5B905),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Set Challenge Duration',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Maximum 9 hours',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _buildDurationPicker(),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5B905).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _formatDuration(_selectedDuration),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.group, color: Color(0xFFF5B905)),
                          const SizedBox(width: 10),
                          Text(
                            '$_playerCount player${_playerCount != 1 ? 's' : ''} joined',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedDuration.inSeconds > 0 && 
                                  _objectiveNameController.text.isNotEmpty
                            ? _startChallenge 
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5B905),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'START CHALLENGE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You can start this challenge alone',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (!_isAdmin && !_isStarted) ...[
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        size: 60,
                        color: Color(0xFFF5B905),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      '00:00:00',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Waiting for host to start the challenge',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You will earn 1 point every minute',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  if (_isStarted || isActive) ...[
                    if (_currentObjectiveName.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          _currentObjectiveName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF5B905),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 40),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF5B905), Color(0xFFFFD700)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatDuration(_duration),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_earnedPoints > 0) ...[
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.green),
                            const SizedBox(width: 10),
                            Text(
                              'Earned: $_earnedPoints points',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSurrendering ? null : _surrenderChallenge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSurrendering
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning_amber_outlined),
                                  SizedBox(width: 10),
                                  Text(
                                    'SURRENDER (-10 points)',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'Warning: Closing the app will be considered surrender and will deduct 10 points',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}