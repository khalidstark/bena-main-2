import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const AchievementScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  String _language = 'english'; // Default language

  @override
  void initState() {
    super.initState();
    _fetchLanguage();
  }

  Future<void> _fetchLanguage() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _language = userData['lang'] ?? 'english';
        });
      }
    } catch (e) {
      print("Error fetching language: $e");
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
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

  Future<Map<String, int>> _fetchWeeklyUsage(String userId) async {
    try {
      // Get dates for the past 7 days
      DateTime now = DateTime.now();
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      
      QuerySnapshot usageSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('usage')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(weekAgo))
          .where(FieldPath.documentId, isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(now))
          .get();

      Map<String, int> usageMap = {};
      for (var doc in usageSnapshot.docs) {
        try {
          DateTime date = DateTime.parse(doc.id);
          String dayOfWeek = DateFormat('EEEE').format(date);
          usageMap[dayOfWeek] = (doc.get('minutes') ?? 0).toInt();
        } catch (e) {
          print('Error parsing usage data: $e');
        }
      }
      return usageMap;
    } catch (e) {
      print('Error fetching weekly usage: $e');
      return {};
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
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? Colors.black : Colors.grey,
            ),
            textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
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
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
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
          Expanded(
            child: Column(
              crossAxisAlignment: _language == 'arabic' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
                ),
                Text(
                  value.toString(),
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
                ),
              ],
            ),
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
    final userProgressText = _language == 'arabic' ? 'تقدم المستخدم' : 'User Progress';
    final daysText = _language == 'arabic' ? 'أيام' : 'days';
    final minutesText = _language == 'arabic' ? 'دقيقة' : 'min';
    
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
        crossAxisAlignment: _language == 'arabic' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            userProgressText,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black.withOpacity(0.8),
            ),
            textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              _buildStatItem(
                _language == 'arabic' ? 'المتابعة اليومية' : 'Streak', 
                _language == 'arabic' ? '$streakCount $daysText' : '$streakCount days', 
                Icons.local_fire_department, 
                Colors.red,
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                _language == 'arabic' ? 'التحديات' : 'Challenges', 
                challengesCompleted, 
                Icons.flag, 
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                _language == 'arabic' ? 'الدقائق' : 'Minutes', 
                _language == 'arabic' ? '$totalMinutes $minutesText' : '$totalMinutes min', 
                Icons.timer, 
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityChart(Map<String, int> dailyUsage) {
    final weeklyActivityText = _language == 'arabic' ? 'النشاط الأسبوعي' : 'Weekly Activity';
    final learningHoursText = _language == 'arabic' ? 'ساعات التعلم هذا الأسبوع' : 'Learning hours this week';
    
    List<String> englishDays = ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"];
    List<String> arabicDays = ["السبت", "الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"];
    List<String> days = _language == 'arabic' ? arabicDays : englishDays;
    
    return Container(
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
        crossAxisAlignment: _language == 'arabic' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            weeklyActivityText,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 10),
          Text(
            learningHoursText,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: _language == 'arabic' ? TextAlign.right : TextAlign.left,
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
                          return Text(
                            _language == 'arabic' ? "٥+" : "5+",
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey,
                            )
                          );
                        }
                        return Text(
                          _language == 'arabic' ? "${value.toInt()}س" : "${value.toInt()}h",
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.grey,
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
                        int index = value.toInt();
                        if (index >= 0 && index < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[index],
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: Colors.grey,
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
                    spots: _getChartData(dailyUsage),
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
    );
  }

  List<FlSpot> _getChartData(Map<String, int> dailyUsage) {
    List<FlSpot> spots = [];
    
    List<String> englishDays = ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
    List<String> arabicDays = ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
    
    List<String> days = _language == 'arabic' ? arabicDays : englishDays;
    
    for (int i = 0; i < days.length; i++) {
      double minutes = (dailyUsage[days[i]] ?? 0).toDouble();
      double hours = minutes / 60.0;
      double displayValue = hours > 5 ? 5 : hours;
      spots.add(FlSpot(i.toDouble(), displayValue));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _language == 'arabic' ? 'إنجازات ${widget.userName}' : '${widget.userName}\'s Achievements',
          style: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
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
            return Center(
              child: Text(
                _language == 'arabic' ? 'خطأ في تحميل البيانات' : 'Error loading data',
                style: GoogleFonts.cairo(),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                _language == 'arabic' ? 'لا توجد بيانات متاحة' : 'No data available',
                style: GoogleFonts.cairo(),
              ),
            );
          }

          final userData = snapshot.data!;
          final int score = userData['score'] ?? 0;
          final int streakCount = userData['streakCount'] ?? 0;
          final int challengesCompleted = userData['Challenges completed'] ?? 0;

          // Define texts based on language
          final challengeMasterText = _language == 'arabic' ? 'سيد التحديات' : 'Challenge Master';
          final timeChampionText = _language == 'arabic' ? 'بطل الوقت' : 'Time Champion';
          final streakLegendText = _language == 'arabic' ? 'أسطورة المتابعة' : 'Streak Legend';
          
          final challengeLabels = _language == 'arabic' 
            ? ['100 تحدياً', '50 تحدياً', '20 تحدياً'] 
            : ['100 Challenges', '50 Challenges', '20 Challenges'];
          
          final minutesLabels = _language == 'arabic'
            ? ['3500 دقيقة', '2000 دقيقة', '1000 دقيقة']
            : ['3500 Minutes', '2000 Minutes', '1000 Minutes'];
          
          final streakLabels = _language == 'arabic'
            ? ['100 يوم', '50 يوم', '20 يوم']
            : ['100 Days', '50 Days', '20 Days'];

          return FutureBuilder<int>(
            future: _fetchTotalMinutes(widget.userId),
            builder: (context, minutesSnapshot) {
              int totalMinutes = minutesSnapshot.data ?? 0;

              return FutureBuilder<Map<String, int>>(
                future: _fetchWeeklyUsage(widget.userId),
                builder: (context, usageSnapshot) {
                  Map<String, int> weeklyUsage = usageSnapshot.data ?? {};

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
                    child:  Column(
                        children: [
                          _buildUserStatsCard(
                            name: widget.userName,
                            score: score,
                            streakCount: streakCount,
                            challengesCompleted: challengesCompleted,
                            totalMinutes: totalMinutes,
                          ),
                          
                          _buildWeeklyActivityChart(weeklyUsage),
                          
                          _buildAchievementRow(
                            title: challengeMasterText,
                            assets: [
                              'assets/gold medal.png',
                              'assets/silver medal.png',
                              'assets/bronze medal.png',
                            ],
                            labels: challengeLabels,
                            isUnlocked: challengeUnlocked,
                            color: const Color(0xFF4CAF50),
                            showDivider: true,
                          ),

                          _buildAchievementRow(
                            title: timeChampionText,
                            assets: [
                              'assets/gold cup.png',
                              'assets/silver cup.png',
                              'assets/bronze cup.png',
                            ],
                            labels: minutesLabels,
                            isUnlocked: minutesUnlocked,
                            color: const Color(0xFF2196F3),
                            showDivider: true,
                          ),

                          _buildAchievementRow(
                            title: streakLegendText,
                            assets: [
                              'assets/gold badge.png',
                              'assets/silver badge.png',
                              'assets/bronz badge.png',
                            ],
                            labels: streakLabels,
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
          );
        },
      ),
    );
  }
}