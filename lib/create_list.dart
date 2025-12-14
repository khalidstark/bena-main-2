import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateTask extends StatefulWidget {
  const CreateTask({super.key});

  @override
  State<CreateTask> createState() => _CreateTaskState();
}

class _CreateTaskState extends State<CreateTask> {
  final TextEditingController _taskNameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 13, minute: 0); // 1:00 PM
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 30); // 3:30 PM
  String _selectedCategory = 'important task';
  bool _remindMe = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _currentLanguage = 'english'; // اللغة الافتراضية

  final Map<String, Map<String, String>> _translations = {
    'english': {
      'create': 'Create',
      'new_task': 'New Task',
      'task_name': 'Task Name',
      'enter_task_name': 'Enter task name',
      'date': 'Date',
      'time': 'Time',
      'category': 'Category',
      'remind_me': 'Remind me',
      'create_task': 'Create Task',
      'important_task': 'important task',
      'normal_task': 'normal task',
      'please_enter_task_name': 'Please enter a task name',
      'user_not_authenticated': 'User not authenticated',
      'task_created_successfully': 'Task created successfully',
      'error_creating_task': 'Error creating task: ',
    },
    'arabic': {
      'create': 'إنشاء',
      'new_task': 'مهمة جديدة',
      'task_name': 'اسم المهمة',
      'enter_task_name': 'أدخل اسم المهمة',
      'date': 'التاريخ',
      'time': 'الوقت',
      'category': 'الفئة',
      'remind_me': 'تذكير',
      'create_task': 'إنشاء المهمة',
      'important_task': 'مهمة مهمة',
      'normal_task': 'مهمة عادية',
      'please_enter_task_name': 'يرجى إدخال اسم المهمة',
      'user_not_authenticated': 'المستخدم غير مصرح به',
      'task_created_successfully': 'تم إنشاء المهمة بنجاح',
      'error_creating_task': 'خطأ في إنشاء المهمة: ',
    },
  };

  final Map<String, IconData> _categories = {
    'important task': Icons.priority_high,
    'normal task': Icons.task,
  };

  // أوقات الصلاة الثابتة (يمكن استبدالها بقيم ديناميكية من API)
  final Map<String, TimeOfDay> _prayerTimes = {
    'Fajr': const TimeOfDay(hour: 4, minute: 43),
    'Sunrise': const TimeOfDay(hour: 6, minute: 17),
    'Dhuhr': const TimeOfDay(hour: 12, minute: 53),
    'Asr': const TimeOfDay(hour: 16, minute: 29),
    'Maghrib': const TimeOfDay(hour: 19, minute: 29),
    'Isha': const TimeOfDay(hour: 20, minute: 53),
  };

  @override
  void initState() {
    super.initState();
    _getUserLanguage();
  }

  // الحصول على لغة المستخدم من Firestore
  Future<void> _getUserLanguage() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final String lang = userData['lang'] ?? 'english';
          setState(() {
            _currentLanguage = lang;
          });
        }
      }
    } catch (e) {
      print('Error getting user language: $e');
    }
  }

  // دالة للحصول على النص المترجم
  String _t(String key) {
    return _translations[_currentLanguage]?[key] ?? key;
  }

  // تحويل TimeOfDay إلى دقائق منذ منتصف الليل
  int _timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // حساب عدد الصلوات في المدة المحددة
  int _calculatePrayerBreaks(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = _timeOfDayToMinutes(startTime);
    final endMinutes = _timeOfDayToMinutes(endTime);
    
    int count = 0;
    
    _prayerTimes.forEach((name, time) {
      final prayerMinutes = _timeOfDayToMinutes(time);
      if (prayerMinutes >= startMinutes && prayerMinutes <= endMinutes) {
        count++;
      }
    });
    
    return count;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF5B905),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B905),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF5B905),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B905),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF5B905),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B905),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _createTask() async {
    if (_taskNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('please_enter_task_name'))),
      );
      return;
    }

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    final durationInMinutes = endDateTime.difference(startDateTime).inMinutes;

    // حساب عدد فترات الصلاة
    final prayerBreaks = _calculatePrayerBreaks(_startTime, _endTime);

    final formattedStartTime = _formatTimeForFirestore(_startTime);
    final formattedEndTime = _formatTimeForFirestore(_endTime);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('user_not_authenticated'))),
        );
        return;
      }

      await _firestore.collection('tasks').add({
        'name': _taskNameController.text,
        'duration': durationInMinutes,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'start': formattedStartTime,
        'end': formattedEndTime,
        'remind': _remindMe,
        'userId': user.uid,
        'category': _selectedCategory,
        'complete': false,
        'entryCount': 2,
        'isStarted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'prayerBreaks': prayerBreaks, // إضافة عدد فترات الصلاة
        'prayers': _getPrayersInRange(_startTime, _endTime), // أسماء الصلوات في المدة
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('task_created_successfully'))),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('error_creating_task') + e.toString())),
      );
    }
  }

  // الحصول على أسماء الصلوات في المدة المحددة
  List<String> _getPrayersInRange(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = _timeOfDayToMinutes(startTime);
    final endMinutes = _timeOfDayToMinutes(endTime);
    
    List<String> prayers = [];
    
    _prayerTimes.forEach((name, time) {
      final prayerMinutes = _timeOfDayToMinutes(time);
      if (prayerMinutes >= startMinutes && prayerMinutes <= endMinutes) {
        prayers.add(name);
      }
    });
    
    return prayers;
  }

  String _formatTimeForFirestore(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // تنسيق التاريخ بناءً على اللغة
  String _formatDate(DateTime date) {
    if (_currentLanguage == 'arabic') {
      // استخدام تنسيق التاريخ العربي
      final arabicMonths = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      
      final arabicDays = [
        'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
      ];
      
      return '${arabicDays[date.weekday - 1]} ${date.day}، ${arabicMonths[date.month - 1]}';
    } else {
      return DateFormat('EEEE d, MMMM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRTL = _currentLanguage == 'arabic';
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  icon: Icon(
                    isRTL ? Icons.arrow_forward_ios : Icons.arrow_back_ios, 
                    size: 24
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('create'),
                      style: GoogleFonts.tajawal(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black.withOpacity(0.9),
                        height: 0.9,
                      ),
                    ),
                    Text(
                      _t('new_task'),
                      style: GoogleFonts.tajawal(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  _t('task_name'),
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taskNameController,
                  decoration: InputDecoration(
                    hintText: _t('enter_task_name'),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.tajawal(fontSize: 16),
                ),
                const SizedBox(height: 32),
                _buildDetailItem(
                  icon: Icons.calendar_today,
                  value: _formatDate(_selectedDate),
                  onTap: () => _selectDate(context),
                  isDate: true,
                ),
                const SizedBox(height: 24),
                _buildDetailItem(
                  icon: Icons.access_time,
                  value: '${_formatTime(_startTime)} - ${_formatTime(_endTime)}',
                  onTap: () async {
                    await _selectStartTime(context);
                    await _selectEndTime(context);
                  },
                  isTime: true,
                ),
                const SizedBox(height: 24),
                _buildDetailItem(
                  icon: _categories[_selectedCategory]!,
                  value: _selectedCategory == 'important task' 
                      ? _t('important_task') 
                      : _t('normal_task'),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _categories.entries.map((entry) {
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5B905).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(entry.value, color: const Color(0xFFF5B905)),
                                ),
                                title: Text(
                                  entry.key == 'important task' 
                                      ? _t('important_task') 
                                      : _t('normal_task'),
                                  style: GoogleFonts.tajawal(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = entry.key;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                _buildDetailItem(
                  icon: Icons.notifications,
                  value: _t('remind_me'),
                  trailing: Switch(
                    value: _remindMe,
                    onChanged: (value) {
                      setState(() {
                        _remindMe = value;
                      });
                    },
                    activeColor: const Color(0xFFF5B905),
                  ), 
                  onTap: () {},
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5B905),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _createTask,
                      child: Text(
                        _t('create_task'),
                        style: GoogleFonts.tajawal(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    Widget? trailing,
    bool isDate = false,
    bool isTime = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: isDate || isTime 
              ? Border.all(
                  color: const Color(0xFFF5B905).withOpacity(0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDate 
                    ? const Color(0xFFF5B905).withOpacity(0.2)
                    : isTime
                        ? const Color(0xFFF5B905).withOpacity(0.2)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isDate || isTime 
                    ? const Color(0xFFF5B905)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  color: Colors.black.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ?? Icon(
              Icons.chevron_right,
              color: Colors.black.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt).toLowerCase();
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    super.dispose();
  }
}