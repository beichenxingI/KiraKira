import 'package:flutter/material.dart';

class ApiServicesTab extends StatelessWidget {
  const ApiServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(title: const Text('API \u670d\u52a1', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard('\u5bf9\u8bdd\u6a21\u578b', Icons.chat_bubble_rounded, '\u914d\u7f6e\u7528\u4e8e\u5bf9\u8bdd\u7684\u5927\u8bed\u8a00\u6a21\u578b\uff0c\u5982 DeepSeek\u3001OpenAI\u3001Claude \u7b49'),
          const SizedBox(height: 12),
          _buildCard('\u7ed8\u56fe\u6a21\u578b', Icons.image_rounded, '\u914d\u7f6e\u7528\u4e8e\u751f\u6210\u56fe\u7247\u7684\u6a21\u578b\uff0c\u5982 Stable Diffusion\u3001DALL-E \u7b49'),
          const SizedBox(height: 12),
          _buildCard('\u8bed\u97f3\u5408\u6210', Icons.volume_up_rounded, '\u914d\u7f6e\u5c06\u6587\u672c\u8f6c\u6362\u4e3a\u8bed\u97f3\u7684\u670d\u52a1\uff0c\u5982 Azure TTS\u3001Edge TTS \u7b49'),
          const SizedBox(height: 12),
          _buildCard('\u8bed\u97f3\u8bc6\u522b', Icons.mic_rounded, '\u914d\u7f6e\u5c06\u8bed\u97f3\u8f6c\u6362\u4e3a\u6587\u672c\u7684\u670d\u52a1\uff0c\u5982 Whisper\u3001Azure STT \u7b49'),
        ],
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, String desc) {
    return Card(
      color: Colors.white.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: const Color(0xFFFCD34D), size: 24),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFFFCD34D).withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text('\u70b9\u51fb\u914d\u7f6e', style: TextStyle(color: const Color(0xFFFCD34D).withValues(alpha: 0.7))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}