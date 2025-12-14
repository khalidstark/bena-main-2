import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proft/screens/login_screens/login_screen.dart';
import 'package:proft/screens/my_offers.dart';
import '../home_page.dart';
import 'my_account.dart';
import 'leaderboard.dart';
import 'challenges_screen.dart';
import 'your_achievements.dart';
import 'chat_screen.dart';
import 'prizes_screen.dart';
import 'announcements.dart';
import 'groups_leaderboard.dart';
import 'my_streak.dart';
import 'islamic_page.dart';
import 'homework.dart'; // تأكد من استيراد صفحة الواجبات

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  String userName = "Loading...";
  String? photoUrl;
  String? religion;
  String language = "english";
  bool isMister = false; // إضافة متغير لتتبع حالة المستخدم
  final double _drawerHeaderHeight = 200.0;
  final double _menuIconSize = 24.0;
  final double _avatarRadius = 42.0;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _setupUserUpdates();
  }

  /// إعداد تحديثات بيانات المستخدم
  void _setupUserUpdates() {
    _fetchUserData();
    
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchUserData();
    });
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            userName = snapshot.data()?['name'] ?? 'No Name';
            photoUrl = snapshot.data()?['photoUrl'];
            religion = snapshot.data()?['religion'];
            language = snapshot.data()?['lang'] ?? 'english';
            isMister = snapshot.data()?['mister'] ?? false; // تحديث حالة المستخدم
          });
        }
      });
    }
  }

  /// جلب بيانات المستخدم من Firestore
  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (docSnapshot.exists && mounted) {
          setState(() {
            userName = docSnapshot.data()?['name'] ?? 'No Name';
            photoUrl = docSnapshot.data()?['photoUrl'];
            religion = docSnapshot.data()?['religion'];
            language = docSnapshot.data()?['lang'] ?? 'english';
            isMister = docSnapshot.data()?['mister'] ?? false; // تحديث حالة المستخدم
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      if (mounted) {
        setState(() {
          userName = "Guest User";
        });
      }
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  /// دالة لترجمة النصوص بناءً على اللغة المحددة
  String _translate(String englishText, String arabicText) {
    return language == 'arabic' ? arabicText : englishText;
  }

  /// بناء عنصر قائمة في الدراور
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _navigateToPage(context, page);
          },
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? Colors.grey[800]!.withOpacity(0.3)
                    : Colors.grey[200]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 22,
              ),
            ),
            title: Text(
              title,
              style: language == 'arabic'
                ? GoogleFonts.tajawal(
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  )
                : TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  /// التنقل إلى صفحة مع تأثير انتقال
  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  /// بناء رأس الدراور
  Widget _buildDrawerHeader(bool isDarkMode) {
    return Container(
      height: _drawerHeaderHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Colors.amber[800]!, Colors.amber[600]!]
              : [const Color(0xFFF5B905), const Color(0xFFF5B905)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.0,
                ),
              ),
              child: CircleAvatar(
                radius: _avatarRadius,
                backgroundColor: Colors.white,
                child: photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          photoUrl!,
                          width: _avatarRadius * 2 - 4,
                          height: _avatarRadius * 2 - 4,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(
                                Icons.person,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: _avatarRadius,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: language == 'arabic'
                ? GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.3),
                      )
                    ],
                  )
                : TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.3),
                      )
                    ],
                  ),
            ),
            // عرض بادج "مستر" إذا كان المستخدم من نوع mister
           
          ],
        ),
      ),
    );
  }

  /// بناء عنصر تسجيل الخروج
  Widget _buildLogoutTile(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListTile(
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.logout_rounded, 
            color: isDarkMode ? Colors.white : Colors.black
          ),
        ),
        title: Text(
          _translate('Logout', 'تسجيل الخروج'),
          style: language == 'arabic'
            ? GoogleFonts.tajawal(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              )
            : TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        onTap: _handleLogout,
      ),
    );
  }

  /// معالجة تسجيل الخروج
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  LoginScreen()),
      );
    }
  }

  /// بناء قائمة عناصر الدراور
  Widget _buildDrawerMenuItems(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.account_circle_rounded,
            title: _translate('My Account', 'حسابي'),
            page: MyAccountScreen(
              name: userName,
              email: FirebaseAuth.instance.currentUser?.email ?? "",
              photoUrl: photoUrl,
              religion: religion,
              language: language,
            ),
          ),
          // إضافة عنصر الواجبات فقط إذا كان المستخدم mister
          if (isMister)
            _buildMenuItem(
              context,
              icon: Icons.assignment_rounded,
              title: _translate('Homework', 'الواجبات'),
              page: const Homework(),
            ),
          _buildMenuItem(
            context,
            icon: Icons.leaderboard_rounded,
            title: _translate('Leaderboard', 'لوحة المتصدرين'),
            page: const LeaderboardScreen(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.emoji_events_rounded,
            title: _translate('Your Achievements', 'إنجازاتك'),
            page: const YourAchievementsScreen(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.chat_bubble_rounded,
            title: _translate('Groups', 'المجموعات'),
            page: const GroupListScreen(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.card_giftcard_rounded,
            title: _translate('Prizes', 'الجوائز'),
            page: PrizesScreen(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.groups_rounded,
            title: _translate('Groups Leaderboard', 'تصنيف المجموعات'),
            page: const GroupsLeaderboardScreen(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.announcement_rounded,
            title: _translate('Announcements', 'الإعلانات'),
            page: const AnnouncementsScreen(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.sell,
            title: _translate('offers', 'العروض'),
            page: const OffersPage(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.local_fire_department_rounded,
            title: _translate('My Streak', 'سلسلة تقدمي'),
            page: const MyStreakScreen(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final drawerWidth = MediaQuery.of(context).size.width * 0.78;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        title: Text(
          _translate('Home', 'الرئيسية'),
          style: language == 'arabic' 
            ? GoogleFonts.tajawal(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              )
            : TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: isDarkMode ? Colors.white : Colors.black,
              size: _menuIconSize,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              // This would trigger the theme change in the parent widget
              // You'll need to pass the toggleTheme function from main.dart
            },
          ),
        ],
      ),
      drawer: Drawer(
        width: drawerWidth,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF121212) : Colors.white,
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildDrawerHeader(isDarkMode),
              const SizedBox(height: 24),
              _buildDrawerMenuItems(isDarkMode),
              Divider(
                height: 24,
                thickness: 0.5,
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                indent: 16,
                endIndent: 16,
              ),
              _buildLogoutTile(isDarkMode),
            ],
          ),
        ),
      ),
      body: const HomePage(),
    );
  }
}