import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudyPage extends StatefulWidget {
  final String groupName;
  final String groupId;

  const StudyPage({
    super.key,
    required this.groupName,
    required this.groupId,
  });

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  late Stream<List<Map<String, dynamic>>> _membersStream;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _membersStream = _fetchGroupMembers();
  }

  Stream<List<Map<String, dynamic>>> _fetchGroupMembers() {
    return _firestore.collection('groups').doc(widget.groupId).snapshots().asyncMap((groupSnapshot) async {
      if (!groupSnapshot.exists) return [];

      final members = List<String>.from(groupSnapshot.data()?['members'] ?? []);
      final users = <Map<String, dynamic>>[];

      for (final memberId in members) {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          users.add({
            'id': memberId,
            'name': userDoc.data()?['name'] ?? 'Unknown',
            'isActive': userDoc.data()?['IsActive'] ?? false,
          });
        }
      }

      return users;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "${widget.groupName}'s Study Room",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black54),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Room for ${widget.groupName}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.amber[700],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Group Members',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _membersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading members',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  final members = snapshot.data ?? [];

                  if (members.isEmpty) {
                    return Center(
                      child: Text(
                        'No members found',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return _buildMemberCard(member);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      member['isActive'] ? 'assets/study.png' : 'assets/phone.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      member['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: member['isActive'] ? Colors.green[400] : Colors.red[400],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: member['isActive']
                                ? Colors.green[100]!
                                : Colors.red[100]!,
                            spreadRadius: 2,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}