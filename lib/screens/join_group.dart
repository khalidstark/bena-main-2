import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_chat_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final TextEditingController _groupInputController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _userLanguage = 'english'; // القيمة الافتراضية

  @override
  void initState() {
    super.initState();
    _getUserLanguage();
  }

  Future<void> _getUserLanguage() async {
    String? userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userLanguage = userData['lang'] ?? 'english';
          });
        }
      } catch (e) {
        print("Error fetching user language: $e");
      }
    }
  }

  String _extractGroupId(String input) {
    if (input.contains("https://yourapp.com/group/")) {
      return input.split("https://yourapp.com/group/").last.trim();
    }
    return input.trim();
  }

  Future<void> _joinGroup() async {
    setState(() => _isLoading = true);
    
    String input = _groupInputController.text.trim();
    String groupId = _extractGroupId(input);
    String? userId = _auth.currentUser?.uid;

    if (groupId.isEmpty || userId == null) {
      _showErrorSnackbar(_userLanguage == 'arabic' ? "يرجى إدخال رابط أو معرف المجموعة" : "Please enter a group link or ID");
      setState(() => _isLoading = false);
      return;
    }

    try {
      DocumentSnapshot groupDoc =
          await _firestore.collection('groups').doc(groupId).get();

      if (groupDoc.exists) {
        List<dynamic> members = groupDoc['members'] ?? [];

        if (members.contains(userId)) {
          _showInfoSnackbar(_userLanguage == 'arabic' ? "أنت بالفعل عضو في هذه المجموعة" : "You're already a member of this group");
          setState(() => _isLoading = false);
          return;
        }

        await _firestore.collection('groups').doc(groupId).update({
          'members': FieldValue.arrayUnion([userId])
        });

        _showSuccessSnackbar(_userLanguage == 'arabic' ? "تم الانضمام إلى المجموعة بنجاح!" : "Successfully joined the group!");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CombinedGroupScreen(
              groupId: groupId,
              groupName: groupDoc['name'],
            ),
          ),
        );
      } else {
        _showErrorSnackbar(_userLanguage == 'arabic' ? "لم يتم العثور على المجموعة" : "Group not found");
      }
    } catch (e) {
      _showErrorSnackbar(_userLanguage == 'arabic' ? "حدث خطأ: ${e.toString()}" : "An error occurred: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic = _userLanguage == 'arabic';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          isArabic ? 'انضم إلى مجموعة' : 'Join a Group',
          style: GoogleFonts.tajawal(
            color: Colors.black,
            fontWeight: FontWeight.bold,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFF5B905).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group,
                size: 70,
                color: Color(0xFFF5B905),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              isArabic ? 'انضم إلى مجموعة موجودة' : 'Join an Existing Group',
              style: GoogleFonts.tajawal(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isArabic ? 'أدخل رابط أو معرف المجموعة للانضمام' : 'Enter the group link or ID to join',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _groupInputController,
              decoration: InputDecoration(
                labelText: isArabic ? 'رابط أو معرف المجموعة' : 'Group Link or ID',
                labelStyle: GoogleFonts.tajawal(color: Colors.black54),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.link,
                    color: Color(0xFFF5B905),
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFF5B905),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B905),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.group_add, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            isArabic ? 'انضم للمجموعة' : 'JOIN GROUP',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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

  @override
  void dispose() {
    _groupInputController.dispose();
    super.dispose();
  }
}