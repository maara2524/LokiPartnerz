import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String message;
  final String storeUrl;
  final String storeLabel;

  const UpdateRequiredScreen({
    super.key,
    required this.message,
    required this.storeUrl,
    this.storeLabel = "Update App",
  });

  @override
  Widget build(BuildContext context) {
    final hasStoreUrl = storeUrl.trim().isNotEmpty;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update_alt, size: 80, color: Colors.blue),

              const SizedBox(height: 20),

              const Text(
                "Update Required",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasStoreUrl
                      ? () {
                          launchUrlString(
                            storeUrl,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      : null,
                  child: Text(storeLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
