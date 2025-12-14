import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screens/create_account.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  // Function to check if user exists in Firestore with matching username and password
  Future<Map<String, dynamic>?> _findUserByCredentials(String username, String password) async {
    try {
      print("🔍 Searching for user: $username with password: $password");
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: username)
          .limit(1)
          .get();
      
      print("📊 Found ${snapshot.docs.length} documents with matching username");
      
      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data();
        final storedPassword = userData['password']?.toString() ?? '';
        
        print("🔑 Stored password: $storedPassword");
        print("🔑 Entered password: $password");
        print("✅ Password match: ${storedPassword == password}");
        
        if (storedPassword == password) {
          return userData;
        } else {
          print("❌ Passwords don't match");
          return null;
        }
      }
      
      return null;
    } catch (e) {
      print("🔥 Error checking user: $e");
      return null;
    }
  }

  // Username/password login
  Future<void> signInWithUsername(
      String username, String password, BuildContext context) async {
    try {
      // Check if user exists in Firestore with matching credentials
      final userData = await _findUserByCredentials(username, password);
      
      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
        return;
      }

      // Get user email from Firestore document
      final userEmail = userData['email'] as String?;
      
      if (userEmail == null || userEmail.isEmpty) {
        // If no email exists, try to sign in with a default email pattern
        final defaultEmail = '$username@bena.com';
        try {
          final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: defaultEmail,
            password: password,
          );
          
          if (credential.user != null) {
            _navigateToHome(context, credential.user!);
          }
        } catch (e) {
          print("⚠️ Default email login failed: $e");
          
          // Create a new auth user if one doesn't exist
          try {
            final newUser = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: defaultEmail,
              password: password,
            );
            
            if (newUser.user != null) {
              _navigateToHome(context, newUser.user!);
            }
          } catch (createError) {
            print("🔥 Error creating auth user: $createError");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Authentication error. Please contact support.')),
            );
          }
        }
      } else {
        // Sign in with Firebase Auth using the email from Firestore
        try {
          final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: userEmail,
            password: password,
          );

          if (credential.user != null) {
            _navigateToHome(context, credential.user!);
          }
        } catch (e) {
          print("⚠️ Email login failed: $e");
          
          // If email login fails, try to create the auth account
          try {
            final newUser = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: userEmail,
              password: password,
            );
            
            if (newUser.user != null) {
              _navigateToHome(context, newUser.user!);
            }
          } catch (createError) {
            print("🔥 Error creating auth user: $createError");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Authentication error: ${createError.toString()}')),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login error occurred';
      if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'User not found';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print("🔥 Unexpected error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    }
  }

  // Google sign-in
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Check if user exists in Firestore by email
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
            
        if (userDoc.docs.isEmpty) {
          // Create a new user document if doesn't exist
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': user.displayName ?? user.email!.split('@').first,
                'email': user.email,
                'uid': user.uid,
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        _navigateToHome(context, user);
      }
    } catch (e) {
      print("🔥 Google sign-in error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: ${e.toString()}')),
      );
    }
  }

  // Navigate to home screen
  void _navigateToHome(BuildContext context, User user) {
    Navigator.pushReplacementNamed(
      context,
      '/home',
      arguments: {
        'name': user.displayName ?? 'User',
        'email': user.email ?? 'No email',
      },
    );
  }

  // Navigate to create account screen
  void _navigateToCreateAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateAccountScreen()),
    );
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
                  _buildTextField(
                    controller: usernameController,
                    label: "Username",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 25),
                  
                  // Password field
                  _buildTextField(
                    controller: passController,
                    label: "Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 40),
                  
                  // Login button
                  _buildLoginButton(context),
                  const SizedBox(height: 30),
                  
                  // Divider with "OR"
                  _buildDivider(),
                  const SizedBox(height: 30),
                  
                  // Google sign-in button
                  _buildGoogleButton(context),
                  
                  // Create account link
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () => _navigateToCreateAccount(context),
                    child: const Text(
                      "Don't have an account? Create one now",
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

  // Text field widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
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
      ),
    );
  }

  // Login button widget
  Widget _buildLoginButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFFF5B905),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () {
        if (usernameController.text.isEmpty || passController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter username and password')),
          );
          return;
        }
        signInWithUsername(
          usernameController.text.trim(),
          passController.text,
          context,
        );
      },
      child: const Text(
        "LOGIN",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Divider widget
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[400])),
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
        Expanded(child: Divider(color: Colors.grey[400])),
      ],
    );
  }

  // Google button widget (without logo)
  Widget _buildGoogleButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade300),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () => signInWithGoogle(context),
      child: const Text(
        "SIGN IN WITH GOOGLE",
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
    );
  }
}