import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'create_group.dart';
import 'join_group.dart';
import 'group_chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const GroupListScreen(),
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String language = "english";
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserLanguage();
  }

  void _fetchUserLanguage() {
    final user = _auth.currentUser;
    if (user != null) {
      _userSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          setState(() {
            language = snapshot.data()?['lang'] ?? 'english';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  // دالة لترجمة النصوص بناءً على اللغة المحددة
  String _translate(String englishText, String arabicText) {
    return language == 'arabic' ? arabicText : englishText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _translate('My Groups', 'مجموعاتي'),
          style: language == 'arabic'
            ? GoogleFonts.tajawal(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              )
            : const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, size: 28),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: _translate('Search groups...', 'ابحث في المجموعات...'),
                hintStyle: language == 'arabic' ? GoogleFonts.tajawal() : null,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .where('members', arrayContains: _auth.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerLoading();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      _translate('Error: ', 'خطأ: ') + '${snapshot.error}',
                      style: language == 'arabic' ? GoogleFonts.tajawal() : null,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.group,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _translate('No groups yet', 'لا توجد مجموعات بعد'),
                          style: language == 'arabic'
                            ? GoogleFonts.tajawal(
                                fontSize: 18,
                                color: Colors.grey,
                              )
                            : const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5B905),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateGroupScreen(),
                              ),
                            );
                          },
                          child: Text(
                            _translate('Create New Group', 'إنشاء مجموعة جديدة'),
                            style: language == 'arabic'
                              ? GoogleFonts.tajawal(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                )
                              : const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final groups = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final groupName = group['name'];
                    final membersCount = group['members'].length;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      color: Colors.white,
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CombinedGroupScreen(
                                groupId: group.id,
                                groupName: groupName,
                              ),
                            ),
                          );
                        },
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B905),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              groupName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          groupName,
                          style: language == 'arabic'
                            ? GoogleFonts.tajawal(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              )
                            : const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                        ),
                        subtitle: Text(
                          _translate('$membersCount members', '$membersCount أعضاء'),
                          style: language == 'arabic'
                            ? GoogleFonts.tajawal(
                                color: Colors.grey,
                              )
                            : const TextStyle(
                                color: Colors.grey,
                              ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF5B905),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateGroupScreen(),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            height: 150,
            decoration: const BoxDecoration(
              color: Color(0xFFF5B905),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.group,
                      size: 40,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _translate('My Groups', 'مجموعاتي'),
                    style: language == 'arabic'
                      ? GoogleFonts.tajawal(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        )
                      : const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .where('members', arrayContains: _auth.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      _translate('Error: ', 'خطأ: ') + '${snapshot.error}',
                      style: language == 'arabic' ? GoogleFonts.tajawal() : null,
                    ),
                  );
                }

                final groups = snapshot.data?.docs ?? [];

                return ListView(
                  padding: const EdgeInsets.only(top: 16),
                  children: [
                    ...groups.map((group) {
                      final groupName = group['name'];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B905),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              groupName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          groupName,
                          style: language == 'arabic'
                            ? GoogleFonts.tajawal(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              )
                            : const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CombinedGroupScreen(
                                groupId: group.id,
                                groupName: groupName,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    const Divider(height: 20, thickness: 1, color: Colors.grey),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Color(0xFFF5B905)),
                      title: Text(
                        _translate('Create Group', 'إنشاء مجموعة'),
                        style: language == 'arabic'
                          ? GoogleFonts.tajawal(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            )
                          : const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateGroupScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.group_add, color: Color(0xFFF5B905)),
                      title: Text(
                        _translate('Join Group', 'انضم إلى مجموعة'),
                        style: language == 'arabic'
                          ? GoogleFonts.tajawal(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            )
                          : const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JoinGroupScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
          );
        },
      ),
    );
  }
}