import 'package:flutter/material.dart';
import 'prayer_page.dart';
import 'tasbeeh_page.dart';
import 'azkar_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Islamic App',
      theme: ThemeData(
        primaryColor: Colors.black,
        colorScheme: ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.amber[700]!,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.amber[700],
          unselectedItemColor: Colors.black,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const IslamicPage(),
    );
  }
}

class IslamicPage extends StatefulWidget {
  const IslamicPage({super.key});

  @override
  State<IslamicPage> createState() => _IslamicPageState();
}

class _IslamicPageState extends State<IslamicPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const PrayerPage(),
    const TasbeehPage(),
    const AzkarPage(), // تم إزالة QuranPage من هنا
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.mosque,
                size: 26,
                color: _currentIndex == 0 ? Colors.amber[700] : Colors.black,
              ),
              label: 'Prayer',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.psychology,
                size: 26,
                color: _currentIndex == 1 ? Colors.amber[700] : Colors.black,
              ),
              label: 'Tasbeeh',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.article,
                size: 26,
                color: _currentIndex == 2 ? Colors.amber[700] : Colors.black,
              ),
              label: 'Azkar',
            ),
          ],
        ),
      ),
    );
  }
}