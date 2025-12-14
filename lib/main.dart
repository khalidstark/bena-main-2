import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // استيراد حزمة SharedPreferences
import 'package:proft/firebase_options.dart';
import 'package:proft/screens/login_screens/login_screen.dart';
import 'package:proft/screens/navigation_page.dart';
import 'package:proft/splash_screen.dart'; // استيراد شاشة البداية (الفيديو)
import 'package:proft/usage_tracker.dart'; // استيراد كود تتبع الاستخدام

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // بدء تسجيل مدة الاستخدام عند تشغيل التطبيق
  UsageTracker.startSession();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool isFirstLaunch = true; // متغير لتحديد ما إذا كان التطبيق قد تم تشغيله من قبل

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFirstLaunch(); // التحقق من أول تشغيل للتطبيق
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
 
  // دالة للتحقق من أول تشغيل للتطبيق
  Future<void> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunchPref = prefs.getBool('isFirstLaunch') ?? true;

    setState(() {
      isFirstLaunch = isFirstLaunchPref;
    });

    if (isFirstLaunch) {
      // إذا كان أول تشغيل، قم بتعيين القيمة إلى false
      await prefs.setBool('isFirstLaunch', false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // عند خروج التطبيق أو وضعه في الخلفية يتم تسجيل المدة المستخدمة
      UsageTracker.endSession();
    } else if (state == AppLifecycleState.resumed) {
      // استئناف الجلسة عند العودة إلى التطبيق
      UsageTracker.startSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proft App',
      debugShowCheckedModeBanner: false, // إخفاء شارة DEBUG
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5B905), // لون خلفية التطبيق
        useMaterial3: true, // تفعيل تصميم Material 3
        fontFamily: 'plo', // تعيين الخط الأساسي للتطبيق
      ),
      initialRoute: '/', // تشغيل شاشة البداية أولاً
      routes: {
        '/': (context) => const SplashScreen(), // شاشة البداية (الفيديو)
        '/login': (context) => LoginScreen(), // شاشة تسجيل الدخول
        '/home': (context) => const NavigationPage(), // الصفحة الرئيسية
      },
      onGenerateRoute: (settings) {
        // توجيه المستخدم بناءً على حالة أول تشغيل للتطبيق
        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (context) {
              if (isFirstLaunch) {
                return const SplashScreen(); // إذا كان أول تشغيل، عرض شاشة البداية
              } else {
                return const NavigationPage(); // إذا لم يكن أول تشغيل، توجيه إلى الصفحة الرئيسية
              }
            },
          );
        }
        return null;
      },
    );
  }
}