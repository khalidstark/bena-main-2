import 'package:flutter/material.dart';
import 'package:proft/screens/players_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpecificDaysScreen extends StatelessWidget {
  final String challengeName;
  final String challengeId;
  const SpecificDaysScreen({
    super.key, 
    required this.challengeName,
    required this.challengeId
  });

  Future<List<String>> _getPlayerIds() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();
      
      final players = doc.data()?['players'] as List<dynamic>? ?? [];
      return players.map((id) => id.toString()).toList();
    } catch (e) {
      print('Error fetching player IDs: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(challengeName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () async {
              final playerIds = await _getPlayerIds();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayersListScreen(
                    challengeId: challengeId,
                    playerIds: playerIds, challengeName: '',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text("Hello from Specific Days"),
      ),
    );
  }
}