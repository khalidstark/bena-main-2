import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أذكار المسلم',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Lateef',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 20.0),
          bodyMedium: TextStyle(fontSize: 16.0),
          bodySmall: TextStyle(fontSize: 14.0),
        ),
      ),
      home: const AzkarPage(),
    );
  }
}

class AzkarPage extends StatefulWidget {
  const AzkarPage({super.key});

  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  late DateTime _lastResetDate;

  List<Map<String, dynamic>> morningAzkar = [
    {
      'text': 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'morning_1',
    },
    {
      'text': 'اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ، لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ، لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ، مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ، يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ، وَلاَ يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء، وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ، وَلاَ يَؤُودُهُ حِفْظُهُمَا، وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      'count': 1,
      'reference': 'آية الكرسي - البقرة 255',
      'initialCount': 1,
      'id': 'morning_2',
    },
    {
      'text': 'قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
      'count': 3,
      'reference': 'سورة الإخلاص',
      'initialCount': 3,
      'id': 'morning_3',
    },
    {
      'text': 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
      'count': 3,
      'reference': 'سورة الفلق',
      'initialCount': 3,
      'id': 'morning_4',
    },
    {
      'text': 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ، مَلِكِ النَّاسِ، إِلَهِ النَّاسِ، مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ، الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ، مِنَ الْجِنَّةِ وَ النَّاسِ',
      'count': 3,
      'reference': 'سورة الناس',
      'initialCount': 3,
      'id': 'morning_5',
    },
    {
      'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'morning_6',
    },
    {
      'text': 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'morning_7',
    },
    {
      'text': 'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'morning_8',
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلاَئِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لاَ إِلَهَ إِلاَّ أَنْتَ وَحْدَكَ لاَ شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
      'count': 4,
      'reference': '',
      'initialCount': 4,
      'id': 'morning_9',
    },
    {
      'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ: عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
      'count': 3,
      'reference': '',
      'initialCount': 3,
      'id': 'morning_10',
    },
    {
      'text': 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لاَ إِلَهَ إِلاَّ أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ، وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لاَ إِلَهَ إِلاَّ أَنْتَ',
      'count': 3,
      'reference': '',
      'initialCount': 3,
      'id': 'morning_11',
    },
    {
      'text': 'حَسْبِيَ اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
      'count': 7,
      'reference': '',
      'initialCount': 7,
      'id': 'morning_12',
    },
    {
      'text': 'أَصْبَحْنَا عَلَى فِطْرَةِ الإِسْلاَمِ، وَعَلَى كَلِمَةِ الإِخْلاَصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'morning_13',
    },
    {
      'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      'count': 100,
      'reference': '',
      'initialCount': 100,
      'id': 'morning_14',
    },
    {
      'text': 'لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      'count': 10,
      'reference': '',
      'initialCount': 10,
      'id': 'morning_15',
    },
  ];

  List<Map<String, dynamic>> eveningAzkar = [
    {
      'text': 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'evening_1',
    },
    {
      'text': 'اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ، لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ، لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ، مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ، يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ، وَلاَ يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء، وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ، وَلاَ يَؤُودُهُ حِفْظُهُمَا، وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      'count': 1,
      'reference': 'آية الكرسي - البقرة 255',
      'initialCount': 1,
      'id': 'evening_2',
    },
    {
      'text': 'قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
      'count': 3,
      'reference': 'سورة الإخلاص',
      'initialCount': 3,
      'id': 'evening_3',
    },
    {
      'text': 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
      'count': 3,
      'reference': 'سورة الفلق',
      'initialCount': 3,
      'id': 'evening_4',
    },
    {
      'text': 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ، مَلِكِ النَّاسِ، إِلَهِ النَّاسِ، مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ، الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ، مِنَ الْجِنَّةِ وَ النَّاسِ',
      'count': 3,
      'reference': 'سورة الناس',
      'initialCount': 3,
      'id': 'evening_5',
    },
    {
      'text': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'evening_6',
    },
    {
      'text': 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'evening_7',
    },
    {
      'text': 'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'evening_8',
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلاَئِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لاَ إِلَهَ إِلاَّ أَنْتَ وَحْدَكَ لاَ شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
      'count': 4,
      'reference': '',
      'initialCount': 4,
      'id': 'evening_9',
    },
    {
      'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ: عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
      'count': 3,
      'reference': '',
      'initialCount': 3,
      'id': 'evening_10',
    },
    {
      'text': 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لاَ إِلَهَ إِلاَّ أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ، وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لاَ إِلَهَ إِلاَّ أَنْتَ',
      'count': 3,
      'reference': '',
      'initialCount': 3,
      'id': 'evening_11',
    },
    {
      'text': 'حَسْبِيَ اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
      'count': 7,
      'reference': '',
      'initialCount': 7,
      'id': 'evening_12',
    },
    {
      'text': 'أَمْسَيْنَا عَلَى فِطْرَةِ الإِسْلاَمِ، وَعَلَى كَلِمَةِ الإِخْلاَصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'evening_13',
    },
    {
      'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      'count': 100,
      'reference': '',
      'initialCount': 100,
      'id': 'evening_14',
    },
    {
      'text': 'لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      'count': 10,
      'reference': '',
      'initialCount': 10,
      'id': 'evening_15',
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ العَفْوَ وَالعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ العَفْوَ وَالعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي، وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ، وَمِنْ خَلْفِي، وَعَنْ يَمِينِي، وَعَنْ شِمَالِي، وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي',
      'count': 1,
      'reference': '',
      'initialCount': 1,
      'id': 'evening_16',
    },
  ];

