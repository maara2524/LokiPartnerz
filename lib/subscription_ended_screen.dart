import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bbm_app/widgets/app_error_view.dart';

class SubscriptionEndedScreen extends StatelessWidget {
  const SubscriptionEndedScreen({super.key});

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _goToPlans(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, "/Subscription", (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToPlans(context);
      },
      child: Scaffold(
        body: AppErrorView(
          icon: Icons.lock_outline,
          title: _isIOS ? "Lead limit reached" : "Subscription Ended",
          message: _isIOS
              ? "You have reached the lead limit for your account. Choose a plan to continue claiming leads."
              : "You have reached your maximum lead claim limit for this plan. Please upgrade or renew your subscription to continue claiming leads.",
          buttonText: _isIOS ? "View Plans" : "View Subscription Plans",
          onPressed: () => _goToPlans(context),
        ),
      ),
    );
  }
}
