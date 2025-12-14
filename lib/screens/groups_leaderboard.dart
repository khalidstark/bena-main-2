import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupsLeaderboardScreen extends StatelessWidget {
  const GroupsLeaderboardScreen({super.key});

  List<String> _splitName(String fullName) {
    final parts = fullName.split(' ');
    if (parts.length <= 1) return [fullName, ''];
    return [
      parts.take(parts.length ~/ 2).join(' '),
      parts.skip(parts.length ~/ 2).join(' ')
    ];
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Groups Leaderboard', 
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            )),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('groups')
            .orderBy('totalScore', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
              ),
            );
          }

          final groups = snapshot.data!.docs;
          final top50Groups = groups.take(50).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top 3 Podium
                if (top50Groups.length >= 3) 
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Top Groups',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTopThree(top50Groups),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Leaderboard List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Leaderboard',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 20),
                      if (top50Groups.length <= 3)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No more groups to display',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: top50Groups.length - 3,
                          separatorBuilder: (context, index) => const Divider(height: 20),
                          itemBuilder: (context, index) {
                            var groupData = top50Groups[index + 3].data() as Map<String, dynamic>;
                            String name = groupData['name'] ?? 'Unknown Group';
                            int score = groupData['totalScore'] ?? 0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5B905).withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 4}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF5B905),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5B905).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$score pts',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF5B905),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopThree(List<QueryDocumentSnapshot> groups) {
    var first = groups[0].data() as Map<String, dynamic>;
    var second = groups[1].data() as Map<String, dynamic>;
    var third = groups[2].data() as Map<String, dynamic>;

    return Column(
      children: [
        // First Place
        _buildTopGroupItem(first, 1),
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Second Place
            _buildTopGroupItem(second, 2),
            const SizedBox(width: 32),
            // Third Place
            _buildTopGroupItem(third, 3),
          ],
        ),
      ],
    );
  }

  Widget _buildTopGroupItem(Map<String, dynamic> group, int rank) {
    final fullName = group['name'] ?? 'Unknown Group';
    final nameParts = _splitName(fullName);
    final score = group['totalScore'] ?? 0;

    // Determine which medal image to use based on rank
    String medalAsset;
    double medalSize;
    double containerWidth;

    switch (rank) {
      case 1:
        medalAsset = 'assets/gold badge.png';
        medalSize = 80;
        containerWidth = 220;
        break;
      case 2:
        medalAsset = 'assets/silver badge.png';
        medalSize = 60;
        containerWidth = 130;
        break;
      case 3:
        medalAsset = 'assets/bronz badge.png';
        medalSize = 60;
        containerWidth = 130;
        break;
      default:
        medalAsset = 'assets/bronz badge.png';
        medalSize = 40;
        containerWidth = 140;
    }

    return Container(
      width: containerWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset(
            medalAsset,
            width: medalSize,
            height: medalSize,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Text(
                nameParts[0],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (nameParts[1].isNotEmpty)
                Text(
                  nameParts[1],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$score points',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}