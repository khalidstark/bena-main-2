import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  final Color primaryColor = const Color(0xFFFFC107); // Primary yellow
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = Colors.grey[50]!;
  final Color discountColor = const Color(0xFF4CAF50); // Green for discount
  final Color oldPriceColor = Colors.grey[600]!;
  final Color pointsColor = const Color(0xFFFFA000); // Dark yellow for points
  final Color successColor = const Color(0xFF4CAF50);
  final Color lightPurple = const Color(0xFFF3E5F5); // Very light purple for background

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _userPoints = 0;
  bool _isLoadingPoints = true;
  String? _redeemedCode;
  String? _redeemedOfferName;

  @override
  void initState() {
    super.initState();
    _getUserPoints();
  }

  Future<void> _getUserPoints() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get user points from score subcollection
        final scoresSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('score')
            .get();
        
        int totalPoints = 0;
        for (var doc in scoresSnapshot.docs) {
          final scoreData = doc.data()['score'];
          final numData = doc.data()['num'] ?? 0;
          
          if (scoreData != null) {
            // Calculate net points (score + num)
            final netScore = int.parse(scoreData.toString()) + (numData is int ? numData : int.parse(numData.toString()));
            totalPoints += netScore;
          }
        }
        
        setState(() {
          _userPoints = totalPoints;
          _isLoadingPoints = false;
        });
      }
    } catch (e) {
      print('Error fetching user points: $e');
      setState(() {
        _isLoadingPoints = false;
      });
    }
  }

  // Helper function to convert any value to integer
  int _parsePointsRequired(dynamic points) {
    if (points == null) return 0;
    if (points is int) return points;
    if (points is double) return points.toInt();
    if (points is String) {
      return int.tryParse(points) ?? 0;
    }
    return 0;
  }

  // Function to redeem offer
  Future<void> _redeemOffer(String offerId, Map<String, dynamic> data, int pointsRequired) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 1. Get user points to deduct
      final scoresSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('score')
          .orderBy('date')
          .get();

      if (scoresSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough points', style: GoogleFonts.tajawal())),
        );
        return;
      }

      int pointsToDeduct = pointsRequired;
      final batch = _firestore.batch();

      // Deduct points from oldest to newest using num field
      for (var doc in scoresSnapshot.docs) {
        if (pointsToDeduct <= 0) break;

        final scoreData = doc.data()['score'];
        if (scoreData != null) {
          final currentScore = int.parse(scoreData.toString());
          final currentNum = doc.data()['num'] ?? 0;
          final netScore = currentScore + (currentNum is int ? currentNum : int.parse(currentNum.toString()));
          
          if (netScore > 0) {
            final pointsAvailable = netScore;
            
            if (pointsAvailable >= pointsToDeduct) {
              // Update num field with deducted points
              final newNum = currentNum - pointsToDeduct;
              batch.update(doc.reference, {'num': newNum});
              pointsToDeduct = 0;
            } else {
              // Deduct all available points
              batch.update(doc.reference, {'num': currentNum - pointsAvailable});
              pointsToDeduct -= pointsAvailable;
            }
          }
        }
      }

      if (pointsToDeduct > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough points', style: GoogleFonts.tajawal())),
        );
        return;
      }

      // 2. Get a code from the codes list
      final offerDoc = await _firestore.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return;

      final codes = List<String>.from(offerDoc.data()?['codes'] ?? []);
      if (codes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No codes available', style: GoogleFonts.tajawal())),
        );
        return;
      }

      final usedCode = codes.first;
      final updatedCodes = codes.sublist(1);

      // 3. Update codes in the offer
      batch.update(offerDoc.reference, {
        'codes': updatedCodes,
        'usedCodes': FieldValue.arrayUnion([usedCode])
      });

      // 4. Add 5 to billing for the offer owner
      final offerOwnerId = data['userId'];
      if (offerOwnerId != null && offerOwnerId is String) {
        final userBillingRef = _firestore.collection('users').doc(offerOwnerId);
        final userDoc = await userBillingRef.get();
        
        if (userDoc.exists) {
          final currentBilling = userDoc.data()?['billing'] ?? 0;
          batch.update(userBillingRef, {'billing': currentBilling + 5});
        }
      }

      // Execute all operations
      await batch.commit();

      // Update local user points
      await _getUserPoints();
      
      setState(() {
        _redeemedCode = usedCode;
        _redeemedOfferName = data['placeName'] ?? '';
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offer redeemed successfully!', style: GoogleFonts.tajawal()),
          backgroundColor: successColor,
        ),
      );

    } catch (e) {
      print('Error redeeming offer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during redemption', style: GoogleFonts.tajawal())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightPurple,
      appBar: AppBar(
        title: Text(
          'Available Offers',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white, // Changed to white
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: pointsColor, size: 18),
                const SizedBox(width: 6),
                _isLoadingPoints
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pointsColor,
                        ),
                      )
                    : Text(
                        '$_userPoints',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.9),
              lightPurple.withOpacity(0.7),
            ],
          ),
        ),
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('offers').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading offers',
                        style: GoogleFonts.tajawal(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 60, color: primaryColor.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No offers available at the moment',
                          style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black87),
                     ) ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final pointsRequired = _parsePointsRequired(data['pointsRequired']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top offer image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                image: (data['logoUrl'] ?? '').isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(data['logoUrl']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (data['logoUrl'] ?? '').isEmpty
                                  ? Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: primaryColor,
                                        size: 50,
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.3),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                          ),

                          // Offer content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Place name and profile
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: primaryColor.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.white,
                                        backgroundImage: (data['profileImage'] ?? '').isNotEmpty
                                            ? NetworkImage(data['profileImage'])
                                            : null,
                                        child: (data['profileImage'] ?? '').isEmpty
                                            ? Icon(Icons.store, color: primaryColor, size: 18)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        data['placeName'] ?? '',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Offer title
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.tajawal(fontSize: 16, color: Colors.black),
                                    children: [
                                      TextSpan(
                                        text: '${data['discountPercentage']}% OFF ',
                                        style: GoogleFonts.tajawal(
                                            fontWeight: FontWeight.bold, color: discountColor),
                                      ),
                                      const TextSpan(text: 'on '),
                                      TextSpan(
                                        text: data['displayName'] ?? '',
                                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Price
                                Row(
                                  children: [
                                    Text(
                                      '${data['originalPrice'] ?? ''} EGP',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 14,
                                        color: oldPriceColor,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${data['discountedPrice'] ?? ''} EGP',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: discountColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Points required
                                Row(
                                  children: [
                                    Icon(Icons.star, color: pointsColor, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$pointsRequired points required',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Description
                                if ((data['offerDetails'] ?? '').isNotEmpty)
                                  Text(
                                    data['offerDetails'] ?? '',
                                    style: GoogleFonts.tajawal(
                                        fontSize: 14, color: Colors.black87),
                                  ),
                                const SizedBox(height: 20),

                                // Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _userPoints >= pointsRequired
                                        ? () => _redeemOffer(doc.id, data, pointsRequired)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      _userPoints >= pointsRequired ? 'REDEEM OFFER' : 'INSUFFICIENT POINTS',
                                      style: GoogleFonts.tajawal(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            
            // Show discount code after redemption
            if (_redeemedCode != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 60, color: successColor),
                            const SizedBox(height: 16),
                            Text(
                              'Offer Redeemed Successfully!',
                              style: GoogleFonts.tajawal(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'From $_redeemedOfferName',
                              style: GoogleFonts.tajawal(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: lightPurple,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryColor.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Your Discount Code:',
                                    style: GoogleFonts.tajawal(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _redeemedCode!,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'You can copy this code and use it at checkout',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _redeemedCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Code copied', style: GoogleFonts.tajawal()),
                                        backgroundColor: successColor,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: Text('COPY CODE', style: GoogleFonts.tajawal()),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _redeemedCode = null;
                                    });
                                  },
                                  child: Text('CLOSE', style: GoogleFonts.tajawal(color: Colors.black54)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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