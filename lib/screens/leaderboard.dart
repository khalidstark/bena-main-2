import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'achievment.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Daily, 1: Weekly, 2: Monthly
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd 00:00:00.000');
  final DateFormat _monthFormat = DateFormat('yyyy-MM');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _currentLanguage = 'english'; // Default language

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    // Get user language preference
    _getUserLanguage();
    
    // Check and award winners when screen loads (for demo purposes)
    // In production, this should be handled by a cloud function
    _checkAndAwardWinners();
  }

  Future<void> _getUserLanguage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentLanguage = userData['lang'] ?? 'english';
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAndAwardWinners() async {
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;
    final currentWeekday = now.weekday;

    // Check if it's 11:59 PM (for demo, you can change the time)
    if (currentHour == 23 && currentMinute == 59) {
      // Award daily winners
      await _awardDailyWinners();
      
      // Check if it's Thursday (weekend starts from Friday)
      if (currentWeekday == DateTime.thursday) {
        await _awardWeeklyWinners();
      }
    }
  }

  Future<void> _awardDailyWinners() async {
    final todayKey = _dateFormat.format(DateTime.now());
    final users = await _firestore.collection('users').get();
    final usersWithScores = await _getUsersWithScores(users.docs, todayKey, 'daily');
    
    // Take top 3 users
    final top3 = usersWithScores.take(3).toList();
    
    // Award points for next day
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowKey = _dateFormat.format(tomorrow);
    
    final batch = _firestore.batch();
    
    for (int i = 0; i < top3.length; i++) {
      final user = top3[i];
      final points = [20, 10, 5][i]; // 20 for 1st, 10 for 2nd, 5 for 3rd
      
      final userRef = _firestore.collection('users').doc(user['id']);
      final scoreRef = userRef.collection('score').doc(tomorrowKey);
      
      batch.set(scoreRef, {
        'score': FieldValue.increment(points),
        'awarded': true,
        'awardType': 'daily',
        'position': i + 1,
        'date': tomorrowKey,
      }, SetOptions(merge: true));
      
      // Add to winner history
      final winnerRef = userRef.collection('winner_history').doc();
      batch.set(winnerRef, {
        'type': 'daily',
        'position': i + 1,
        'points': points,
        'date': tomorrowKey,
        'awardedAt': DateTime.now(),
      });
    }
    
    await batch.commit();
  }

  Future<void> _awardWeeklyWinners() async {
    final weekDates = _getCurrentWeekDates();
    final users = await _firestore.collection('users').get();
    final usersWithScores = await _getUsersWithWeeklyScores(users.docs, weekDates);
    
    // Take top 3 users
    final top3 = usersWithScores.take(3).toList();
    
    final batch = _firestore.batch();
    
    for (int i = 0; i < top3.length; i++) {
      final user = top3[i];
      final points = [30, 20, 10][i]; // 30 for 1st, 20 for 2nd, 10 for 3rd
      
      final userRef = _firestore.collection('users').doc(user['id']);
      
      // Update weekly winner count
      batch.update(userRef, {
        'weekly_wins': FieldValue.increment(1),
        'total_weekly_points': FieldValue.increment(points),
      });
      
      // Add to winner history
      final winnerRef = userRef.collection('winner_history').doc();
      batch.set(winnerRef, {
        'type': 'weekly',
        'position': i + 1,
        'points': points,
        'week_start': weekDates.first,
        'week_end': weekDates.last,
        'awardedAt': DateTime.now(),
      });
      
      // Add points to next week's first day (Friday)
      final nextFriday = _getNextFriday();
      final nextFridayKey = _dateFormat.format(nextFriday);
      final scoreRef = userRef.collection('score').doc(nextFridayKey);
      
      batch.set(scoreRef, {
        'score': FieldValue.increment(points),
        'awarded': true,
        'awardType': 'weekly',
        'position': i + 1,
        'date': nextFridayKey,
      }, SetOptions(merge: true));
    }
    
    await batch.commit();
  }

  DateTime _getNextFriday() {
    final now = DateTime.now();
    int daysToAdd = DateTime.friday - now.weekday;
    if (daysToAdd <= 0) {
      daysToAdd += 7;
    }
    return now.add(Duration(days: daysToAdd));
  }

  List<String> _splitName(String fullName) {
    final parts = fullName.split(' ');
    if (parts.length <= 1) return [fullName, ''];
    return [
      parts.take(parts.length ~/ 2).join(' '),
      parts.skip(parts.length ~/ 2).join(' ')
    ];
  }

  String _getCurrentDateKey() {
    return _dateFormat.format(DateTime.now());
  }

  List<String> _getCurrentWeekDates() {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    DateTime friday;

    if (currentWeekday >= DateTime.friday) {
      friday = now.subtract(Duration(days: currentWeekday - DateTime.friday));
    } else {
      friday = now.subtract(Duration(days: 7 + currentWeekday - DateTime.friday));
    }

    final dates = <String>[];
    for (int i = 0; i < 7; i++) {
      final date = friday.add(Duration(days: i));
      dates.add(_dateFormat.format(date));
    }

    return dates;
  }

  String _getCurrentMonthKey() {
    return _monthFormat.format(DateTime.now());
  }

  // Translation methods
  String _translate(String english, String arabic) {
    return _currentLanguage == 'arabic' ? arabic : english;
  }

  TextStyle _getTextStyle(double fontSize, FontWeight fontWeight, Color color) {
    if (_currentLanguage == 'arabic') {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    } else {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
  }

  // Get avatar emoji based on rank
  String _getAvatarEmoji(int rank, String name) {
    if (rank == 1) return '👑';
    if (rank == 2) return '🎨';
    if (rank == 3) return '🎯';
    if (name == 'Bena') return '🌟';
    if (name == 'Alex') return '🎪';
    if (name == 'Sam') return '🎨';
    if (name == 'Jordan') return '🎭';
    return '👤';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0), // For status bar
          child: Column(
            children: [
              // Custom Header (matching Figma)
              _buildCustomHeader(),
              
              // Tabs (matching Figma)
              _buildFigmaTabs(),
              
              // Leaderboard Content
              Expanded(
                child: _buildLeaderboardContent(currentUserId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaderboardHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translate('Leaderboard Info', 'معلومات المتصدرين'),
            style: _getTextStyle(16, FontWeight.bold, Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_translate('• Daily: Resets at midnight', '• يومي: يتم إعادة الضبط عند منتصف الليل'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
            const SizedBox(height: 8),
            Text(_translate('• Weekly: Friday to Friday', '• أسبوعي: من الجمعة إلى الجمعة'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
            const SizedBox(height: 8),
            Text(_translate('• Monthly: 1st to last day of month', '• شهري: من أول إلى آخر يوم في الشهر'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
            const SizedBox(height: 8),
            Text(_translate('Points are earned by completing tasks and challenges.', 'يتم كسب النقاط من خلال إكمال المهام والتحديات.'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
            const SizedBox(height: 8),
            Text(_translate('Daily winners get bonus points for next day:', 'يحصل الفائزون اليوميون على نقاط مكافأة لليوم التالي:'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
            Text(_translate('🥇 20 points, 🥈 10 points, 🥉 5 points', '🥇 20 نقطة، 🥈 10 نقاط، 🥉 5 نقاط'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
            const SizedBox(height: 8),
            Text(_translate('Weekly winners get bonus points for next week:', 'يحصل الفائزون الأسبوعيون على نقاط مكافأة للأسبوع التالي:'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
            Text(_translate('🥇 30 points, 🥈 20 points, 🥉 10 points', '🥇 30 نقطة، 🥈 20 نقطة، 🥉 10 نقاط'),
                style: _getTextStyle(14, FontWeight.normal, Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_translate('OK', 'موافق'),
                style: _getTextStyle(14, FontWeight.bold, const Color(0xFFF5B905))),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Stack(
        children: [
          // Center title
          Center(
            child: Text(
              _translate('Leaderboard', 'لوحة المتصدرين'),
              style: _getTextStyle(24, FontWeight.w600, Colors.black),
            ),
          ),
          
          // Help button (right side)
          Positioned(
            top: 16,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.help_outline, size: 28),
              onPressed: () {
                _showLeaderboardHelp(context);
              },
            ),
          ),
          
          // Decorative star (left side)
          Positioned(
            top: 32,
            left: 16,
            child: Icon(
              Icons.star,
              size: 16,
              color: Colors.pink[300],
            ),
          ),
          
          // Decorative sparkle (right side)
          Positioned(
            top: 16,
            right: 40,
            child: Icon(
              Icons.stars,
              size: 24,
              color: Colors.yellow[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaTabs() {
    final tabs = [
      _translate('Daily', 'يومي'),
      _translate('Weekly', 'أسبوعي'),
      _translate('Monthly', 'شهري')
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                  _animationController.reset();
                  _animationController.forward();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _selectedTab == index
                      ? const LinearGradient(
                          colors: [Color(0xFFFFF176), Color(0xFFFFD54F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: _selectedTab == index
                      ? [
                          BoxShadow(
                            color: Colors.yellow[300]!.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    tab,
                    style: _getTextStyle(
                      14,
                      FontWeight.w600,
                      _selectedTab == index ? Colors.white : Colors.grey[600]!,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeaderboardContent(String? currentUserId) {
    switch (_selectedTab) {
      case 0: // Daily
        return _buildDailyLeaderboard(currentUserId);
      case 1: // Weekly
        return _buildWeeklyLeaderboard(currentUserId);
      case 2: // Monthly
        return _buildMonthlyLeaderboard(currentUserId);
      default:
        return _buildDailyLeaderboard(currentUserId);
    }
  }

  Widget _buildDailyLeaderboard(String? currentUserId) {
    final todayKey = _getCurrentDateKey();

    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('users').get(),
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
            ),
          );
        }

        final users = usersSnapshot.data!.docs;
        
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getUsersWithScores(users, todayKey, 'daily'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                ),
              );
            }

            final usersWithScores = snapshot.data!;
            
            // Get top 3 users
            List<Map<String, dynamic>> topUsers = [];
            if (usersWithScores.length >= 3) {
              topUsers = usersWithScores.sublist(0, 3);
            } else if (usersWithScores.isNotEmpty) {
              topUsers = List.from(usersWithScores);
              while (topUsers.length < 3) {
                topUsers.add({
                  'id': 'placeholder${topUsers.length}',
                  'name': 'User ${topUsers.length + 1}',
                  'dailyScore': 0,
                });
              }
            }

            // Find current user
            Map<String, dynamic>? currentUser;
            int currentUserRank = 0;
            if (currentUserId != null) {
              for (int i = 0; i < usersWithScores.length; i++) {
                if (usersWithScores[i]['id'] == currentUserId) {
                  currentUser = usersWithScores[i];
                  currentUserRank = i + 1;
                  break;
                }
              }
            }

            // Get other users (starting from rank 4)
            final otherUsers = usersWithScores.length > 3
                ? usersWithScores.sublist(3)
                : [];

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Podium Section
                  _buildPodium(topUsers),
                  
                  // Your Position Card
                  if (currentUser != null)
                    _buildYourPositionCard(currentUser, currentUserRank),
                  
                  // Leaderboard Table Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _translate('Rank', 'الترتيب'),
                          style: _getTextStyle(12, FontWeight.w500, Colors.grey[400]!),
                        ),
                        Text(
                          _translate('User', 'المستخدم'),
                          style: _getTextStyle(12, FontWeight.w500, Colors.grey[400]!),
                        ),
                        Text(
                          _translate('Points', 'النقاط'),
                          style: _getTextStyle(12, FontWeight.w500, Colors.grey[400]!),
                        ),
                      ],
                    ),
                  ),
                  
                  // Leaderboard List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: otherUsers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final user = entry.value;
                        final rank = index + 4;
                        final isCurrentUser = user['id'] == currentUserId;
                        
                        return _buildUserRow(user, rank, isCurrentUser);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> topUsers) {
    if (topUsers.length < 3) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          // Podium Stand
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              Expanded(
                child: _buildPodiumUser(topUsers[0], 2),
              ),
              
              // 1st Place
              Expanded(
                child: _buildPodiumUser(topUsers[1], 1),
              ),
              
              // 3rd Place
              Expanded(
                child: _buildPodiumUser(topUsers[2], 3),
              ),
            ],
          ),
          
          // Floating decorations
          Positioned(
            top: 0,
            left: 32,
            child: Icon(
              Icons.star,
              size: 20,
              color: Colors.yellow[700],
            ),
          ),
          Positioned(
            top: 8,
            right: 48,
            child: Icon(
              Icons.stars,
              size: 16,
              color: Colors.pink[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumUser(Map<String, dynamic> user, int rank) {
    final name = user['name'] ?? 'User';
    final score = user['dailyScore'] ?? 0;
    final avatar = _getAvatarEmoji(rank, name);
    
    // Colors based on rank
    Color gradientColor1;
    Color gradientColor2;
    Color badgeColor;
    Color textColor;
    
    switch (rank) {
      case 1:
        gradientColor1 = const Color(0xFFFFF176);
        gradientColor2 = const Color(0xFFFFD54F);
        badgeColor = const Color(0xFFFFD54F);
        textColor = Colors.white;
        break;
      case 2:
        gradientColor1 = const Color(0xFFE0E0E0);
        gradientColor2 = const Color(0xFFBDBDBD);
        badgeColor = const Color(0xFFBDBDBD);
        textColor = Colors.black;
        break;
      case 3:
        gradientColor1 = const Color(0xFFFFB74D);
        gradientColor2 = const Color(0xFFFF9800);
        badgeColor = const Color(0xFFFF9800);
        textColor = Colors.white;
        break;
      default:
        gradientColor1 = Colors.grey;
        gradientColor2 = Colors.grey;
        badgeColor = Colors.grey;
        textColor = Colors.black;
    }
    
    return Column(
      children: [
        // Avatar with badge
        Stack(
          children: [
            Container(
              width: rank == 1 ? 80 : 64,
              height: rank == 1 ? 80 : 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientColor1, gradientColor2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(rank == 1 ? 40 : 24),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  avatar,
                  style: TextStyle(
                    fontSize: rank == 1 ? 32 : 24,
                  ),
                ),
              ),
            ),
            
            // Rank badge
            if (rank == 1)
              Positioned(
                top: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: Icon(
                    Icons.emoji_events,
                    size: 32,
                    color: Colors.yellow[700],
                  ),
                ),
              ),
            
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientColor2, gradientColor1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    rank == 1 ? Icons.emoji_events : Icons.workspace_premium,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Podium stand
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: rank == 1 ? 48 : 32,
            bottom: 16,
            left: 8,
            right: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientColor1, gradientColor2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Rank number
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: rank == 1 ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Name
              Text(
                name.length > 10 ? '${name.substring(0, 10)}...' : name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Points
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rank == 1 ? Colors.white : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYourPositionCard(Map<String, dynamic> currentUser, int rank) {
    final name = currentUser['name'] ?? 'User';
    final score = currentUser['dailyScore'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF176), Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow[300]!.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Trophy icon background
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              Icons.emoji_events,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          
          // Decorative elements
          Positioned(
            bottom: 8,
            left: 16,
            child: Icon(
              Icons.star,
              size: 12,
              color: Colors.yellow[200],
            ),
          ),
          
          Row(
            children: [
              // Rank circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translate('Your Daily Position', 'موقعك اليومي'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$score ${_translate('points', 'نقطة')}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.yellow[100],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Trophy icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user, int rank, bool isCurrentUser) {
    final name = user['name'] ?? 'User';
    final score = user['dailyScore'] ?? 0;
    final avatar = _getAvatarEmoji(rank, name);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: isCurrentUser
            ? const LinearGradient(
                colors: [Color(0xFFFFF9C4), Color(0xFFFFF3E0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isCurrentUser ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isCurrentUser
            ? Border.all(color: const Color(0xFFFFD54F), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCurrentUser ? const Color(0xFFFFD54F) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Avatar and name
          Row(
            children: [
              Text(
                avatar,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentUser ? Colors.black : Colors.grey[700],
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrentUser ? const Color(0xFFFFD54F) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isCurrentUser
                  ? [
                      BoxShadow(
                        color: Colors.yellow[700]!.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getUsersWithScores(
    List<QueryDocumentSnapshot> users, String dateKey, String scoreType) async {
    final List<Map<String, dynamic>> usersWithScores = [];
    
    for (final user in users) {
      final scoreDoc = await _firestore
          .collection('users')
          .doc(user.id)
          .collection('score')
          .doc(dateKey)
          .get();
      
      final userData = user.data() as Map<String, dynamic>;
      final name = userData['name'] ?? 'Unknown';
      
      int score = 0;
      if (scoreDoc.exists) {
        final dynamic scoreData = scoreDoc.data()?['score'];
        score = (scoreData is num ? scoreData.toInt() : 0);
      }

      usersWithScores.add({
        'id': user.id,
        'name': name,
        '${scoreType}Score': score,
      });
    }

    usersWithScores.sort((a, b) {
      if (a['${scoreType}Score'] != b['${scoreType}Score']) {
        return b['${scoreType}Score'].compareTo(a['${scoreType}Score']);
      }
      return a['name'].compareTo(b['name']);
    });

    return usersWithScores;
  }

  Future<List<Map<String, dynamic>>> _getUsersWithWeeklyScores(
      List<QueryDocumentSnapshot> users, List<String> weekDates) async {
    final List<Map<String, dynamic>> usersWithScores = [];

    for (final user in users) {
      final scoresSnapshot = await _firestore
          .collection('users')
          .doc(user.id)
          .collection('score')
          .where(FieldPath.documentId, whereIn: weekDates)
          .get();

      int weeklyScore = 0;
      for (final doc in scoresSnapshot.docs) {
        final dynamic scoreData = doc.data()['score'];
        weeklyScore += (scoreData is num ? scoreData.toInt() : 0);
      }

      final userData = user.data() as Map<String, dynamic>;
      usersWithScores.add({
        'id': user.id,
        'name': userData['name'] ?? 'Unknown',
        'weeklyScore': weeklyScore,
      });
    }

    usersWithScores.sort((a, b) {
      if (a['weeklyScore'] != b['weeklyScore']) {
        return b['weeklyScore'].compareTo(a['weeklyScore']);
      }
      return a['name'].compareTo(b['name']);
    });

    return usersWithScores;
  }

  Future<List<Map<String, dynamic>>> _getUsersWithMonthlyScores(
      List<QueryDocumentSnapshot> users, String monthKey) async {
    final List<Map<String, dynamic>> usersWithScores = [];

    for (final user in users) {
      final scoresSnapshot = await _firestore
          .collection('users')
          .doc(user.id)
          .collection('score')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '$monthKey-01')
          .where(FieldPath.documentId, isLessThanOrEqualTo: '$monthKey-31')
          .get();

      int monthlyScore = 0;
      for (final doc in scoresSnapshot.docs) {
        final dynamic scoreData = doc.data()['score'];
        monthlyScore += (scoreData is num ? scoreData.toInt() : 0);
      }

      final userData = user.data() as Map<String, dynamic>;
      usersWithScores.add({
        'id': user.id,
        'name': userData['name'] ?? 'Unknown',
        'monthlyScore': monthlyScore,
      });
    }

    usersWithScores.sort((a, b) {
      if (a['monthlyScore'] != b['monthlyScore']) {
        return b['monthlyScore'].compareTo(a['monthlyScore']);
      }
      return a['name'].compareTo(b['name']);
    });

    return usersWithScores;
  }

  Widget _buildWeeklyLeaderboard(String? currentUserId) {
    final weekDates = _getCurrentWeekDates();

    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('users').get(),
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
            ),
          );
        }

        final users = usersSnapshot.data!.docs;
        
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getUsersWithWeeklyScores(users, weekDates),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                ),
              );
            }

            return _buildLeaderboardUI(snapshot.data!, currentUserId, 'weekly');
          },
        );
      },
    );
  }

  Widget _buildMonthlyLeaderboard(String? currentUserId) {
    final monthKey = _getCurrentMonthKey();

    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('users').get(),
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
            ),
          );
        }

        final users = usersSnapshot.data!.docs;
        
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getUsersWithMonthlyScores(users, monthKey),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                ),
              );
            }

            return _buildLeaderboardUI(snapshot.data!, currentUserId, 'monthly');
          },
        );
      },
    );
  }

  Widget _buildLeaderboardUI(
      List<Map<String, dynamic>> usersWithScores, String? currentUserId, String scoreType) {
    // For weekly and monthly, we'll use the same UI structure as daily
    // Get top 3 users
    List<Map<String, dynamic>> topUsers = [];
    if (usersWithScores.length >= 3) {
      topUsers = usersWithScores.sublist(0, 3);
    } else if (usersWithScores.isNotEmpty) {
      topUsers = List.from(usersWithScores);
      while (topUsers.length < 3) {
        topUsers.add({
          'id': 'placeholder${topUsers.length}',
          'name': 'User ${topUsers.length + 1}',
          '${scoreType}Score': 0,
        });
      }
    }

    // Find current user
    Map<String, dynamic>? currentUser;
    int currentUserRank = 0;
    if (currentUserId != null) {
      for (int i = 0; i < usersWithScores.length; i++) {
        if (usersWithScores[i]['id'] == currentUserId) {
          currentUser = usersWithScores[i];
          currentUserRank = i + 1;
          break;
        }
      }
    }

    // Get other users (starting from rank 4)
    final otherUsers = usersWithScores.length > 3
        ? usersWithScores.sublist(3)
        : [];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Podium Section
          _buildPodium(topUsers),
          
          // Your Position Card
          if (currentUser != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF176), Color(0xFFFFD54F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow[300]!.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Trophy icon background
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.emoji_events,
                      size: 80,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  
                  Row(
                    children: [
                      // Rank circle
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '#$currentUserRank',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // User info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _translate('Your ${scoreType.capitalize()} Position', 'موقعك في المتصدرين ${_getArabicScoreType(scoreType)}'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentUser['name'] ?? 'User',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${currentUser['${scoreType}Score']} ${_translate('points', 'نقطة')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.yellow[100],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Trophy icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Leaderboard Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _translate('Rank', 'الترتيب'),
                  style: _getTextStyle(12, FontWeight.w500, Colors.grey[400]!),
                ),
                Text(
                  _translate('User', 'المستخدم'),
                  style: _getTextStyle(12, FontWeight.w500, Colors.grey[400]!),
                ),
                Text(
                  _translate('Points', 'النقاط'),
                  style: _getTextStyle(12, FontWeight.w500, Colors.grey[400]!),
                ),
              ],
            ),
          ),
          
          // Leaderboard List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: otherUsers.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;
                final rank = index + 4;
                final isCurrentUser = user['id'] == currentUserId;
                final name = user['name'] ?? 'User';
                final score = user['${scoreType}Score'] ?? 0;
                final avatar = _getAvatarEmoji(rank, name);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: isCurrentUser
                        ? const LinearGradient(
                            colors: [Color(0xFFFFF9C4), Color(0xFFFFF3E0)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isCurrentUser ? null : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: isCurrentUser
                        ? Border.all(color: const Color(0xFFFFD54F), width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Rank circle
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isCurrentUser ? const Color(0xFFFFD54F) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCurrentUser ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Avatar and name
                      Row(
                        children: [
                          Text(
                            avatar,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentUser ? Colors.black : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Points
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? const Color(0xFFFFD54F) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isCurrentUser
                              ? [
                                  BoxShadow(
                                    color: Colors.yellow[700]!.withOpacity(0.3),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isCurrentUser ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getArabicScoreType(String scoreType) {
    switch (scoreType) {
      case 'daily': return 'اليومي';
      case 'weekly': return 'الأسبوعي';
      case 'monthly': return 'الشهري';
      default: return scoreType;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}