import 'package:flutter/material.dart';

class PrizesScreen extends StatelessWidget {
  const PrizesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6), // Soft cream background
      appBar: AppBar(
        title: const Text(
          "Monthly Prizes",
          style: TextStyle(
            color: Color(0xFF5D4037), // Deep brown
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, 
              color: Color(0xFF5D4037), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header with decorative elements
              Stack(
                alignment: Alignment.center,
                children: [
                  
                  const Text(
                    "",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "This month's exclusive prizes for our most focused users",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF795548),
                ),
              ),
              const SizedBox(height: 30),
              
              // First Place Prize (Gold)
              _buildPrizeCard(
                place: "1st Place",
                color: Color(0xFFFFD700), // Gold
                asset: 'assets/Mugs.png',
                title: "Premium Mug Set",
                height: 180,
              ),
              const SizedBox(height: 25),
              
              // Second Place Prize (Silver)
              _buildPrizeCard(
                place: "2nd Place",
                color: Color(0xFFC0C0C0), // Silver
                asset: 'assets/Notebook.png',
                title: "Designer Notebook",
                height: 200,
              ),
              const SizedBox(height: 25),
              
              // Third Place Prize (Bronze)
              _buildPrizeCard(
                place: "3rd Place",
                color: Color(0xFFCD7F32), // Bronze
                asset: 'assets/Screenshot_1.png',
                title: "Productivity Kit",
                height: 170,
              ),
              
              // Motivational Footer
              const Padding(
                padding: EdgeInsets.only(top: 30, bottom: 20),
                child: Text(
                  "Keep focusing to win next month!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPrizeCard({
    required String place,
    required Color color,
    required String asset,
    required String title,
    required double height,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Place ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                place,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            // Prize image with decorative frame
            Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            // Prize title
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}