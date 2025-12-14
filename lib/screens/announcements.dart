import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  // دالة لفتح الرابط
  Future<void> _launchURL(BuildContext context, String url, String platform) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userRef.get();

    // Check if user has already joined this platform
    if (doc.exists && (doc.data()?[platform] == true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already joined this $platform'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (await canLaunch(url)) {
      await launch(url);
      await _updateUserData(userRef, platform);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // دالة لتحديث بيانات المستخدم
  Future<void> _updateUserData(DocumentReference userRef, String platform) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      
      if (!snapshot.exists) {
        // Create document if not exists
        transaction.set(userRef, {
          'score': 100,
          'insta': platform == 'insta',
          'whats': platform == 'whats',
        });
      } else {
        // Update existing document
        final data = snapshot.data() as Map<String, dynamic>;
        final currentScore = data['score'] ?? 0;
        
        transaction.update(userRef, {
          'score': currentScore + 20,
          platform: true,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Announcements",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5B905), Color(0xFFFFD700)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.celebration,
                    size: 50,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Join to get 100 points!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Follow us on social media and earn rewards",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Social Cards
            Expanded(
              child: ListView(
                children: [
                  _buildSocialCard(
                    context: context,
                    imagePath: "assets/insta.jpeg",
                    text: "Join Instagram",
                    url: "https://www.instagram.com/bena_study?igsh=MWh4eGE0YnpudjRrYg%3D%3D&utm_source=qr",
                    platform: 'insta',
                    color: const Color(0xFFE1306C),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildSocialCard(
                    context: context,
                    imagePath: "assets/Whats.jpeg",
                    text: "Join WhatsApp Channel",
                    url: "https://whatsapp.com/channel/0029VbAHzf00gcfR0JiLLJ1w",
                    platform: 'whats',
                    color: const Color(0xFF25D366),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة لبناء بطاقة الوسائط الاجتماعية
  Widget _buildSocialCard({
    required BuildContext context,
    required String imagePath,
    required String text,
    required String url,
    required String platform,
    required Color color,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final isJoined = snapshot.hasData && 
                        snapshot.data!.exists && 
                        (snapshot.data!.data() as Map<String, dynamic>)[platform] == true;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isJoined ? null : () => _showConfirmationDialog(context, url, platform),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: isJoined 
                    ? Colors.green.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.2),
                width: isJoined ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      imagePath,
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isJoined 
                            ? "Already joined (+100 points)"
                            : "Tap to join and earn 100 points",
                        style: TextStyle(
                          fontSize: 14,
                          color: isJoined ? Colors.green : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isJoined 
                        ? Colors.green.withOpacity(0.1)
                        : color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isJoined ? Icons.check : Icons.arrow_forward_ios,
                    size: 16,
                    color: isJoined ? Colors.green : color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // دالة لعرض نافذة التأكيد
  void _showConfirmationDialog(BuildContext context, String url, String platform) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B905).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link,
                    size: 30,
                    color: Color(0xFFF5B905),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Confirm Action",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You'll earn 100 points for joining",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  url,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.grey.withOpacity(0.5)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5B905),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _launchURL(context, url, platform);
                        },
                        child: const Text(
                          "Join Now",
                          style: TextStyle(color: Colors.black),
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
    );
  }
}