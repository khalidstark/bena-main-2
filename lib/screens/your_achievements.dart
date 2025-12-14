import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class YourAchievementsScreen extends StatelessWidget {
  const YourAchievementsScreen({super.key});

  Future<Map<String, dynamic>?> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
    return null;
  }

  Future<int> _fetchTotalMinutes(String userId) async {
    try {
      QuerySnapshot usageSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('usage')
          .get();

      int totalMinutes = 0;
      for (var doc in usageSnapshot.docs) {
        totalMinutes += (doc['minutes'] as int? ?? 0);
      }
      return totalMinutes;
    } catch (e) {
      print("Error fetching usage data: $e");
      return 0;
    }
  }

  Widget _buildAchievementItem({
    required String imagePath,
    required String label,
    required bool isUnlocked,
    required Color borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isUnlocked ? Colors.white : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUnlocked ? borderColor : Colors.grey,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Image.asset(
                    imagePath,
                    color: isUnlocked ? null : Colors.grey[400],
                    fit: BoxFit.contain,
                  ),
                ),
                if (!isUnlocked)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementRow({
    required String title,
    required List<String> assets,
    required List<String> labels,
    required List<bool> isUnlocked,
    required Color color,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < assets.length; i++)
                _buildAchievementItem(
                  imagePath: assets[i],
                  label: labels[i],
                  isUnlocked: isUnlocked[i],
                  borderColor: color,
                ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (showDivider)
          Divider(
            color: Colors.grey.withOpacity(0.2),
            thickness: 1,
            indent: 40,
            endIndent: 40,
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildStatItem(String label, dynamic value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatsCard({
    required String name,
    required int score,
    required int streakCount,
    required int challengesCompleted,
    required int totalMinutes,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5B905), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: [
            
              _buildStatItem('Streak', '$streakCount days', Icons.local_fire_department, Colors.red),
              const SizedBox(height: 12),
              _buildStatItem('Challenges', challengesCompleted, Icons.flag, Colors.green),
              const SizedBox(height: 12),
              _buildStatItem('Minutes', '$totalMinutes min', Icons.timer, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Your Achievements',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            )),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
            ));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data available'));
          }

          final userData = snapshot.data!;
          final String name = userData['name'] ?? 'Unknown';
          final int score = userData['score'] ?? 0;
          final int streakCount = userData['streakCount'] ?? 0;
          final int challengesCompleted = userData['Challenges completed'] ?? 0;
          final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

          return FutureBuilder<int>(
            future: _fetchTotalMinutes(userId),
            builder: (context, minutesSnapshot) {
              int totalMinutes = minutesSnapshot.data ?? 0;

              final challengeUnlocked = [
                challengesCompleted >= 100,
                challengesCompleted >= 50,
                challengesCompleted >= 20,
              ];

              final minutesUnlocked = [
                totalMinutes >= 3500,
                totalMinutes >= 2000,
                totalMinutes >= 1000,
              ];

              final streakUnlocked = [
                streakCount >= 100,
                streakCount >= 50,
                streakCount >= 20,
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildUserStatsCard(
                      name: name,
                      score: score,
                      streakCount: streakCount,
                      challengesCompleted: challengesCompleted,
                      totalMinutes: totalMinutes,
                    ),
                    
                    _buildAchievementRow(
                      title: 'Challenge Master',
                      assets: [
                        'assets/gold medal.png',
                        'assets/silver medal.png',
                        'assets/bronze medal.png',
                      ],
                      labels: ['100 Challenges', '50 Challenges', '20 Challenges'],
                      isUnlocked: challengeUnlocked,
                      color: const Color(0xFF4CAF50),
                      showDivider: true,
                    ),

                    _buildAchievementRow(
                      title: 'Time Champion',
                      assets: [
                        'assets/gold cup.png',
                        'assets/silver cup.png',
                        'assets/bronze cup.png',
                      ],
                      labels: ['3500 Minutes', '2000 Minutes', '1000 Minutes'],
                      isUnlocked: minutesUnlocked,
                      color: const Color(0xFF2196F3),
                      showDivider: true,
                    ),

                    _buildAchievementRow(
                      title: 'Streak Legend',
                      assets: [
                        'assets/gold badge.png',
                        'assets/silver badge.png',
                        'assets/bronz badge.png',
                      ],
                      labels: ['100 Days', '50 Days', '20 Days'],
                      isUnlocked: streakUnlocked,
                      color: const Color(0xFFF44336),
                      showDivider: false,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}