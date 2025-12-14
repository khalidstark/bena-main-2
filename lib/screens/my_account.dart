import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class MyAccountScreen extends StatefulWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final String? religion;
  final String language;

  const MyAccountScreen({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
    this.religion,
    required this.language,
  });

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> with SingleTickerProviderStateMixin {
  late String name;
  late String email;
  String? photoUrl;
  int score = 0;
  int streakCount = 0;
  Map<String, int> dailyUsage = {};
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isLoading = true;
  late String _language;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  Map<String, Map<String, String>> localizedTexts = {
    'profile': {
      'en': 'My Profile',
      'arabic': 'ملفي الشخصي',
    },
    'points': {
      'en': 'Points',
      'arabic': 'النقاط',
    },
    'streak': {
      'en': 'Streak',
      'arabic': 'المتابعة',
    },
    'days': {
      'en': 'days',
      'arabic': 'أيام',
    },
    'weekly_activity': {
      'en': 'Weekly Activity',
      'arabic': 'النشاط الأسبوعي',
    },
    'learning_hours': {
      'en': 'Learning hours this week',
      'arabic': 'ساعات التعلم هذا الأسبوع',
    },
    'recent_activity': {
      'en': 'Recent Activity',
      'arabic': 'النشاط الأخير',
    },
    'earned_points': {
      'en': 'Earned \$score points',
      'arabic': 'حصلت على \$score نقطة',
    },
    'current_streak': {
      'en': 'Current streak: \$days days',
      'arabic': 'متابعة حالية: \$days يوم',
    },
    'learning_progress': {
      'en': 'Weekly learning progress',
      'arabic': 'تقدم التعلم الأسبوعي',
    },
    'ongoing': {
      'en': 'Ongoing',
      'arabic': 'مستمرة',
    },
    'daily_update': {
      'en': 'Daily update',
      'arabic': 'تحديث يومي',
    },
    'name_updated': {
      'en': 'Name updated successfully!',
      'arabic': 'تم تحديث الاسم بنجاح!',
    },
    'name_update_failed': {
      'en': 'Failed to update name: \$error',
      'arabic': 'فشل في تحديث الاسم: \$error',
    },
    'this_month': {
      'en': 'This month',
      'arabic': 'هذا الشهر',
    },
  };

  String _t(String key) {
    return localizedTexts[key]?[_language]?.replaceAll('\$score', score.toString()).replaceAll('\$days', streakCount.toString()) ?? key;
  }

  @override
  void initState() {
    super.initState();
    
    // تهيئة البيانات من الـ widget
    name = widget.name;
    email = widget.email;
    photoUrl = widget.photoUrl;
    _language = widget.language;
    _nameController.text = name;
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _initializeUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await fetchUserData();
      } catch (e) {
        print('Error initializing user data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        String monthKey = DateFormat('yyyy-MM').format(DateTime.now());
        
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        QuerySnapshot usageDocs = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .get();

        int monthlyScore = await _getUserMonthlyScore(user.uid, monthKey);

        Map<String, int> usageMap = {};
        for (var doc in usageDocs.docs) {
          try {
            DateTime date = DateTime.parse(doc.id);
            String dayOfWeek = DateFormat('EEEE').format(date);
            usageMap[dayOfWeek] = (doc.get('minutes') ?? 0).toInt();
          } catch (e) {
            print('Error parsing usage data: $e');
          }
        }

        setState(() {
          // استخدام البيانات من Firestore إذا كانت متاحة، وإلا استخدام البيانات من الـ widget
          name = userDoc.get('name') ?? name;
          email = userDoc.get('email') ?? email;
          score = monthlyScore;
          streakCount = (userDoc.get('streakCount') ?? 0).toInt();
          dailyUsage = usageMap;
          _nameController.text = name;
          _language = userDoc.get('lang') ?? _language;
          _isLoading = false;
        });
      } catch (e) {
        print('Error fetching user data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<int> _getUserMonthlyScore(String userId, String monthKey) async {
    try {
      final scoresSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('score')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '$monthKey-01')
          .where(FieldPath.documentId, isLessThanOrEqualTo: '$monthKey-31')
          .get();

      int monthlyScore = 0;
      for (final doc in scoresSnapshot.docs) {
        final dynamic scoreData = doc.data()['score'];
        monthlyScore += (scoreData is num ? scoreData.toInt() : 0);
      }

      return monthlyScore;
    } catch (e) {
      print('Error getting monthly score: $e');
      return 0;
    }
  }

  Future<void> _updateName() async {
    if (_nameController.text.isEmpty) return;

    User? user = _auth.currentUser;
    if (user != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Update name in Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'name': _nameController.text});

        // Also update name in Firebase Auth
        await user.updateDisplayName(_nameController.text);
        await user.reload(); // Reload the user to get the updated name

        setState(() {
          name = _nameController.text;
          _isEditingName = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('name_updated'))),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('name_update_failed').replaceAll('\$error', e.toString()))),
        );
      }
    }
  }

  Future<void> _toggleLanguage() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String newLang = _language == 'en' ? 'arabic' : 'en';
      
      // Start animation
      _animationController.reset();
      _animationController.forward();
      
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'lang': newLang});
        
        setState(() {
          _language = newLang;
        });
      } catch (e) {
        print('Error updating language: $e');
      }
    }
  }

  List<FlSpot> getChartData() {
    List<FlSpot> spots = [];
    List<String> days = ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
    
    for (int i = 0; i < days.length; i++) {
      double minutes = (dailyUsage[days[i]] ?? 0).toDouble();
      double hours = minutes / 60.0;
      double displayValue = hours > 5 ? 5 : hours;
      spots.add(FlSpot(i.toDouble(), displayValue));
    }
    return spots;
  }

  Widget _buildText(String text, TextStyle style) {
    return Text(
      text,
      style: GoogleFonts.tajawal(textStyle: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    bool isRTL = _language == 'arabic';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _buildText(
          _t('profile'),
          const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          )
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: _language == 'arabic' 
              ? const Icon(Icons.language, color: Colors.black)
              : const Icon(Icons.translate, color: Colors.black),
          onPressed: _toggleLanguage,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
                    child: photoUrl == null || photoUrl!.isEmpty 
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _isEditingName
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _nameController,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.tajawal(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: _updateName,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _isEditingName = false;
                                  _nameController.text = name;
                                });
                              },
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildText(
                              name,
                              const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              )
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () {
                                setState(() {
                                  _isEditingName = true;
                                });
                              },
                            ),
                          ],
                        ),
                  const SizedBox(height: 5),
                  _buildText(
                    email,
                    TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    )
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(_t('points'), "$score", Icons.star, Colors.amber),
                      _buildStatCard(_t('streak'), "$streakCount ${_t('days')}", Icons.local_fire_department, Colors.red),
                    ],
                  ),
                ],
              ),
            ),

            // Weekly Activity Chart
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildText(
                    _t('weekly_activity'),
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )
                  ),
                  const SizedBox(height: 10),
                  _buildText(
                    _t('learning_hours'),
                    TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    )
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 5,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value == 5) {
                                  return _buildText(
                                    _language == 'arabic' ? "٥+" : "5+",
                                    TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    )
                                  );
                                }
                                return _buildText(
                                  "${value.toInt()}h",
                                  TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  )
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                List<String> daysEn = ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"];
                                List<String> daysarabic = ["السبت", "الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"];
                                int index = value.toInt();
                                if (index >= 0 && index < daysEn.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: _buildText(
                                      _language == 'arabic' ? daysarabic[index] : daysEn[index],
                                      TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      )
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.withOpacity(0.2))),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: getChartData(),
                            isCurved: true,
                            color: const Color(0xFFF5B905),
                            barWidth: 4,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: const Color(0xFFF5B905),
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF5B905).withOpacity(0.4),
                                  const Color(0xFFF5B905).withOpacity(0.1),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Recent Activity
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildText(
                    _t('recent_activity'),
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )
                  ),
                  const SizedBox(height: 15),
                  _buildActivityItem(Icons.star, _t('earned_points'), _t('this_month')),
                  _buildActivityItem(Icons.assignment_turned_in, _t('current_streak'), _t('ongoing')),
                  _buildActivityItem(Icons.timer, _t('learning_progress'), _t('daily_update')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildText(
                title,
                TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                )
              ),
              _buildText(
                value,
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5B905).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFF5B905)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildText(
                  title,
                  const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )
                ),
                const SizedBox(height: 2),
                _buildText(
                  time,
                  TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  )
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }
}