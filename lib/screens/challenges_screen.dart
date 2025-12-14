import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:proft/screens/unspecified_time_screen.dart';
import 'package:proft/screens/create_challenge_screen.dart';
import 'package:proft/screens/join_challenge_screen.dart';
import 'package:proft/screens/navigation_page.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(minutes: 1), (Timer t) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _navigateToChallengeScreen(String challengeId, String challengeName) async {
    try {
      // Fetch challenge document to get required parameters
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (challengeDoc.exists) {
        final challengeData = challengeDoc.data() as Map<String, dynamic>;
        
        // Extract required parameters with default values
        final int days = challengeData['durationDays'] as int? ?? 7;
        final DateTime startTime = (challengeData['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
        final String challengeType = challengeData['challengeType'] ?? 'Unspecified Time';

        if (!mounted) return;

        // Navigate to appropriate screen based on challenge type
        Widget nextScreen;
        switch (challengeType) {
          case 'Unspecified Time':
            nextScreen = UnspecifiedTimeScreen(
              challengeId: challengeId,
              challengeName: challengeName,
              days: days,
              startTime: startTime,
            );
            break;
          // Add cases for other challenge types if needed
          default:
            nextScreen = UnspecifiedTimeScreen(
              challengeId: challengeId,
              challengeName: challengeName,
              days: days,
              startTime: startTime,
            );
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChallengeOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B905).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle_outline, 
                    size: 28, 
                    color: Color(0xFFF5B905)),
                ),
                title: const Text(
                  'Create Challenge',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateChallengeScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 20, thickness: 1, indent: 20, endIndent: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add, 
                    size: 28, 
                    color: Colors.blue),
                ),
                title: const Text(
                  'Join Challenge',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JoinChallengeScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Challenges', 
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          )),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NavigationPage()),
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Challenges',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5B905).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Public',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('challenges')
                      .where('isFull', isEqualTo: false)
                      .where('isPublic', isEqualTo: true)
                      .where('isActive', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFF5B905)),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              "No challenges available",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Create or join a challenge to get started!",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final challenge = doc.data() as Map<String, dynamic>;
                        final String challengeName =
                            challenge['challengeName'] ?? "Unnamed Challenge";
                        final int peopleCount =
                            challenge['peopleCount'] ?? 0;
                        final String challengeType = 
                            challenge['challengeType'] ?? 'Unspecified Time';
                            
                        final dynamic playersField = challenge['players'];
                        int currentPlayers = 0;
                        
                        if (playersField is List) {
                          currentPlayers = playersField.where((player) => player != null && player.toString().isNotEmpty).length;
                        } else if (playersField is Map) {
                          currentPlayers = playersField.values.where((player) => player != null && player.toString().isNotEmpty).length;
                        }
                            
                        final int slotsLeft = peopleCount - currentPlayers;

                        if (peopleCount == 1) return const SizedBox();

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _navigateToChallengeScreen(doc.id, challengeName);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5B905).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.emoji_events,
                                    color: Color(0xFFF5B905),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        challengeName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        challengeType,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: slotsLeft > 0
                                        ? const Color(0xFFF5B905).withOpacity(0.2)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    slotsLeft > 0 ? '$slotsLeft slots left' : 'Full',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: slotsLeft > 0 ? Colors.black : Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF5B905),
        elevation: 4,
        onPressed: () {
          _showChallengeOptions(context);
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFF5B905), Color(0xFFFFD700)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }
}