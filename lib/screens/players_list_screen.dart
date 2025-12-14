import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayersListScreen extends StatelessWidget {
  final String challengeId;
  final String challengeName;
  final List<String> playerIds;
  
  const PlayersListScreen({
    super.key, 
    required this.challengeId,
    required this.challengeName,
    required this.playerIds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Players in $challengeName',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey[850]!, Colors.grey[900]!],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey[100]!, Colors.grey[200]!],
                ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('challenges')
              .doc(challengeId)
              .collection('players')
              .orderBy('score', descending: true) // ترتيب تنازلي حسب النتيجة
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              );
            }

            final players = snapshot.data!.docs;
            
            if (players.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 60,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No players yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: players.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final playerData = players[index].data() as Map<String, dynamic>;
                final userName = playerData['username'] ?? 'Unknown';
                final userScore = playerData['score'] ?? 0;
                final minutes = playerData['minutes'] ?? 0;
                final photoUrl = playerData['photoUrl'];
                
                
                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: isDarkMode 
                          ? Colors.grey[700] 
                          : Colors.grey[200],
                      backgroundImage: photoUrl != null 
                          ? NetworkImage(photoUrl) 
                          : null,
                      child: photoUrl == null
                          ? Icon(
                              Icons.person,
                              color: isDarkMode 
                                  ? Colors.grey[300] 
                                  : Colors.grey[600],
                            )
                          : null,
                    ),
                    title: Text(
                      userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        const SizedBox(height: 4),
                        Text(
                          '$minutes minutes',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(userScore, isDarkMode),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$userScore pts',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      // Add player profile navigation if needed
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getScoreColor(int score, bool isDarkMode) {
    if (score >= 1000) return Colors.purple;
    if (score >= 500) return Colors.indigo;
    if (score >= 250) return Colors.blue;
    if (score >= 100) return Colors.green;
    if (score >= 50) return Colors.lightGreen;
    if (score >= 25) return Colors.amber[700]!;
    if (score >= 10) return Colors.orange;
    return isDarkMode ? Colors.red[700]! : Colors.red;
  }

  Widget _buildShimmerLoader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  color: Colors.grey.withOpacity(0.2),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 14,
                  color: Colors.grey.withOpacity(0.2),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}