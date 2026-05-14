import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String phoneNumber;
  final String otp;

  const ResetPasswordPage({
    super.key,
    required this.phoneNumber,
    required this.otp,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final passwordRegex = RegExp(r'^(?=.*[0-9])(?=.*[\W_]).{8,50}$');

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String? passwordError;
  String? confirmPasswordError;

  bool isLoading = false;

  Future<void> _goToLoginWithConfirmation() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Return to Login?"),
          content: const Text(
            "Your OTP is already verified. If you go back now, you will return to the login page and need to start password recovery again.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Stay"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Go to Login"),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();

    passwordController.addListener(() {
      final text = passwordController.text.trim();

      setState(() {
        if (text.isEmpty) {
          passwordError = "Enter password";
        } else if (!passwordRegex.hasMatch(text)) {
          passwordError =
              "Password must be 8–50 chars, include number &\nspecial char";
        } else {
          passwordError = null;
        }
      });
    });

    confirmPasswordController.addListener(() {
      final confirm = confirmPasswordController.text.trim();

      setState(() {
        if (confirm.isEmpty) {
          confirmPasswordError = "Confirm your password";
        } else if (confirm != passwordController.text.trim()) {
          confirmPasswordError = "Passwords do not match";
        } else {
          confirmPasswordError = null;
        }
      });
    });
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> changePassword() async {
    final password = passwordController.text.trim();

    if (passwordError != null || confirmPasswordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fix errors before continuing")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resetPasswordEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "mobile": widget.phoneNumber,
          "otp": widget.otp,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Password updated")),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data["message"] ?? "Failed")));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Network error")));
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToLoginWithConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Reset Password"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goToLoginWithConfirmation,
          ),
        ),

        body: Padding(
          padding: const EdgeInsets.all(25),

          child: Column(
            children: [
            const SizedBox(height: 30),

            Text(
              "Create a new password",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: passwordController,
              obscureText: obscurePassword,

              decoration: InputDecoration(
                labelText: "New Password",
                errorText: passwordError,

                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,

              decoration: InputDecoration(
                labelText: "Confirm Password",
                errorText: confirmPasswordError,

                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: isLoading ? null : changePassword,

                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Change Password"),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
