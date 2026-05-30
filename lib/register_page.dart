import 'dart:convert';
import 'meta_events.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config/api_config.dart';
import 'utils/network_utils.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessController = TextEditingController();
  final _contactController = TextEditingController();
  final _instagramController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _couponController = TextEditingController();

  // Category
  String? _selectedCategory;
  List<String> serviceCategories = [];

  // Error messages
  String? whatsappError;
  String? businessError;
  String? contactError;
  String? instagramError;
  String errorMessage = "";

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadServiceCategories();

    // Dynamic WhatsApp validation
    _whatsappController.addListener(() {
      final text = _whatsappController.text.trim();
      final whatsappRegex = RegExp(r'^[0-9]{10}$');

      setState(() {
        if (text.isEmpty) {
          whatsappError = "Enter WhatsApp number";
        } else if (!whatsappRegex.hasMatch(text)) {
          whatsappError = "WhatsApp number must be exactly 10 digits";
        } else {
          whatsappError = null;
        }
      });
    });

    // Dynamic Instagram URL validation
    _instagramController.addListener(() {
      final text = _instagramController.text.trim();
      setState(() {
        if (text.isEmpty) {
          instagramError = null;
        } else if (!text.startsWith('https://www.instagram.com/')) {
          instagramError =
              "Enter a valid Instagram profile URL \n(https://www.instagram.com/yourname)";
        } else {
          instagramError = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _businessController.dispose();
    _contactController.dispose();
    _instagramController.dispose();
    _whatsappController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.pinkAccent),
      filled: true,
      fillColor: Colors.white,

      errorMaxLines: 3,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
      ),
    );
  }

  Future<void> loadServiceCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/mobile_api/get-service-categories.php'),
      );

      debugPrint(response.body.toString());

      final data = jsonDecode(response.body);

      if (data['success']) {
        setState(() {
          serviceCategories = List<String>.from(data['categories']);
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      final whatsapp = _whatsappController.text.trim();
      final password = whatsapp; // Password is set to WhatsApp number initially
      final business = _businessController.text.trim();
      final contact = _contactController.text.trim();
      final instagram = _instagramController.text.trim();
      final category = _selectedCategory ?? "";
      final coupon = _couponController.text.trim();

      setState(() {
        isLoading = true;
        errorMessage = "";
      });

      try {
        await NetworkUtils.checkConnectivity();
        var url = Uri.parse(ApiConfig.registerEndpoint);
        var response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "whatsapp": whatsapp,
            "password": password,
            "business_name": business,
            "contact_person": contact,
            "instagram": instagram,
            "category": category,
            "coupon_code": coupon.isNotEmpty ? coupon : null,
          }),
        );

        debugPrint(
          "Debug : status code: ${response.statusCode} | from register page",
        );
        Map<String, dynamic>? data;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {}

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (data == null) {
            setState(() {
              errorMessage = "Server returned an invalid response.";
            });
            return;
          }

          if (data['success'] == true) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString("auth_token", data["token"]);
            await prefs.setInt("user_id", data["user"]["id"]);
            await prefs.setInt("level", data["user"]["level"]);
            await prefs.setString("username", data["user"]["username"]);
            await prefs.setString("role", data["user"]["role"]);
            await prefs.setString(
              "status",
              data["user"]["status"] ?? "inactive",
            );
            await prefs.setString(
              "business_name",
              data["user"]["business_name"] ?? "",
            );

            debugPrint(
              "Debug : META DEBUG: CompleteRegistration about to fire",
            );
            facebookAppEvents.logEvent(name: 'CompleteRegistration');
            debugPrint("Debug : META DEBUG: CompleteRegistration fired");
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text("Registration Successful"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Here are your login credentials. Please write them down or take a screenshot:",
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "Login ID: ${data!['user']['username']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.pink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Password: $whatsapp",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.pink,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Use these credentials whenever you log in.",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.pushReplacementNamed(
                          context,
                          "/Subscription",
                        );
                      },
                      child: const Text(
                        "OK",
                        style: TextStyle(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          } else {
            setState(() {
              errorMessage =
                  data!["error"]?.toString() ??
                  data["message"]?.toString() ??
                  "Registration failed. Please try again.";
            });
          }
        } else {
          final errors = data?["errors"];
          final errorText = errors is Map
              ? errors.values.map((value) => value.toString()).join("\n")
              : null;

          setState(() {
            errorMessage =
                errorText ??
                data?["error"]?.toString() ??
                data?["message"]?.toString() ??
                "Registration failed. Please try again.";
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  "Loki Partnerz",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade800,
                  ),
                ),
                const SizedBox(height: 30),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // WhatsApp
                      TextFormField(
                        controller: _whatsappController,
                        decoration: _inputDecoration(
                          "WhatsApp Number",
                          FontAwesomeIcons.whatsapp,
                        ).copyWith(errorText: whatsappError),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),

                      // Business Name
                      TextFormField(
                        controller: _businessController,
                        decoration: _inputDecoration(
                          "Business Name",
                          Icons.store,
                        ).copyWith(errorText: businessError),
                        validator: (value) =>
                            value!.isEmpty ? "Enter business name" : null,
                      ),
                      const SizedBox(height: 15),

                      // Contact Person
                      TextFormField(
                        controller: _contactController,
                        decoration: _inputDecoration(
                          "Person Name",
                          Icons.person_pin,
                        ).copyWith(errorText: contactError),
                        validator: (value) =>
                            value!.isEmpty ? "Enter contact person" : null,
                      ),
                      const SizedBox(height: 15),

                      // Instagram Profile URL
                      TextFormField(
                        controller: _instagramController,
                        decoration:
                            _inputDecoration(
                              "Instagram Profile Link",
                              FontAwesomeIcons.instagram,
                            ).copyWith(
                              errorText: instagramError,
                              errorMaxLines: 3,
                              hintText: "https://www.instagram.com/yourname",
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  FontAwesomeIcons.arrowUpRightFromSquare,
                                  color: Colors.pinkAccent,
                                  size: 18,
                                ),
                                tooltip:
                                    "Open Instagram to copy your profile link",
                                onPressed: () async {
                                  final uri = Uri.parse(
                                    'https://www.instagram.com/',
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                            ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Enter your Instagram profile link";
                          }
                          if (!value.trim().startsWith(
                            'https://www.instagram.com/',
                          )) {
                            return "Link must start with https://www.instagram.com/";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Category (Dropdown)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: _inputDecoration(
                          "Service Category",
                          Icons.category,
                        ),
                        items: serviceCategories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? "Select category"
                            : null,
                      ),
                      const SizedBox(height: 15),

                      // Coupon Code (optional)
                      TextFormField(
                        controller: _couponController,
                        decoration: _inputDecoration(
                          "Coupon Code (optional)",
                          Icons.local_offer,
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 25),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: _registerUser,
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Register",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Already have account
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, "/login");
                        },
                        child: const Text(
                          "Already have an account? Login",
                          style: TextStyle(color: Colors.pink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
