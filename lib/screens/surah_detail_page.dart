import 'package:flutter/material.dart';

class SurahDetailPage extends StatelessWidget {
  final int surahNumber;
  final String surahName;
  final List<Map<String, dynamic>> ayahs;

  const SurahDetailPage({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.ayahs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image (same as QuranPage)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/quran_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // App Bar with back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      'سورة $surahName',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Lateef',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      surahNumber.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Ayah list
                Expanded(
                  child: ListView.builder(
                    itemCount: ayahs.length,
                    itemBuilder: (context, index) {
                      final ayah = ayahs[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Arabic text
                              Text(
                                ayah['text'] ?? '',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontFamily: 'Lateef',
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Ayah number
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  ayah['numberInSurah'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}