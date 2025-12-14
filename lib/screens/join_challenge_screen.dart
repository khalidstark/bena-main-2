import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'specific_time_screen.dart';
import 'unspecified_time_screen.dart';
import 'specific_days_screen.dart';
import 'complete_objective_screen.dart';

class JoinChallengeScreen extends StatefulWidget {
  const JoinChallengeScreen({super.key});

  @override
  State<JoinChallengeScreen> createState() => _JoinChallengeScreenState();
}

class _JoinChallengeScreenState extends State<JoinChallengeScreen> {
  final TextEditingController _challengeCodeController = TextEditingController();
  bool isJoining = false;

  Future<void> _navigateToChallengeScreen(Map<String, dynamic> challengeData, String challengeId) async {
    final String challengeType = challengeData['challengeType'] ?? "";
    final String challengeName = challengeData['challengeName'] ?? "Challenge";
    final int days = challengeData['durationDays'] as int? ?? 7;
    final DateTime startTime = (challengeData['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();

    Widget nextScreen;
    switch (challengeType) {
      case 'Specific Time':
        nextScreen = SpecificTimeScreen(
          challengeName: challengeName,
          challengeId: challengeId,
        );
        break;
      case 'Unspecified Time':
        nextScreen = UnspecifiedTimeScreen(
          challengeName: challengeName,
          challengeId: challengeId,
          days: days,
          startTime: startTime,
        );
        break;
      case 'Specific Days':
        nextScreen = SpecificDaysScreen(
          challengeName: challengeName,
          challengeId: challengeId,
        );
        break;
      case 'Complete a Specific Objective':
        nextScreen = CompleteObjectiveScreen(
          challengeName: challengeName,
          challengeId: challengeId,
        );
        break;
      default:
        _showErrorSnackbar("Invalid challenge type");
        return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    }
  }

  Future<void> _joinChallenge() async {
    final String challengeId = _challengeCodeController.text.trim();
    if (challengeId.isEmpty) {
      _showErrorSnackbar("Please enter a challenge code");
      return;
    }

    setState(() => isJoining = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (!doc.exists) {
        _showErrorSnackbar("Invalid challenge code");
        setState(() => isJoining = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final challengeData = doc.data()!;
      final List<dynamic> players = challengeData['players'] ?? [];
      final int playerCount = challengeData['peopleCount'] ?? 2;

      if (players.length >= playerCount) {
        _showErrorSnackbar("Challenge is full");
        setState(() => isJoining = false);
        return;
      }

      // إذا كان المستخدم موجود بالفعل في التحدي، قم بنقله إلى صفحة التحدي مباشرة
      if (players.contains(user.uid)) {
        await _navigateToChallengeScreen(challengeData, challengeId);
        return;
      }

      await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .update({
        'players': FieldValue.arrayUnion([user.uid]),
      });

      _showSuccessSnackbar("Joined challenge successfully!");
      await _navigateToChallengeScreen(challengeData, challengeId);
    } catch (e) {
      debugPrint("Error joining challenge: $e");
      _showErrorSnackbar("Failed to join challenge");
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFFF5B905),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Join Challenge",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFF5B905).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add,
                size: 70,
                color: Color(0xFFF5B905),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Enter Challenge Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Get the code from your friend or challenge creator',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _challengeCodeController,
              decoration: InputDecoration(
                labelText: 'Challenge Code',
                labelStyle: const TextStyle(color: Colors.black54),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.code,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isJoining ? null : _joinChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B905),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isJoining
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
                          Icon(Icons.login, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'JOIN CHALLENGE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _challengeCodeController.dispose();
    super.dispose();
  }
}