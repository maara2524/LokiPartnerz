import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AdminApiException implements Exception {
  final String message;
  final int? statusCode;

  const AdminApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AdminApiService {
  const AdminApiService();

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw const AdminApiException('Session expired. Please login again.');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final response = await http.get(Uri.parse(url), headers: await _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response shape');
      }
      data = decoded;
    } catch (_) {
      throw AdminApiException(
        'Server returned an invalid response. Please try again.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400 || data['success'] == false) {
      throw AdminApiException(
        (data['error'] ?? data['message'] ?? 'Request failed').toString(),
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> fetchDashboard() async {
    return _get(ApiConfig.adminDashboardEndpoint);
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final data = await _get(ApiConfig.adminUsersEndpoint);
    return List<Map<String, dynamic>>.from(data['users'] as List);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) async {
    return _post(ApiConfig.adminUserCreateEndpoint, payload);
  }

  Future<void> updateUser(Map<String, dynamic> payload) async {
    await _post(ApiConfig.adminUserUpdateEndpoint, payload);
  }

  Future<void> toggleUserStatus(int id, String status) async {
    await _post(ApiConfig.adminUserToggleStatusEndpoint, {
      'id': id,
      'status': status,
    });
  }

  Future<void> deleteUser(int id) async {
    await _post(ApiConfig.adminUserDeleteEndpoint, {'id': id});
  }

  Future<void> grantPlan(int id, String planSlug) async {
    await _post(ApiConfig.adminUserGrantPlanEndpoint, {
      'id': id,
      'plan_slug': planSlug,
    });
  }

  Future<List<Map<String, dynamic>>> fetchLeads() async {
    final data = await _get(ApiConfig.adminLeadsEndpoint);
    return List<Map<String, dynamic>>.from(data['leads'] as List);
  }

  Future<Map<String, dynamic>> fetchLeadDetail(int id) async {
    return _get('${ApiConfig.adminLeadDetailEndpoint}?id=$id');
  }

  Future<void> updateLead(Map<String, dynamic> payload) async {
    await _post(ApiConfig.adminLeadUpdateEndpoint, payload);
  }

  Future<void> unlockLead(int id) async {
    await _post(ApiConfig.adminLeadUnlockEndpoint, {'id': id});
  }

  Future<void> deleteLead(int id) async {
    await _post(ApiConfig.adminLeadDeleteEndpoint, {'id': id});
  }

  Future<Map<String, dynamic>> releaseAllLockedLeads() async {
    return _post(ApiConfig.adminReleaseAllLeadsEndpoint, {});
  }

  Future<Map<String, dynamic>> fetchSubscriptions() async {
    return _get(ApiConfig.adminSubscriptionsEndpoint);
  }

  Future<void> updatePlan(Map<String, dynamic> payload) async {
    await _post(ApiConfig.adminSubscriptionPlanUpdateEndpoint, payload);
  }

  Future<Map<String, dynamic>> fetchSettings() async {
    return _get(ApiConfig.adminSettingsEndpoint);
  }

  Future<void> updateVersion(Map<String, dynamic> payload) async {
    await _post(ApiConfig.adminSettingsUpdateVersionEndpoint, payload);
  }

  Future<void> updateToggles(Map<String, dynamic> payload) async {
    await _post(ApiConfig.adminSettingsUpdateTogglesEndpoint, payload);
  }

  Future<Map<String, dynamic>> updateUiConfig(Map<String, dynamic> payload) async {
    return _post(ApiConfig.adminSettingsUpdateUiConfigEndpoint, payload);
  }

  Future<Map<String, dynamic>> createTelecaller(Map<String, dynamic> payload) async {
    return _post(ApiConfig.adminTelecallerCreateEndpoint, payload);
  }

  Future<void> removeTelecaller({
    required int id,
    int? userId,
  }) async {
    await _post(ApiConfig.adminTelecallerRemoveEndpoint, {
      'id': id,
      'user_id': userId,
    });
  }
}
