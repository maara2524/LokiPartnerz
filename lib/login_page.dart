import 'package:bbm_app/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/api_config.dart';
import 'utils/network_utils.dart';
// import 'forgot_password_page.dart';
import 'admin/admin_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Duration _requestTimeout = Duration(seconds: 20);

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String errorMessage = "";
  bool _obscurePassword = true;

  Widget _centeredFaIcon(FaIcon icon, double size) {
    return SizedBox.square(
      dimension: size,
      child: Center(child: icon),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      errorMessage = message;
      isLoading = false;
    });
  }

  Map<String, dynamic>? _tryParseJsonObject(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Let the caller handle non-JSON responses gracefully.
    }

    return null;
  }

  // Sends the FCM token to your backend server using stored API token
  Future<void> _sendTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userAuthToken = prefs.getString('auth_token');

      if (userAuthToken == null || userAuthToken.isEmpty) {
        debugPrint('Debug : No user auth token found. Skipping FCM upload.');
        return;
      }

      const String apiUrl = ApiConfig.saveFCMTokenEndpoint;

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_token': userAuthToken, 'fcm_token': token}),
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Debug : FCM token sent successfully to backend');
        } else {
          debugPrint('Debug : Failed to update token: ${data['message']}');
        }
      } else {
        debugPrint('Debug : Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Debug : Error sending token: $e');
    }
  }

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      // Check internet connection
      await NetworkUtils.checkConnectivity();
      var url = Uri.parse(ApiConfig.loginEndpoint);
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": emailController.text.trim(),
          "password": passwordController.text.trim(),
        }),
      ).timeout(_requestTimeout);

      // print('Response status: ${response.statusCode}');
      // print('Response body: ${response.body}');
      debugPrint('Debug : Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          _showError("Server returned empty response");
          return;
        }

        final data = _tryParseJsonObject(response.body);
        if (data == null) {
          _showError("Server returned invalid JSON");
          return;
        }

        if (data['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("auth_token", data["token"]);
          await prefs.setInt("user_id", data["user"]["id"]);
          await prefs.setInt("level", data["user"]["level"]);
          await prefs.setString("username", data["user"]["username"]);
          await prefs.setString("role", data["user"]["role"]);
          await prefs.setString("status", data["user"]["status"]);
          await prefs.setString(
            "business_name",
            data["user"]["business_name"] ?? "",
          );

          String? fcmToken = prefs.getString('fcm_token');
          if (fcmToken != null && fcmToken.isNotEmpty) {
            debugPrint('Debug : Sending stored FCM token after login...');
            await _sendTokenToServer(fcmToken);
          }

          if (mounted) {
            final String role =
                (data["user"]["role"] ?? "").toString().toLowerCase();
            final int level = (data["user"]["level"] ?? 0) as int;
            final String status =
                (data["user"]["status"] ?? "").toString().toLowerCase();

            if (role == "admin") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminShell()),
              );
            } else if (role == "telecaller") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MainShell()),
              );
            } else if (level == 5 || status == "inactive") {
              Navigator.pushReplacementNamed(context, "/Subscription");
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MainShell()),
              );
            }
          }
        } else {
          setState(() {
            errorMessage = data["error"] ?? "Login failed";
            isLoading = false;
          });
        }
      } else {
        final errorData = _tryParseJsonObject(response.body);
        final fallbackMessage = response.body.trim().isEmpty
            ? "Server error: Empty response (${response.statusCode})"
            : "Server error ${response.statusCode}. Please try again.";

        setState(() {
          errorMessage =
              errorData?["error"]?.toString() ??
              errorData?["message"]?.toString() ??
              fallbackMessage;
          isLoading = false;
        });
      }
    } on NetworkException catch (e) {
      _showError(e.message);
    } on TimeoutException catch (e) {
      _showError(NetworkUtils.friendlyMessageFor(e));
    } on http.ClientException catch (e) {
      _showError(NetworkUtils.friendlyMessageFor(e));
    } catch (e) {
      _showError(NetworkUtils.friendlyMessageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 30),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Placeholder
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue.shade100,
                        child: _centeredFaIcon(
                          const FaIcon(
                            FontAwesomeIcons.userShield,
                            size: 40,
                            color: Colors.blue,
                          ),
                          40,
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Welcome Back!",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Login to continue",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Username Field
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          prefixIcon: _centeredFaIcon(
                            const FaIcon(FontAwesomeIcons.user, size: 24),
                            24,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelText: "Username",
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Password Field
                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: _centeredFaIcon(
                            const FaIcon(FontAwesomeIcons.lock, size: 24),
                            24,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelText: "Password",
                        ),
                      ),

                      const SizedBox(height: 5),

                      if (errorMessage.isNotEmpty)
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),

                      const SizedBox(height: 5),
                      // Align(
                      //   alignment: Alignment.centerRight,
                      //   child: TextButton(
                      //     onPressed: () {
                      //       Navigator.push(
                      //         context,
                      //         MaterialPageRoute(
                      //           builder: (_) => const ForgotPasswordPage(),
                      //         ),
                      //       );
                      //     },
                      //     child: Text(
                      //       "Forgot Password?",
                      //       style: GoogleFonts.poppins(
                      //         fontSize: 13,
                      //         fontWeight: FontWeight.w500,
                      //         color: Colors.blue,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(height: 5),
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: isLoading ? null : loginUser,
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  "Login",

                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Sign up & Admin login placeholders
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text("Create a new account? Sign Up"),
                          ),
                          const SizedBox(width: 10),
                          // TextButton(
                          //   onPressed: () {
                          //     ScaffoldMessenger.of(context).showSnackBar(
                          //       const SnackBar(
                          //         content: Text("Admin Login"),
                          //       ),
                          //     );
                          //   },
                          //   child: const Text("Admin Login"),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
