import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TasbeehPage extends StatefulWidget {
  const TasbeehPage({super.key});

  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage> {
  final List<TasbeehItem> _tasbeehat = [
    TasbeehItem(text: 'سبحان الله', count: 30, id: 'subhan_allah'),
    TasbeehItem(text: 'الحمد لله', count: 30, id: 'alhamdulillah'),
    TasbeehItem(text: 'لا إله إلا الله', count: 30, id: 'la_ilaha_illa_allah'),
    TasbeehItem(text: 'الله أكبر', count: 30, id: 'allah_akbar'),
    TasbeehItem(text: 'لا حول ولا قوة إلا بالله', count: 30, id: 'la_hawla_wa_la_quwwata_illa_billah'),
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  late DateTime _lastResetDate;

  @override
  void initState() {
    super.initState();
    _lastResetDate = DateTime.now();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (_user == null) return;

    final docRef = _firestore
        .collection('islamic')
        .doc(_user.uid)
        .collection('tasbeehat')
        .doc(_getCurrentDate());

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      setState(() {
        for (var tasbeeh in _tasbeehat) {
          if (data!.containsKey(tasbeeh.id)) {
            tasbeeh.count = data[tasbeeh.id] ?? 30;
          }
        }
        _lastResetDate = (data?['last_reset'] as Timestamp?)?.toDate() ?? DateTime.now();
      });
    } else {
      await _resetAllCounts();
    }
  }

  Future<void> _decrementCount(int index) async {
    if (_user == null || _tasbeehat[index].count <= 0) return;

    final today = DateTime.now();
    if (!_isSameDay(today, _lastResetDate)) {
      await _resetAllCounts();
      return;
    }

    setState(() {
      _tasbeehat[index].count--;
    });

    await _updateFirebaseCount(index);
  }

  Future<void> _resetCount(int index) async {
    if (_user == null) return;

    setState(() {
      _tasbeehat[index].count = 30;
    });

    await _updateFirebaseCount(index);
  }

  Future<void> _resetAllCounts() async {
    if (_user == null) return;

    final now = DateTime.now();
    setState(() {
      for (var tasbeeh in _tasbeehat) {
        tasbeeh.count = 30;
      }
      _lastResetDate = now;
    });

    final docRef = _firestore
        .collection('islamic')
        .doc(_user.uid)
        .collection('tasbeehat')
        .doc(_getCurrentDate());

    final data = {
      'last_reset': Timestamp.fromDate(now),
      for (var tasbeeh in _tasbeehat) tasbeeh.id: tasbeeh.count,
    };

    await docRef.set(data);
  }

  Future<void> _updateFirebaseCount(int index) async {
    if (_user == null) return;

    final docRef = _firestore
        .collection('islamic')
        .doc(_user.uid)
        .collection('tasbeehat')
        .doc(_getCurrentDate());

    await docRef.set({
      _tasbeehat[index].id: _tasbeehat[index].count,
      'last_reset': Timestamp.fromDate(_lastResetDate),
    }, SetOptions(merge: true));
  }

  String _getCurrentDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // الخلفية
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/IMG_8679.JPG'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // المحتوى
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'التسبيح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView.separated(
                  itemCount: _tasbeehat.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _buildTasbeehCard(index);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasbeehCard(int index) {
    return GestureDetector(
      onTap: () => _decrementCount(index),
      onLongPress: () => _resetCount(index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _tasbeehat[index].text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.right,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _tasbeehat[index].count > 0
                    ? Colors.amber.withOpacity(0.7)
                    : Colors.green.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_tasbeehat[index].count}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TasbeehItem {
  final String text;
  final String id;
  int count;

  TasbeehItem({required this.text, required this.count, required this.id});
}
