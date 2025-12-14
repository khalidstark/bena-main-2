import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsageTracker {
  static DateTime? _startTime;

  /// يتم استدعاؤها عند فتح التطبيق
  static void startSession() {
    _startTime = DateTime.now();
  }

  /// يتم استدعاؤها عند إغلاق التطبيق
  static Future<void> endSession() async {
    if (_startTime == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime endTime = DateTime.now();
    int minutesUsed = endTime.difference(_startTime!).inMinutes;

    // حفظ البيانات في Firestore
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    DocumentReference usageRef = userRef.collection('usage').doc(_getDateKey());

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(usageRef);

      if (snapshot.exists && snapshot.data() != null) {
        int previousMinutes = (snapshot['minutes'] ?? 0) as int;
        transaction.update(usageRef, {'minutes': previousMinutes + minutesUsed});
      } else {
        transaction.set(usageRef, {'minutes': minutesUsed});
      }
    });
  }

  /// تحويل التاريخ إلى مفتاح نصي YYYY-MM-DD
  static String _getDateKey() {
    return DateTime.now().toIso8601String().split('T').first;
  }
}
