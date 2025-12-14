import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupMembersScreen({
    super.key, 
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late Timer _scoreUpdateTimer;
  int _totalScore = 0;
  Map<String, int> _memberScores = {};
  bool _isLoading = false;
  bool _isEditingName = false;
  bool _isEditingDescription = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scoreUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateGroupTotalScore();
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _updateGroupTotalScore();
    
    // Load group details
    final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
    if (groupDoc.exists) {
      final groupData = groupDoc.data() as Map<String, dynamic>;
      _nameController.text = groupData['name'] ?? widget.groupName;
      _descriptionController.text = groupData['description'] ?? '';
    }
    
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _scoreUpdateTimer.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _updateGroupTotalScore() async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final List<dynamic> memberIds = groupData['members'] ?? [];

      if (memberIds.isEmpty) {
        if (mounted) {
          setState(() {
            _totalScore = 0;
            _memberScores = {};
          });
        }
        return;
      }

      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final Map<String, int> newMemberScores = {};
      int sumScore = 0;

      await Future.wait(
        memberIds.map((id) async {
          final scoresSnapshot = await _firestore
              .collection('users')
              .doc(id)
              .collection('score')
              .where(FieldPath.documentId, isGreaterThanOrEqualTo: '$monthKey-01')
              .where(FieldPath.documentId, isLessThanOrEqualTo: '$monthKey-31')
              .get();

          int monthlyScore = 0;
          for (final doc in scoresSnapshot.docs) {
            monthlyScore += (doc.data()['score'] as num).toInt();
          }

          newMemberScores[id] = monthlyScore;
          sumScore += monthlyScore;
        }),
      );

      final totalScore = (sumScore / memberIds.length).round();

      await _firestore.collection('groups').doc(widget.groupId).update({
        'totalScore': totalScore,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _totalScore = totalScore;
          _memberScores = newMemberScores;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update scores: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateGroupName() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('groups').doc(widget.groupId).update({
        'name': _nameController.text.trim(),
      });
      
      setState(() {
        _isEditingName = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group name updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update group name: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateGroupDescription() async {
    try {
      await _firestore.collection('groups').doc(widget.groupId).update({
        'description': _descriptionController.text.trim(),
      });
      
      setState(() {
        _isEditingDescription = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update description: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRemoveConfirmation(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $userName from ${widget.groupName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('groups').doc(widget.groupId).update({
                  'members': FieldValue.arrayRemove([userId]),
                });
                await _updateGroupTotalScore();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$userName has been removed'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove member: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  Widget _buildMemberItem({
    required String userId,
    required String name,
    required int score,
    required bool isAdmin,
    required bool isCurrentUserAdmin,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? const Color(0xFFF5B905) : Colors.grey[200],
          child: Icon(
            isAdmin ? Icons.star : Icons.person,
            color: isAdmin ? Colors.black : Colors.black54,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Score: $score',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: isCurrentUserAdmin && !isAdmin
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => _showRemoveConfirmation(userId, name),
              )
            : null,
      ),
    );
  }

  Widget _buildGroupScoreCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5B905).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'GROUP TOTAL SCORE',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _totalScore.toString(),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameField(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Group Name",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (isAdmin) 
                IconButton(
                  icon: Icon(_isEditingName ? Icons.check : Icons.edit),
                  onPressed: () {
                    if (_isEditingName) {
                      _updateGroupName();
                    } else {
                      setState(() {
                        _isEditingName = true;
                      });
                      // Focus on the text field after a short delay
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _nameFocusNode.requestFocus();
                      });
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          _isEditingName
              ? TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isEditingName = false;
                          _nameController.text = widget.groupName;
                        });
                      },
                    ),
                  ),
                  onFieldSubmitted: (value) {
                    _updateGroupName();
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _nameController.text,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildGroupDescriptionField(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Group Description",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (isAdmin) 
                IconButton(
                  icon: Icon(_isEditingDescription ? Icons.check : Icons.edit),
                  onPressed: () {
                    if (_isEditingDescription) {
                      _updateGroupDescription();
                    } else {
                      setState(() {
                        _isEditingDescription = true;
                      });
                      // Focus on the text field after a short delay
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _descriptionFocusNode.requestFocus();
                      });
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          _isEditingDescription
              ? TextFormField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocusNode,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isEditingDescription = false;
                          // Reset to original description
                          _descriptionController.text = _descriptionController.text;
                        });
                      },
                    ),
                  ),
                  onFieldSubmitted: (value) {
                    _updateGroupDescription();
                  },
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _descriptionController.text.isEmpty 
                              ? "No description added" 
                              : _descriptionController.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: _descriptionController.text.isEmpty 
                                ? Colors.grey 
                                : Colors.black,
                            fontStyle: _descriptionController.text.isEmpty 
                                ? FontStyle.italic 
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildInviteLinkSection(String groupLink) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Group Invite Link",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: groupLink));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Group link copied to clipboard!"),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFFF5B905),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      groupLink,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, size: 20, color: Colors.black54),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[400],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showDeleteGroupDialog(),
          child: const Text(
            'DELETE GROUP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteGroupDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('This will permanently delete the group and all its data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('groups').doc(widget.groupId).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Group deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete group: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.groupName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _updateGroupTotalScore,
            tooltip: 'Refresh Scores',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
              builder: (context, groupSnapshot) {
                if (!groupSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
                    ),
                  );
                }

                final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
                final List<dynamic> memberIds = groupData['members'] ?? [];
                final String groupLink = groupData['groupLink'] ?? '';
                final String adminId = groupData['admin'] ?? '';
                final bool isCurrentUserAdmin = adminId == currentUserId;

                // Update controllers with latest data
                if (groupSnapshot.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_nameController.text != groupData['name']) {
                      _nameController.text = groupData['name'] ?? widget.groupName;
                    }
                    if (_descriptionController.text != (groupData['description'] ?? '')) {
                      _descriptionController.text = groupData['description'] ?? '';
                    }
                  });
                }

                if (memberIds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/empty_group.png',
                          width: 150,
                          height: 150,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No members in this group',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Back to Groups',
                            style: TextStyle(color: Color(0xFFF5B905)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: memberIds)
                      .snapshots(),
                  builder: (context, membersSnapshot) {
                    if (!membersSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5B905)),
                        ),
                      );
                    }

                    final members = membersSnapshot.data!.docs;

                    return ListView(
                      children: [
                        _buildGroupScoreCard(),
                        _buildGroupNameField(isCurrentUserAdmin),
                        _buildGroupDescriptionField(isCurrentUserAdmin),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Text(
                                'Members',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${members.length} members',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: members.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final memberData = member.data() as Map<String, dynamic>;
                            final userId = member.id;
                            final name = memberData['name'] ?? 'Unknown';
                            final score = _memberScores[userId] ?? 0;
                            final isAdmin = userId == adminId;

                            return _buildMemberItem(
                              userId: userId,
                              name: name,
                              score: score,
                              isAdmin: isAdmin,
                              isCurrentUserAdmin: isCurrentUserAdmin,
                            );
                          },
                        ),
                        _buildInviteLinkSection(groupLink),
                        if (isCurrentUserAdmin) _buildDeleteButton(),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}