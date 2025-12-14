import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_list.dart';
import 'task.dart';
import 'dart:ui';
import 'package:flutter/widgets.dart';


class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _tasksStream;
  Stream<DocumentSnapshot>? _userStream;
  int _selectedTab = 1; // 0: History, 1: Currently, 2: Futuristic
  String _currentLanguage = 'english';

 @override
void initState() {
  super.initState();
  _tasksStream = _firestore
      .collection('tasks')
      .where('userId', isEqualTo: _auth.currentUser?.uid ?? '')
      .snapshots();

  // Get user language preference
  final userId = _auth.currentUser?.uid;
  if (userId != null) {
    _userStream = _firestore.collection('users').doc(userId).snapshots();
  }

  // Precaching Tajawal font for better performance
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _precacheTajawalFont(context);
  });
}

// Precache Tajawal font manually (بدون TextPainter)
void _precacheTajawalFont(BuildContext context) {
  final textStyles = [
    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    const TextStyle(fontSize: 14),
    const TextStyle(fontSize: 12),
  ];

  for (final style in textStyles) {
    final tajawalStyle = GoogleFonts.tajawal(textStyle: style);

    // استعمل Text widget عادي عشان Flutter يعمل load للخط
    Text(
      'أ',
      style: tajawalStyle,
    );

    // أو precache style في DefaultTextStyle
    DefaultTextStyle.of(context).style.merge(tajawalStyle);
  }
}


  int _timeStringToMinutes(String timeString) {
    try {
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final timeFormat = DateFormat('h:mm a');
        final dateTime = timeFormat.parse(timeString);
        return dateTime.hour * 60 + dateTime.minute;
      } else {
        final timeParts = timeString.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        return hour * 60 + minute;
      }
    } catch (e) {
      print('Error parsing time: $e');
      return 0;
    }
  }

  int _calculateDuration(String startTime, String endTime) {
    final startMinutes = _timeStringToMinutes(startTime);
    final endMinutes = _timeStringToMinutes(endTime);
    
    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    } else {
      return (24 * 60 - startMinutes) + endMinutes;
    }
  }

  String _formatDuration(int minutes) {
    final duration = Duration(minutes: minutes);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final mins = twoDigits(duration.inMinutes.remainder(60));
    return "$hours:$mins";
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('MMM d').format(date);
  }

  bool _isTaskInHistory(Map<String, dynamic> taskData) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime.parse(taskData['date']);
    final taskDateOnly = DateTime(taskDate.year, taskDate.month, taskDate.day);
    
    return taskDateOnly.isBefore(today);
  }

  bool _isTaskCurrently(Map<String, dynamic> taskData) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime.parse(taskData['date']);
    final taskDateOnly = DateTime(taskDate.year, taskDate.month, taskDate.day);
    
    if (!taskDateOnly.isAtSameMomentAs(today)) {
      return false;
    }
    
    if (taskData['entryCount'] == 0) {
      return false;
    }
    
    return true;
  }

  bool _isTaskFuturistic(Map<String, dynamic> taskData) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime.parse(taskData['date']);
    final taskDateOnly = DateTime(taskDate.year, taskDate.month, taskDate.day);
    
    return taskDateOnly.isAfter(today);
  }

  Widget _buildCompletionIndicator(bool? isCompleted) {
    if (isCompleted == true) {
      return const Icon(Icons.check, color: Colors.green, size: 24);
    } else if (isCompleted == false) {
      return const Icon(Icons.close, color: Colors.red, size: 24);
    }
    return const SizedBox(width: 24);
  }

 Widget _buildStartedIndicator(bool? isStarted) {
  if (isStarted == true) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.7),
        border: Border.all(color: const Color.fromARGB(255, 255, 255, 255), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
  return const SizedBox(width: 36);
}

  // Get localized text based on language
  String _getLocalizedText(String englishText, String arabicText) {
    return _currentLanguage == 'arabic' ? arabicText : englishText;
  }

  // Get text style based on language with Tajawal for Arabic
  TextStyle _getTextStyle(TextStyle baseStyle) {
    if (_currentLanguage == 'arabic') {
      return GoogleFonts.tajawal(
        textStyle: baseStyle,
        fontSize: baseStyle.fontSize,
        fontWeight: baseStyle.fontWeight,
        color: baseStyle.color,
      );
    }
    return baseStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Listen for user language changes
                  if (_userStream != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: _userStream,
                      builder: (context, userSnapshot) {
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          final userLang = userData['lang'] ?? 'english';
                          if (userLang != _currentLanguage) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _currentLanguage = userLang;
                              });
                            });
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  
                  Text(
                    _getLocalizedText('My Tasks', 'مهامي'),
                    style: _getTextStyle(
                      const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTabButton(_getLocalizedText('History', 'السابق'), 0),
                      _buildTabButton(_getLocalizedText('Currently', 'الحالي'), 1),
                      _buildTabButton(_getLocalizedText('Futuristic', 'المستقبلي'), 2),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _tasksStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              _getLocalizedText('Error: ', 'خطأ: ') + snapshot.error.toString(),
                              style: _getTextStyle(const TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                              )),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _currentLanguage == 'arabic' 
                                  ? const Color(0xFFF5B905)
                                  : Colors.blue,
                              ),
                            ),
                          );
                        }

                        final filteredDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          switch (_selectedTab) {
                            case 0:
                              return _isTaskInHistory(data);
                            case 1:
                              return _isTaskCurrently(data);
                            case 2:
                              return _isTaskFuturistic(data);
                            default:
                              return false;
                          }
                        }).toList();

                        if (filteredDocs.isEmpty) {
                          return Center(
                            child: Text(
                              _selectedTab == 0 
                                ? _getLocalizedText('No past tasks', 'لا توجد مهام سابقة')
                                : _selectedTab == 1 
                                  ? _getLocalizedText('No current tasks', 'لا توجد مهام حالية')
                                  : _getLocalizedText('No future tasks', 'لا توجد مهام مستقبلية'),
                              style: _getTextStyle(const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              )),
                            ),
                          );
                        }

                        final importantTasks = filteredDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['category'] == 'important task';
                        }).toList();

                        final normalTasks = filteredDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['category'] == 'normal task';
                        }).toList();

                        return ListView(
                          children: [
                            if (importantTasks.isNotEmpty)
                              _buildCategorySection(
                                title: _getLocalizedText('Important Tasks', 'مهام مهمة'),
                                tasks: importantTasks,
                                color: Colors.orange[700]!,
                              ),
                            
                            if (normalTasks.isNotEmpty)
                              _buildCategorySection(
                                title: _getLocalizedText('Normal Tasks', 'مهام عادية'),
                                tasks: normalTasks,
                                color: Colors.blue[700]!,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF5B905),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CreateTask()),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required List<QueryDocumentSnapshot> tasks,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: _getTextStyle(
                    TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${tasks.length} ${_getLocalizedText('Tasks', 'مهمة')}',
                  style: _getTextStyle(
                    TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...tasks.map((task) {
              final data = task.data() as Map<String, dynamic>;
              final duration = _calculateDuration(
                data['start'] ?? '00:00',
                data['end'] ?? '00:00'
              );
              
              return InkWell(
                onTap: _selectedTab == 1 
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskPage(taskId: task.id),
                        ),
                      );
                    }
                  : null,
                child: _buildTaskCard(data, duration, color.withOpacity(0.1)),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> data, int duration, [Color? backgroundColor]) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            _selectedTab == 0 
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildCompletionIndicator(data['complete']),
                )
              : _buildStartedIndicator(data['isStarted']),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? _getLocalizedText('No Name', 'بدون اسم'),
                    style: _getTextStyle(
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        data['start'] ?? '',
                        style: _getTextStyle(
                          const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        data['end'] ?? '',
                        style: _getTextStyle(
                          const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDuration(duration),
                  style: _getTextStyle(
                    const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Text(
                  _formatDate(data['date'] ?? ''),
                  style: _getTextStyle(
                    const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int tabIndex) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedTab == tabIndex 
              ? const Color(0xFFF5B905) 
              : Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () {
            setState(() {
              _selectedTab = tabIndex;
            });
          },
          child: Text(
            title,
            style: _getTextStyle(
              TextStyle(
                color: _selectedTab == tabIndex ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}