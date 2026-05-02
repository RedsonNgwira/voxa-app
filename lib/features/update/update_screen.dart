import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

class UpdateScreen extends StatelessWidget {
  final String message;
  final String storeUrl;

  const UpdateScreen({super.key, required this.message, required this.storeUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8622A), Color(0xFFC0431A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const VoxaLogo(fontSize: 32),
              const SizedBox(height: 32),
              const Icon(Icons.system_update_rounded, size: 48, color: AppTheme.accent),
              const SizedBox(height: 16),
              const Text(
                'Update Required',
                style: TextStyle(
                  color: Color(0xFFF0E6D3),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: AppTheme.textDim, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(storeUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Update Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
