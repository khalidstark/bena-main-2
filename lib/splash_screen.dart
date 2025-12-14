import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset("assets/videos/Bena.mp4");
      
      await _controller.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      
      _controller.play();
      
      // Navigate when video completes
      _controller.addListener(() {
        if (_controller.value.isPlaying && 
            _controller.value.position >= _controller.value.duration - const Duration(milliseconds: 100)) {
          _navigateBasedOnUserStatus();
        }
      });
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      // If video fails, navigate after delay
      Future.delayed(const Duration(seconds: 2), _navigateBasedOnUserStatus);
      debugPrint('Video initialization error: $e');
    }
  }

  Future<void> _navigateBasedOnUserStatus() async {
    final currentUser = _auth.currentUser;
    
    if (currentUser != null) {
      try {
        // Check if a document exists in 'users' collection with the same ID as current user
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        
        if (userDoc.exists) {
          // User exists in Firestore, navigate to home
          _navigateToHome(context, currentUser);
        } else {
          // User not found in Firestore, go to login
          _navigateToLogin(context);
        }
      } catch (e) {
        debugPrint('Error checking user: $e');
        _navigateToLogin(context);
      }
    } else {
      // No current user, go to login
      _navigateToLogin(context);
    }
  }

  void _navigateToHome(BuildContext context, User user) {
    Navigator.pushReplacementNamed(
      context,
      '/home',
      arguments: user, // pass user if needed
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: _hasError
                ? const Icon(Icons.error, size: 50, color: Colors.red)
                : _isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CircularProgressIndicator(),
          ),
          Positioned(
            top: 30,
            right: 20,
            child: TextButton(
              onPressed: _navigateBasedOnUserStatus,
              child: const Text(
                "",
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}