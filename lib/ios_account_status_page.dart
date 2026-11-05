import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/api_config.dart';

/// Neutral account-help screen for the iOS companion app.
///
/// The iOS build does not show subscription plans, prices, purchase buttons,
/// renewal links, or registration. When an account cannot access the app, this
/// screen offers support and sign-out only.
class IosAccountStatusPage extends StatelessWidget {
  const IosAccountStatusPage({
    super.key,
    this.title = "Account not active",
    this.message =
        "Your Loki Partnerz account is not active. Contact support if you need help restoring access.",
    this.showSignOut = true,
  });

  final String title;
  final String message;
  final bool showSignOut;

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: ApiConfig.supportEmail,
      queryParameters: {'subject': 'Loki Partnerz iOS app - account access'},
    );

    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Contact Support"),
          content: Text(
            "Please email ${ApiConfig.supportEmail} and our team will help you with your account.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3E5F5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _contactSupport(context),
                      icon: const Icon(Icons.support_agent),
                      label: const Text(
                        "Contact Support",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (showSignOut) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _signOut(context),
                      child: const Text("Sign out"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