  @override
  void initState() {
    super.initState();
    _lastResetDate = DateTime.now();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (_user == null) return;

    final docRef = _firestore
        .collection('azkar')
        .doc(_user!.uid)
        .collection('daily_azkar')
        .doc(_getCurrentDate());

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      setState(() {
        _updateAzkarList(morningAzkar, data!['morning'] ?? {});
        _updateAzkarList(eveningAzkar, data['evening'] ?? {});
        _lastResetDate = (data['last_reset'] as Timestamp?)?.toDate() ?? DateTime.now();
      });
    } else {
      await _resetAllCounts();
    }
  }

  void _updateAzkarList(List<Map<String, dynamic>> azkarList, Map<String, dynamic> data) {
    for (var azkar in azkarList) {
      if (data.containsKey(azkar['id'])) {
        azkar['count'] = data[azkar['id']] ?? azkar['initialCount'];
      }
    }
  }

  Future<void> _decrementCounter(List<Map<String, dynamic>> azkarList, int index) async {
    if (_user == null || azkarList[index]['count'] <= 0) return;

    final today = DateTime.now();
    if (!_isSameDay(today, _lastResetDate)) {
      await _resetAllCounts();
      return;
    }

    setState(() {
      azkarList[index]['count']--;
    });

    await _updateFirebaseAzkar(azkarList, azkarList[index]['id']);
  }

  Future<void> _resetCounters(List<Map<String, dynamic>> azkarList) async {
    if (_user == null) return;

    setState(() {
      for (var azkar in azkarList) {
        azkar['count'] = azkar['initialCount'];
      }
    });

    await _updateFirebaseAzkar(azkarList);
  }

  Future<void> _resetAllCounts() async {
    if (_user == null) return;

    final now = DateTime.now();
    setState(() {
      for (var azkar in morningAzkar) {
        azkar['count'] = azkar['initialCount'];
      }
      for (var azkar in eveningAzkar) {
        azkar['count'] = azkar['initialCount'];
      }
      _lastResetDate = now;
    });

    final docRef = _firestore
        .collection('azkar')
        .doc(_user!.uid)
        .collection('daily_azkar')
        .doc(_getCurrentDate());

    final morningData = _prepareAzkarData(morningAzkar);
    final eveningData = _prepareAzkarData(eveningAzkar);

    final data = {
      'last_reset': Timestamp.fromDate(now),
      'morning': morningData,
      'evening': eveningData,
    };

    await docRef.set(data);
  }

  Map<String, dynamic> _prepareAzkarData(List<Map<String, dynamic>> azkarList) {
    final data = <String, dynamic>{};
    for (var azkar in azkarList) {
      data[azkar['id']] = azkar['count'];
    }
    return data;
  }

  Future<void> _updateFirebaseAzkar(List<Map<String, dynamic>> azkarList, [String? specificId]) async {
    if (_user == null) return;

    final docRef = _firestore
        .collection('azkar')
        .doc(_user!.uid)
        .collection('daily_azkar')
        .doc(_getCurrentDate());

    final isMorning = azkarList == morningAzkar;
    final fieldName = isMorning ? 'morning' : 'evening';

    if (specificId != null) {
      // Update specific azkar only
      final azkar = azkarList.firstWhere((a) => a['id'] == specificId);
      await docRef.set({
        fieldName: {specificId: azkar['count']},
        'last_reset': Timestamp.fromDate(_lastResetDate),
      }, SetOptions(merge: true));
    } else {
      // Update all azkar in the list
      final data = _prepareAzkarData(azkarList);
      await docRef.set({
        fieldName: data,
        'last_reset': Timestamp.fromDate(_lastResetDate),
      }, SetOptions(merge: true));
    }
  }

  String _getCurrentDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/IMG_8678.JPG'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Title
                Text(
                  'أذكار الصباح والمساء',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                // Morning Azkar Section
                _buildAzkarSection(
                  context,
                  title: 'أذكار الصباح',
                  azkar: morningAzkar,
                  onReset: () => _resetCounters(morningAzkar),
                ),
                
                const SizedBox(height: 40),
                
                // Evening Azkar Section
                _buildAzkarSection(
                  context,
                  title: 'أذكار المساء',
                  azkar: eveningAzkar,
                  onReset: () => _resetCounters(eveningAzkar),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAzkarSection(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> azkar,
    required VoidCallback onReset,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.yellow,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: onReset,
              tooltip: 'إعادة العدادات',
            ),
          ],
        ),
        const SizedBox(height: 15),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: azkar.length,
          separatorBuilder: (context, index) => const Divider(color: Colors.white54, height: 20),
          itemBuilder: (context, index) {
            final zikr = azkar[index];
            return InkWell(
              onTap: () => _decrementCounter(azkar, index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      zikr['text'],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.right,
                      
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (zikr['reference'] != null && zikr['reference'].isNotEmpty)
                          Text(
                            zikr['reference'],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: zikr['count'] > 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: zikr['count'] > 0 ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            zikr['count'] > 0 ? '${zikr['count']} مرة' : 'تم',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: zikr['count'] > 0 ? Colors.green : Colors.red,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}