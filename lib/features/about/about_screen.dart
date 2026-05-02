import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
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
              const SizedBox(height: 20),
              const VoxaLogo(fontSize: 32),
              const SizedBox(height: 8),
              Text(
                'Where your voice actually matters',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 24),
              Text('Built by', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                'Redson Ngwira',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF0E6D3),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://twitter.com/redsonngwira'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alternate_email, size: 16, color: AppTheme.accent),
                      SizedBox(width: 6),
                      Text('redsonngwira',
                          style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text('Version 1.0.0',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  )),
              const SizedBox(height: 4),
              Text('Made for the world 🌍',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
