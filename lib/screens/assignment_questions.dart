import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignmentQuestionsScreen extends StatefulWidget {
  final Map<String, dynamic> assignmentData;
  final String assignmentId;

  const AssignmentQuestionsScreen({
    super.key,
    required this.assignmentData,
    required this.assignmentId,
  });

  @override
  State<AssignmentQuestionsScreen> createState() => _AssignmentQuestionsScreenState();
}

class _AssignmentQuestionsScreenState extends State<AssignmentQuestionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _userAnswers = [];
  bool _isSubmitted = false;
  int _score = 0;
  double _percentage = 0.0;
  bool _isLoading = true;
  Map<String, dynamic>? _userSubmission;
  List<Map<String, dynamic>> _texts = [];
  int _totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _processTextsData();
    _checkUserSubmission();
  }

  void _processTextsData() {
    // استخراج النصوص من البيانات
    if (widget.assignmentData['texts'] != null) {
      _texts = List<Map<String, dynamic>>.from(widget.assignmentData['texts']);
      
      // حساب إجمالي عدد الأسئلة (فقط الأسئلة التي لها إجابات غير null)
      _totalQuestions = 0;
      for (var text in _texts) {
        List<dynamic> answers = List<dynamic>.from(text['answers'] ?? []);
        // حساب فقط الأسئلة التي لها إجابات (ليست null)
        int validQuestions = answers.where((answer) => answer != null).length;
        _totalQuestions += validQuestions;
      }
    } else {
      // إذا لم تكن هناك نصوص، نتعامل معها كواجب عادي
      List<dynamic> answers = List<dynamic>.from(widget.assignmentData['answers'] ?? []);
      _totalQuestions = answers.where((answer) => answer != null).length;
    }
  }

  Future<void> _checkUserSubmission() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // التحقق إذا كان المستخدم قد سلم الواجب بالفعل
        DocumentSnapshot submissionDoc = await _firestore
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('participants')
            .doc(user.uid)
            .get();

        if (submissionDoc.exists) {
          // المستخدم قد سلم الواجب بالفعل
          setState(() {
            _userSubmission = submissionDoc.data() as Map<String, dynamic>;
            _isSubmitted = true;
            _score = _userSubmission!['score'] ?? 0;
            
            // تحميل الإجابات السابقة للمستخدم
            List<dynamic> previousAnswers = _userSubmission!['userAnswers'] ?? [];
            _userAnswers = List<String>.from(previousAnswers.map((answer) => answer?.toString() ?? ''));
            
            _percentage = _userAnswers.isNotEmpty ? (_score / _userAnswers.length) * 100 : 0;
            _isLoading = false;
          });
        } else {
          // المستخدم لم يسلم الواجب بعد
          setState(() {
            _userAnswers = List.filled(_totalQuestions, '');
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error checking user submission: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildText(String text, TextStyle style) {
    return Text(
      text,
      style: GoogleFonts.tajawal(textStyle: style),
    );
  }

  Future<void> _submitAnswers() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    // جلب بيانات المستخدم
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    String userName = userDoc.get('name') ?? 'مستخدم';
    String whatsappNumber = userDoc.get('whatsappNumber') ?? '';

    // تجميع الإجابات الصحيحة من جميع النصوص
    List<String> correctAnswers = [];
    
    if (_texts.isNotEmpty) {
      for (var text in _texts) {
        List<dynamic> textAnswers = List<dynamic>.from(text['answers'] ?? []);
        // إضافة فقط الإجابات غير الفارغة
        for (var answer in textAnswers) {
          if (answer != null) {
            correctAnswers.add(answer.toString());
          }
        }
      }
    } else {
      // إذا لم تكن هناك نصوص، نتعامل معها كواجب عادي
      List<dynamic> answers = List<dynamic>.from(widget.assignmentData['answers'] ?? []);
      for (var answer in answers) {
        if (answer != null) {
          correctAnswers.add(answer.toString());
        }
      }
    }

    int correctCount = 0;

    for (int i = 0; i < _userAnswers.length; i++) {
      if (i < correctAnswers.length && _userAnswers[i] == correctAnswers[i]) {
        correctCount++;
      }
    }

    // حفظ إجابات المستخدم في مجموعة المشاركين
    await _firestore
        .collection('assignments')
        .doc(widget.assignmentId)
        .collection('participants')
        .doc(user.uid)
        .set({
      'userId': user.uid,
      'userName': userName,
      'whatsappNumber': whatsappNumber,
      'userAnswers': _userAnswers,
      'score': correctCount,
      'totalQuestions': _userAnswers.length,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': correctCount > 0 ? 'completed' : 'attempted',
    });

    // تحديث حالة الواجب الرئيسية إذا لزم الأمر
    await _firestore.collection('assignments').doc(widget.assignmentId).update({
      'participantsCount': FieldValue.increment(1),
    });

    setState(() {
      _score = correctCount;
      _percentage = _userAnswers.isNotEmpty ? (_score / _userAnswers.length) * 100 : 0;
      _isSubmitted = true;
    });
  }

  Widget _buildTextSection(int textIndex, Map<String, dynamic> textData) {
    String textTitle = textData['textTitle'] ?? '';
    List<dynamic> answers = List<dynamic>.from(textData['answers'] ?? []);
    
    // حساب عدد الأسئلة الفعلية (غير الفارغة)
    int actualQuestionCount = answers.where((answer) => answer != null).length;
    
    // حساب مؤشر البداية لهذا النص في قائمة الإجابات
    int startIndex = 0;
    for (int i = 0; i < textIndex; i++) {
      List<dynamic> prevAnswers = List<dynamic>.from(_texts[i]['answers'] ?? []);
      startIndex += prevAnswers.where((answer) => answer != null).length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان النص إذا كان موجوداً
        if (textTitle.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: _buildText(
              textTitle,
              const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        
        // رقم النص
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildText(
            'النص ${textIndex + 1}',
            const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // الأسئلة الخاصة بهذا النص
        ...List.generate(answers.length, (index) {
          if (answers[index] == null) return const SizedBox.shrink();
          
          return _buildQuestionCard(
            startIndex + index, 
            index, 
            answers[index]!.toString()
          );
        }),
        
        // خط فاصل بين النصوص (ما عدا الأخير)
        if (textIndex < _texts.length - 1)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            height: 1,
            color: Colors.grey[300],
          ),
      ],
    );
  }

  Widget _buildQuestionCard(int globalIndex, int localIndex, String correctAnswer) {
    List<String> options = ['أ', 'ب', 'ج', 'د'];
    String userAnswer = globalIndex < _userAnswers.length ? _userAnswers[globalIndex] : '';

    Color getOptionColor(String option) {
      if (!_isSubmitted) {
        return option == userAnswer ? Colors.blue : Colors.white;
      } else {
        if (option == correctAnswer) {
          return Colors.green; // الإجابة الصحيحة
        } else if (option == userAnswer && userAnswer != correctAnswer) {
          return Colors.red; // إجابة المستخدم الخاطئة
        }
        return Colors.white; // الخيارات الأخرى
      }
    }

    Color getOptionTextColor(String option) {
      if (!_isSubmitted) {
        return option == userAnswer ? Colors.white : Colors.black;
      } else {
        if (option == correctAnswer || (option == userAnswer && userAnswer != correctAnswer)) {
          return Colors.white;
        }
        return Colors.black;
      }
    }

    Color getOptionBorderColor(String option) {
      if (!_isSubmitted) {
        return option == userAnswer ? Colors.blue : Colors.grey[300]!;
      } else {
        if (option == correctAnswer) {
          return Colors.green;
        } else if (option == userAnswer && userAnswer != correctAnswer) {
          return Colors.red;
        }
        return Colors.grey[300]!;
      }
    }

    Widget getOptionIcon(String option) {
      if (!_isSubmitted) {
        return option == userAnswer 
            ? Icon(Icons.check_circle, color: Colors.white, size: 20)
            : const SizedBox.shrink();
      } else {
        if (option == correctAnswer) {
          return Icon(Icons.check_circle, color: Colors.white, size: 20);
        } else if (option == userAnswer && userAnswer != correctAnswer) {
          return Icon(Icons.cancel, color: Colors.white, size: 20);
        }
        return const SizedBox.shrink();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _buildText(
                      '${globalIndex + 1}',
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildText(
                    'السؤال ${globalIndex + 1}',
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 2.2,
              ),
              itemCount: options.length,
              itemBuilder: (context, optionIndex) {
                String option = options[optionIndex];
                return GestureDetector(
                  onTap: _isSubmitted ? null : () {
                    setState(() {
                      _userAnswers[globalIndex] = option;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: getOptionColor(option),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: getOptionBorderColor(option),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildText(
                                option,
                                TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: getOptionTextColor(option),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_isSubmitted || option == userAnswer)
                                getOptionIcon(option),
                            ],
                          ),
                        ),
                        if (!_isSubmitted && option == userAnswer)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.radio_button_checked,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // عرض الإجابة الصحيحة إذا كانت إجابة المستخدم خاطئة
            if (_isSubmitted && userAnswer != correctAnswer)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      _buildText(
                        'الإجابة الصحيحة: $correctAnswer',
                        TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildText(
              'نتيجة الواجب',
              const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _percentage >= 50 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _percentage >= 50 ? Colors.green : Colors.red,
                  width: 3,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildText(
                      '$_score',
                      TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _percentage >= 50 ? Colors.green : Colors.red,
                      ),
                    ),
                    _buildText(
                      'من ${_userAnswers.length}',
                      TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildText(
              'النسبة: ${_percentage.toStringAsFixed(1)}%',
              TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _percentage >= 50 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _percentage >= 50 ? Colors.green : Colors.red,
              ),
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildText(
                  '0%',
                  TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                _buildText(
                  '100%',
                  TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildText(
              'تم تسليم إجاباتك بنجاح',
              TextStyle(
                fontSize: 16,
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularAssignment() {
    List<dynamic> answers = List<dynamic>.from(widget.assignmentData['answers'] ?? []);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الأسئلة العادية
        ...List.generate(answers.length, (index) {
          if (answers[index] == null) return const SizedBox.shrink();
          
          return _buildQuestionCard(
            index, 
            index, 
            answers[index]!.toString()
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: _buildText(
            widget.assignmentData['title'] ?? 'الواجب',
            const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _buildText(
          widget.assignmentData['title'] ?? 'الواجب',
          const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isSubmitted) _buildResultCard(),
            Expanded(
              child: ListView(
                children: [
                  if (_texts.isNotEmpty)
                    ...List.generate(_texts.length, (index) {
                      return _buildTextSection(index, _texts[index]);
                    })
                  else
                    _buildRegularAssignment(),
                ],
              ),
            ),
            if (!_isSubmitted)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () {
                    bool allAnswered = _userAnswers.every((answer) => answer.isNotEmpty);
                    if (allAnswered) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: _buildText(
                              'تأكيد التسليم',
                              const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: _buildText(
                              'هل أنت متأكد من أنك تريد تسليم الواجب؟ لا يمكنك تعديل الإجابات بعد التسليم.',
                              const TextStyle(fontSize: 16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: _buildText(
                                  'إلغاء',
                                  const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _submitAnswers();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: _buildText(
                                  'تأكيد التسليم',
                                  const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: _buildText(
                            'يرجى الإجابة على جميع الأسئلة قبل التسليم',
                            const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                  ),
                  child: _buildText(
                    'تسليم الواجب',
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}