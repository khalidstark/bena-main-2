import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class CreateAccountScreen extends StatelessWidget {
  CreateAccountScreen({super.key});

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController confirmPassController = TextEditingController();

  Future<void> _createAccount(BuildContext context) async {
    if (passController.text != confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    try {
      final email = '${usernameController.text.trim()}@gmail.com';
      
      // First check Firestore users collection for existing email
      final firestoreQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (firestoreQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User already exists. Please sign in')),
        );
        return;
      }

      // Then check Firebase Auth
      final authMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (authMethods.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User already exists. Please sign in')),
        );
        return;
      }

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passController.text,
      );

      final user = credential.user;
      if (user != null) {
        await _saveUserToFirestore(user);
        // Navigate to WhatsApp number collection screen instead of home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WhatsAppNumberScreen(user: user),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Account creation failed';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'User already exists. Please sign in';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account creation failed')),
      );
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Check Firestore first for existing user
      final firestoreQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: googleUser.email)
          .limit(1)
          .get();

      if (firestoreQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User already exists. Please sign in')),
        );
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _saveUserToFirestore(user, googleAuth.accessToken);
        // Navigate to WhatsApp number collection screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WhatsAppNumberScreen(user: user),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User already exists. Please sign in')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In failed')),
      );
    }
  }

  Future<void> _saveUserToFirestore(User user, [String? accessToken]) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      String username = user.displayName ?? 
                        user.email?.split('@').first ?? 
                        usernameController.text.trim();

      await userDoc.set({
        'email': user.email ?? '$username@gmail.com',
        'insta': false,
        'name': username,
        'points': 0,
        'score': 0,
        'uid': user.uid,
        'whats': false,
        'whatsappNumber': '', // Initialize with empty string
        'accessToken': accessToken,
        'createdAt': FieldValue.serverTimestamp(),
        'religion': 'Muslim', // Default religion
        'gender': 'Male', // Default gender
        'lang': 'english', // Default language
        'mister': false, // Default value for teacher code verification
      });
    } catch (e) {
      print("Error saving user to Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5B905),
                    Color(0xFFFFD700),
                    Colors.white,
                  ],
                  stops: [0.1, 0.5, 0.9],
                ),
              ),
            ),
          ),
          
          // Logo and app name
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 200,
                  width: 200,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Bena',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Plo',
                  ),
                ),
              ],
            ),
          ),
          
          // Main content
          Positioned.fill(
            top: 400,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  // Username field
                  _buildFloatingTextField(
                    context,
                    usernameController,
                    "Username",
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 25),
                  
                  // Password field
                  _buildFloatingTextField(
                    context,
                    passController,
                    "Password",
                    Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 25),
                  
                  // Confirm Password field
                  _buildFloatingTextField(
                    context,
                    confirmPassController,
                    "Confirm Password",
                    Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 40),
                  
                  // Create Account button
                  _buildAnimatedButton(
                    text: "CREATE ACCOUNT",
                    icon: Icons.person_add,
                    onTap: () => _createAccount(context),
                  ),
                  const SizedBox(height: 30),
                  
                  // Divider with "OR" text
                  _buildDividerWithText(),
                  const SizedBox(height: 30),
                  
                  // Google sign up button
                  _buildSimpleButton(
                    text: "SIGN UP WITH GOOGLE",
                    onTap: () => signInWithGoogle(context),
                  ),
                  
                  // Already have account link
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Already have an account? Sign in",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTextField(
    BuildContext context,
    TextEditingController controller,
    String labelText,
    IconData icon, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xFFF5B905)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF5B905),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 20,
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF5B905).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF5B905).withOpacity(0.8),
                        const Color(0xFFF5B905),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    icon,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerWithText() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey[400],
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            "OR",
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey[400],
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class WhatsAppNumberScreen extends StatefulWidget {
  final User user;

  const WhatsAppNumberScreen({super.key, required this.user});

  @override
  _WhatsAppNumberScreenState createState() => _WhatsAppNumberScreenState();
}

