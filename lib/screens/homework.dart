import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:proft/screens/assignment_questions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Homework extends StatefulWidget {
  const Homework({super.key});

  @override
  State<Homework> createState() => _HomeworkState();
}

class _HomeworkState extends State<Homework> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _language = 'arabic';
  bool _isDateFormatInitialized = false;
  List<String> _teacherCodes = [];
  String? _selectedTeacherCode;
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;

  Map<String, String> localizedTexts = {
    'homework': 'الواجبات',
    'subject': 'المادة',
    'teacher': 'المعلم',
    'questions': 'الأسئلة',
    'no_assignments': 'لا توجد واجبات متاحة',
    'due_date': 'تاريخ التسليم',
    'status': 'الحالة',
    'pending': 'قيد الانتظار',
    'completed': 'مكتمل',
    'assignment_status': 'حالة الواجب',
    'previously_submitted': 'لقد قمت بتسليم هذا الواجب سابقاً\nالنتيجة: ',
    'ok': 'حسناً',
    'view_answers': 'عرض الإجابات',
    'enter_teacher_code': 'أدخل كود المدرس',
    'save': 'حفظ',
    'add_teacher': 'إضافة مدرس',
    'select_teacher': 'اختر المدرس',
    'no_teacher_selected': 'لم يتم اختيار مدرس',
    'teacher_code': 'كود المدرس',
  };

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _loadTeacherCodes();
  }

  Future<void> _loadTeacherCodes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _teacherCodes = prefs.getStringList('teacher_codes') ?? [];
      _selectedTeacherCode = prefs.getString('selected_teacher_code');
      _isLoading = false;
    });
  }

  Future<void> _saveTeacherCodes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('teacher_codes', _teacherCodes);
    if (_selectedTeacherCode != null) {
      await prefs.setString('selected_teacher_code', _selectedTeacherCode!);
    }
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('ar');
    setState(() {
      _isDateFormatInitialized = true;
    });
  }

  String _t(String key) {
    return localizedTexts[key] ?? key;
  }

  Widget _buildText(String text, TextStyle style) {
    return Text(
      text,
      style: GoogleFonts.tajawal(textStyle: style),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp timestamp) {
    if (!_isDateFormatInitialized) {
      return "جاري التحميل...";
    }
    
    try {
      final date = timestamp.toDate();
      return DateFormat('yyyy/MM/dd', 'ar').format(date);
    } catch (e) {
      return "تاريخ غير صحيح";
    }
  }

  Future<void> _checkUserStatus(String assignmentId, Map<String, dynamic> assignmentData) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userSubmission = await _firestore
            .collection('assignments')
            .doc(assignmentId)
            .collection('participants')
            .doc(user.uid)
            .get();

        if (userSubmission.exists) {
          // المستخدم قد سلم الواجب بالفعل
          int userScore = userSubmission.get('score') ?? 0;
          int totalQuestions = userSubmission.get('totalQuestions') ?? 0;
          
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: _buildText(
                  _t('assignment_status'),
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildText(
                      '${_t('previously_submitted')}$userScore/$totalQuestions',
                      const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _navigateToAssignmentQuestions(assignmentData, assignmentId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: _buildText(
                        _t('view_answers'),
                        const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: _buildText(
                      _t('ok'),
                      const TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          // المستخدم لم يسلم الواجب بعد
          _navigateToAssignmentQuestions(assignmentData, assignmentId);
        }
      } catch (e) {
        print('خطأ في التحقق من حالة المستخدم: $e');
        // في حالة الخطأ، انتقل مباشرة إلى صفحة الأسئلة
        _navigateToAssignmentQuestions(assignmentData, assignmentId);
      }
    } else {
      // إذا لم يكن المستخدم مسجلاً، انتقل مباشرة إلى صفحة الأسئلة
      _navigateToAssignmentQuestions(assignmentData, assignmentId);
    }
  }

  void _navigateToAssignmentQuestions(Map<String, dynamic> assignmentData, String assignmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentQuestionsScreen(
          assignmentData: assignmentData,
          assignmentId: assignmentId,
        ),
      ),
    );
  }

  Widget _buildUserStatusIndicator(String assignmentId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore
          .collection('assignments')
          .doc(assignmentId)
          .collection('participants')
          .doc(_auth.currentUser?.uid ?? '')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          int userScore = snapshot.data!.get('score') ?? 0;
          int totalQuestions = snapshot.data!.get('totalQuestions') ?? 0;
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                _buildText(
                  '$userScore/$totalQuestions',
                  TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _showAddTeacherDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            title: _buildText(
              _t('add_teacher'),
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildText(
                  _t('enter_teacher_code'),
                  const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: _t('teacher_code'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _buildText(
                        'إلغاء',
                        const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_codeController.text.isNotEmpty) {
                          setState(() {
                            if (!_teacherCodes.contains(_codeController.text)) {
                              _teacherCodes.add(_codeController.text);
                            }
                            _selectedTeacherCode = _codeController.text;
                            _saveTeacherCodes();
                          });
                          Navigator.of(context).pop();
                          _codeController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _buildText(
                        _t('save'),
                        const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          
        );
      },
    );
  }

  Widget _buildTeacherCodeSelector() {
    return PopupMenuButton<String>(
      onSelected: (String value) {
        if (value == 'add_teacher') {
          _showAddTeacherDialog();
        } else {
          setState(() {
            _selectedTeacherCode = value;
            _saveTeacherCodes();
          });
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          ..._teacherCodes.map((String code) {
            return PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(code),
                ],
              ),
            );
          }).toList(),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'add_teacher',
            child: Row(
              children: [
                Icon(Icons.add, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(_t('add_teacher')),
              ],
            ),
          ),
        ];
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            _buildText(
              _selectedTeacherCode ?? _t('select_teacher'),
              TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _selectedTeacherCode != null ? Colors.blue : Colors.grey,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _buildText(
          _t('homework'),
          const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildTeacherCodeSelector(),
          ),
        ],
      ),
      body: !_isDateFormatInitialized
          ? const Center(child: CircularProgressIndicator())
          : _selectedTeacherCode == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildText(
                      _t('no_teacher_selected'),
                      TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showAddTeacherDialog,
                      icon: Icon(Icons.add),
                      label: _buildText(
                        _t('add_teacher'),
                        TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              )
            : StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('assignments')
                    .where('code', isEqualTo: _selectedTeacherCode)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: _buildText(
                        'خطأ: ${snapshot.error}',
                        const TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildText(
                            _t('no_assignments'),
                            TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 10),
                          _buildText(
                            'كود المدرس: $_selectedTeacherCode',
                            TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: snapshot.data!.docs.map((document) {
                      var data = document.data() as Map<String, dynamic>;
                      String assignmentId = document.id;
                      
                      String subject = data['subject'] ?? '';
                      String title = data['title'] ?? '';
                      String teacher = data['teacher'] ?? '';
                      int questionCount = data['questionCount'] ?? 0;
                      Timestamp dueDate = data['dueDate'] ?? Timestamp.now();
                      
                      Map<String, String> subjectTranslations = {
                        'Math': 'الرياضيات',
                        'Science': 'العلوم',
                        'English': 'اللغة الإنجليزية',
                        'Arabic': 'اللغة العربية',
                        'History': 'التاريخ',
                        'Geography': 'الجغرافيا',
                        'Physics': 'الفيزياء',
                        'Chemistry': 'الكيمياء',
                        'Biology': 'الأحياء',
                      };
                      subject = subjectTranslations[subject] ?? subject;

                      return GestureDetector(
                        onTap: () => _checkUserStatus(assignmentId, data),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildText(
                                        title,
                                        const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _buildUserStatusIndicator(assignmentId),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                Row(
                                  children: [
                                    Icon(Icons.subject, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    _buildText(
                                      '${_t('subject')}: ',
                                      TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    _buildText(
                                      subject,
                                      const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    _buildText(
                                      '${_t('teacher')}: ',
                                      TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    _buildText(
                                      teacher,
                                      const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                Row(
                                  children: [
                                    Icon(Icons.help_outline, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    _buildText(
                                      '${_t('questions')}: ',
                                      TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    _buildText(
                                      '$questionCount',
                                      const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    _buildText(
                                      '${_t('due_date')}: ',
                                      TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    _buildText(
                                      _formatDate(dueDate),
                                      const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
    );
  }
}