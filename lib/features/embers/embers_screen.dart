import 'package:flutter/material.dart';
import '../../core/theme.dart';

class EmbersScreen extends StatelessWidget {
  const EmbersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voxa Embers')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE8622A), Color(0xFFC0431A)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 20),
            Text('Voxa Embers', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('An invitation, not a sales pitch.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 40),
            // 4 benefits per spec 7.13
            ...[
              (Icons.bookmark_outline_rounded, 'Preserve voices before they disappear', 'Remove the 72h expiry from any clip.'),
              (Icons.mic_rounded, 'Post up to 5 minutes', 'Standard accounts get 3 minutes.'),
              (Icons.lock_outline_rounded, 'Create private Circles', 'Invite-only circles for your closest voices.'),
              (Icons.auto_awesome_rounded, 'Voice themes', 'Warmth, clarity, depth.'),
            ].map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(b.$1, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.$2, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(b.$3, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  )),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Text('\$3/month', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // Waitlist CTA (no Stripe yet)
            ElevatedButton(
              onPressed: () => _showWaitlist(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.accent,
              ),
              child: const Text('Join the waitlist'),
            ),
            const SizedBox(height: 12),
            Text('Payments coming soon. No pressure.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showWaitlist(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("You're on the list"),
        content: const Text("We'll reach out when Embers launches."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
      ),
    );
  }
}