class _WhatsAppNumberScreenState extends State<WhatsAppNumberScreen> {
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _teacherCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedReligion = 'Muslim'; // Default value
  String _selectedGender = 'Male'; // Default value
  String _selectedLanguage = 'english'; // Default value
  bool _isTeacherCodeValid = false;
  bool _teacherCodeChecked = false;

  // دالة للتحقق من كود المدرس
  Future<bool> _checkTeacherCode() async {
    if (_teacherCodeController.text.isEmpty) return false;

    try {
      final teacherCodeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('modarsen')
          .get();

      if (teacherCodeDoc.exists) {
        final teacherCodes = teacherCodeDoc.data()?['mr'] as List<dynamic>?;
        if (teacherCodes != null) {
          final enteredCode = int.tryParse(_teacherCodeController.text);
          if (enteredCode != null && teacherCodes.contains(enteredCode)) {
            setState(() {
              _isTeacherCodeValid = true;
              _teacherCodeChecked = true;
            });
            return true; // ✅ الكود صحيح
          }
        }
      }

      setState(() {
        _isTeacherCodeValid = false;
        _teacherCodeChecked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كود المدرس غير صحيح، يرجى التحقق وإدخال كود صحيح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء التحقق من كود المدرس')),
      );
    }
    return false; // ❌ الكود غلط
  }

  Future<void> _saveWhatsAppNumber() async {
    if (!_formKey.currentState!.validate()) return;

    bool misterValue = false;

    // لو المستخدم دخل كود
    if (_teacherCodeController.text.isNotEmpty) {
      misterValue = await _checkTeacherCode();
      if (!misterValue) return; // لو الكود غلط منوقف
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'whatsappNumber': _whatsappController.text.trim(),
        'whats': true,
        'religion': _selectedReligion,
        'gender': _selectedGender,
        'lang': _selectedLanguage,
        'mister': misterValue, // ✅ بناءً على الكود
      });

      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'name': widget.user.displayName ?? '',
          'email': widget.user.email ?? '',
          'photoUrl': widget.user.photoURL,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save information')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5B905),
                    Color(0xFFFFD700),
                    Colors.white,
                  ],
                  stops: [0.1, 0.5, 0.9],
                ),
              ),
            ),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please enter your WhatsApp number and select your details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // WhatsApp Number Field
                        TextFormField(
                          controller: _whatsappController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'WhatsApp Number',
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFFF5B905)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your WhatsApp number';
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Teacher Code Field
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _teacherCodeController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: 'Teacher Code (Optional)',
                                  prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFFF5B905)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: _teacherCodeController.text.isNotEmpty
                                      ? Icon(
                                          _isTeacherCodeValid ? Icons.check_circle : Icons.cancel,
                                          color: _isTeacherCodeValid ? Colors.green : Colors.red,
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _teacherCodeChecked = false;
                                    _isTeacherCodeValid = false;
                                  });
                                },
                              ),
                            ),
                            if (_teacherCodeController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: IconButton(
                                  icon: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Icon(Icons.check, color: Color(0xFFF5B905)),
                                  onPressed: _isLoading ? null : () async {
                                    final valid = await _checkTeacherCode();
                                    if (!valid) return;
                                  },
                                ),
                              ),
                          ],
                        ),
                        if (_teacherCodeChecked && !_isTeacherCodeValid)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'كود المدرس غير صحيح، يرجى التحقق وإدخال كود صحيح',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Religion Dropdown with Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedReligion,
                            decoration: const InputDecoration(
                              labelText: 'Religion',
                              border: InputBorder.none,
                            ),
                            items: ['Muslim', 'Christian', 'Jewish'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedReligion = newValue!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Gender Dropdown with Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              border: InputBorder.none,
                            ),
                            items: ['Male', 'Female'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedGender = newValue!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Language Dropdown with Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedLanguage,
                            decoration: const InputDecoration(
                              labelText: 'Language',
                              border: InputBorder.none,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'arabic', child: Text('Arabic')),
                              DropdownMenuItem(value: 'english', child: Text('English')),
                            ],
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedLanguage = newValue!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveWhatsAppNumber,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5B905),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}