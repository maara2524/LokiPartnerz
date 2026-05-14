import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../theme/bbm_theme.dart';

class TelecallerDashboardPage extends StatefulWidget {
  const TelecallerDashboardPage({super.key});

  @override
  State<TelecallerDashboardPage> createState() =>
      _TelecallerDashboardPageState();
}

class _TelecallerDashboardPageState extends State<TelecallerDashboardPage> {
  bool isLoading = true;
  bool _sessionExpired = false;
  String? _errorMessage;

  int totalContacted = 0;
  int notesTotal = 0;
  int interestedTotal = 0;
  int totalCalls = 0;

  int callsToday = 0;
  int notesToday = 0;
  int interestedToday = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _handleSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _fetchDashboard() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _sessionExpired = false;
        _errorMessage = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null) {
        await _handleSessionExpired();
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.telecallerDashboardEndpoint}?token=$token"),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint("Debug : Dashboard data: $data");

      final errorText = (data["error"] ?? data["message"] ?? "")
          .toString()
          .toLowerCase();
      final bool isSessionExpired =
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          errorText.contains("invalid or expired token") ||
          errorText.contains("authentication token required") ||
          errorText.contains("permission");

      if (isSessionExpired) {
        if (!mounted) return;
        setState(() {
          _sessionExpired = true;
          isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        if (data["success"] == true) {
          totalContacted = data["total_contacted"] ?? 0;
          totalCalls = data["total_calls"] ?? 0;
          notesTotal = data["notes_added_total"] ?? 0;
          interestedTotal = data["interested_leads_total"] ?? 0;

          callsToday = data["calls_today"] ?? 0;
          notesToday = data["notes_today"] ?? 0;
          interestedToday = data["interested_today"] ?? 0;
        } else {
          _errorMessage =
              (data["error"] ?? data["message"] ?? "Failed to load dashboard")
                  .toString();
        }

        isLoading = false;
      });
    } catch (e) {
      debugPrint("Debug : Dashboard error: $e");

      if (!mounted) return;

      setState(() {
        _errorMessage = "Unable to load dashboard right now. Please try again.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_sessionExpired) {
      return Scaffold(
        backgroundColor: BBMTheme.primaryLight,
        body: _buildMessageState(
          title: 'Session Expired',
          message:
              'Your account was logged in on another device. Please login again to continue.',
          buttonText: 'Login Now',
          onPressed: _handleSessionExpired,
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: BBMTheme.primaryLight,
        body: _buildMessageState(
          title: 'Connection Problem',
          message: _errorMessage!,
          buttonText: 'Retry',
          onPressed: _fetchDashboard,
        ),
      );
    }

    return Scaffold(
      backgroundColor: BBMTheme.primaryLight,

      body: RefreshIndicator(
        onRefresh: _fetchDashboard,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            const SizedBox(height: 10),

            const SizedBox(height: 20),

            Row(
              children: [
                _statCard(
                  title: "Leads Contacted",
                  value: totalContacted,
                  icon: Icons.people_alt,
                  color: Colors.blue,
                ),

                _statCard(
                  title: "Total Calls",
                  value: totalCalls,
                  icon: Icons.call,
                  color: Colors.green,
                ),
              ],
            ),

            Row(
              children: [
                _statCard(
                  title: "Notes Added",
                  value: notesTotal,
                  icon: Icons.note,
                  color: Colors.orange,
                ),

                _statCard(
                  title: "Interested Leads",
                  value: interestedTotal,
                  icon: Icons.thumb_up,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 20),

            _activitySummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 54, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BBMTheme.border),
        ),

        child: Column(
          children: [
            Icon(icon, color: color, size: 28),

            const SizedBox(height: 12),

            Text(
              value.toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activitySummary() {
    final todayIstLabel = _todayIstLabel();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BBMTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.today_outlined,
                color: BBMTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Today's Activity",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: BBMTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BBMTheme.border),
                ),
                child: Text(
                  todayIstLabel,
                  style: const TextStyle(
                    color: BBMTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          _activityRow("📞 Calls Made", callsToday, Colors.green),

          const SizedBox(height: 12),

          _activityRow("📝 Notes Written", notesToday, Colors.orange),

          const SizedBox(height: 12),

          _activityRow(
            "🔥 Interested Customers",
            interestedToday,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  String _todayIstLabel() {
    final nowIst = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = nowIst.day.toString().padLeft(2, '0');

    return '$day ${months[nowIst.month - 1]} ${nowIst.year}';
  }

  Widget _activityRow(String label, int value, MaterialColor purple) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),

          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
