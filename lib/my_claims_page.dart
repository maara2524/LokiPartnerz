import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'config/api_config.dart';
import 'utils/network_utils.dart';

class MyClaimsPage extends StatefulWidget {
  final Function(int)? onCountChanged;

  const MyClaimsPage({super.key, this.onCountChanged});

  @override
  State<MyClaimsPage> createState() => _MyClaimsPageState();
}

enum ClaimsErrorType { none, network, sessionExpired, unknown }

class _MyClaimsPageState extends State<MyClaimsPage> {
  List<Map<String, dynamic>> claimedLeads = [];
  List<Map<String, dynamic>> filteredLeads = [];
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  ClaimsErrorType errorType = ClaimsErrorType.none;
  DateTime? selectedFilterDate;
  String? selectedFilterStatus;

  late StreamSubscription<bool> _connectivitySubscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = NetworkUtils.onConnectivityChanged.listen((
      bool isConnected,
    ) {
      if (isConnected && !_hasInternet) {
        _fetchClaimedLeads();
      }
      if (!mounted) return;
      setState(() {
        _hasInternet = isConnected;
      });
    });
    searchController.addListener(_filterLeads);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    bool isConnected = await NetworkUtils.hasInternetConnection();
    if (!mounted) return;
    setState(() {
      _hasInternet = isConnected;
    });
    if (isConnected) {
      await _fetchClaimedLeads();
    }
  }

  void _filterLeads() {
    if (!mounted) return;
    setState(() {
      filteredLeads = _applyFilters(claimedLeads);
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> leads) {
    final query = searchController.text.trim().toLowerCase();

    return leads.where((lead) {
      final name = (lead["customer_name"] ?? "").toString().toLowerCase();
      final status = _displayStatus(lead);
      final statusLabel = _displayStatusLabel(lead).toLowerCase();

      final matchesSearch =
          query.isEmpty || name.contains(query) || statusLabel.contains(query);
      final matchesStatus =
          selectedFilterStatus == null || status == selectedFilterStatus;
      final matchesDate =
          selectedFilterDate == null ||
          _isSameDate(_parseLeadDate(lead), selectedFilterDate);

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  String _displayStatus(Map<String, dynamic> lead) {
    return (lead["display_status"] ?? lead["status"] ?? "new")
        .toString()
        .toLowerCase();
  }

  String _displayStatusLabel(Map<String, dynamic> lead) {
    final status = _displayStatus(lead);
    return (lead["display_status_label"] ?? _statusLabel(status)).toString();
  }

  DateTime? _parseLeadDate(Map<String, dynamic> lead) {
    final rawDate = (lead["event_date"] ?? lead["date"] ?? "").toString();
    if (rawDate.trim().isEmpty) return null;
    return DateTime.tryParse(rawDate);
  }

  bool _isSameDate(DateTime? first, DateTime? second) {
    if (first == null || second == null) return false;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatFilterDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  bool get _hasActiveFilters =>
      selectedFilterDate != null || selectedFilterStatus != null;

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "booked":
        return "Booked";
      case "booked_inside_bbm":
        return "Booked inside app";
      case "booked_outside_bbm":
        return "Booked outside app";
      case "contacted":
        return "Contacted";
      case "closed":
        return "Closed";
      case "follow_up":
        return "Follow Up";
      default:
        return status
            .split("_")
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(" ");
    }
  }

  Future<void> _fetchClaimedLeads() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await NetworkUtils.checkConnectivity();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("auth_token");

      if (token == null) {
        if (!mounted) return;
        setState(() {
          errorType = ClaimsErrorType.sessionExpired;
          errorMessage = "Your session has expired. Please log in again.";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.claimStatsEndpoint}?token=$token"),
      );

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      final String errorText = (data?["error"] ?? data?["message"] ?? "")
          .toString()
          .toLowerCase();
      final bool isTokenError =
          errorText.contains("token") ||
          errorText.contains("session") ||
          response.statusCode == 401;

      if (response.statusCode == 200) {
        if (isTokenError) {
          if (!mounted) return;
          setState(() {
            errorType = ClaimsErrorType.sessionExpired;
            errorMessage = "Your account was logged in on another device.";
            isLoading = false;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          claimedLeads = List<Map<String, dynamic>>.from(
            data?["claimed_leads"] ?? [],
          );
          filteredLeads = _applyFilters(claimedLeads);
          errorType = ClaimsErrorType.none;
          errorMessage = null;
          isLoading = false;
        });
        widget.onCountChanged?.call(claimedLeads.length);
      } else {
        if (!mounted) return;
        setState(() {
          errorType = isTokenError
              ? ClaimsErrorType.sessionExpired
              : ClaimsErrorType.unknown;
          errorMessage = isTokenError
              ? "Your account was logged in on another device."
              : ((data?["error"] ??
                        data?["message"] ??
                        "Unable to load claimed leads.")
                    .toString());
          isLoading = false;
        });
      }
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        errorType = ClaimsErrorType.network;
        errorMessage = e.message;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorType = ClaimsErrorType.unknown;
        errorMessage = "Something went wrong. Please try again.";
        isLoading = false;
      });
    }
  }

  Widget _buildNoInternetView() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No Internet Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchClaimedLeads,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int myClaimsCount = claimedLeads.length;

    // NO INTERNET
    if (!_hasInternet) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text(
            "My Claims ($myClaimsCount)",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: _buildNoInternetView(),
      );
    }

    // LOADING
    if (isLoading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    // NORMAL
    return Scaffold(
      body: Padding(padding: const EdgeInsets.all(12.0), child: _buildBody()),
    );
  }

  Future<void> _showFilterSheet() async {
    DateTime? draftDate = selectedFilterDate;
    String draftStatus = selectedFilterStatus ?? "all";

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: draftDate ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
              );

              if (picked != null) {
                setModalState(() {
                  draftDate = picked;
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filters",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          tooltip: "Close",
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: draftStatus,
                      decoration: const InputDecoration(
                        labelText: "Status",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: "all",
                          child: Text("All statuses"),
                        ),
                        DropdownMenuItem<String>(
                          value: "new",
                          child: Text("New"),
                        ),
                        DropdownMenuItem<String>(
                          value: "contacted",
                          child: Text("Contacted"),
                        ),
                        DropdownMenuItem<String>(
                          value: "booked",
                          child: Text("Booked"),
                        ),
                        DropdownMenuItem<String>(
                          value: "booked_inside_bbm",
                          child: Text("Booked inside app"),
                        ),
                        DropdownMenuItem<String>(
                          value: "booked_outside_bbm",
                          child: Text("Booked outside app"),
                        ),
                        DropdownMenuItem<String>(
                          value: "closed",
                          child: Text("Closed"),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          draftStatus = value ?? "all";
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.event),
                            label: Text(
                              draftDate == null
                                  ? "Any date"
                                  : _formatFilterDate(draftDate!),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (draftDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: "Clear date",
                            onPressed: () {
                              setModalState(() {
                                draftDate = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                draftDate = null;
                                draftStatus = "all";
                              });
                            },
                            child: const Text("Reset"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                selectedFilterDate = draftDate;
                                selectedFilterStatus = draftStatus == "all"
                                    ? null
                                    : draftStatus;
                                filteredLeads = _applyFilters(claimedLeads);
                              });
                              Navigator.pop(context);
                            },
                            child: const Text("Apply"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorType != ClaimsErrorType.none) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            if (errorType == ClaimsErrorType.network)
              ElevatedButton.icon(
                onPressed: _fetchClaimedLeads,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),

            if (errorType == ClaimsErrorType.sessionExpired)
              ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, "/login");
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text("Login"),
              ),
          ],
        ),
      );
    }

    if (claimedLeads.isEmpty) {
      return const Center(child: Text("No claimed leads found"));
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search claims...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  width: 56,
                  child: IconButton(
                    tooltip: "Filters",
                    style: IconButton.styleFrom(
                      backgroundColor: _hasActiveFilters
                          ? Colors.deepPurple
                          : Colors.grey.shade100,
                      foregroundColor: _hasActiveFilters
                          ? Colors.white
                          : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onPressed: _showFilterSheet,
                    icon: Icon(
                      _hasActiveFilters
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filteredLeads.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _hasActiveFilters || searchController.text.trim().isNotEmpty
                      ? "No claims match your filters"
                      : "No claimed leads found",
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchClaimedLeads,
                child: ListView.builder(
                  itemCount: filteredLeads.length,
                  itemBuilder: (context, index) {
                    final lead = filteredLeads[index];
                    return _buildLeadCard(lead: lead);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeadCard({required Map<String, dynamic> lead}) {
    String name = lead["customer_name"] ?? "Unknown";
    String date = lead["event_date"] ?? "";
    String status = _displayStatus(lead);
    String statusLabel = _displayStatusLabel(lead);
    // bool isReleased = lead["released"] == 1;

    Color statusColor;
    switch (status.toLowerCase()) {
      case "booked":
        statusColor = Colors.green;
        break;
      case "booked_inside_bbm":
        statusColor = Colors.green;
        break;
      case "booked_outside_bbm":
        statusColor = Colors.red;
        break;
      case "contacted":
        statusColor = Colors.orange;
        break;
      case "closed":
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/lead_detail', arguments: lead).then((
            _,
          ) {
            _fetchClaimedLeads();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text("Event Date: ${date.split('T').first}"),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),

                  // if (isReleased)
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(
                  //       horizontal: 8,
                  //       vertical: 4,
                  //     ),
                  //     decoration: BoxDecoration(
                  //       color: Colors.grey.shade300,
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //     child: const Text(
                  //       "Released",
                  //       style: TextStyle(color: Colors.black87, fontSize: 12),
                  //     ),
                  //   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Future<void> _releaseLead(int leadId, String leadName) async {
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     String? token = prefs.getString("auth_token");

  //     if (token == null) {
  //       if (mounted) {
  //         Navigator.pushReplacementNamed(context, "/login");
  //       }
  //       return;
  //     }

  //     final response = await http.post(
  //       Uri.parse(ApiConfig.releaseLeadEndpoint),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({
  //         "lead_id": leadId,
  //         "token": token,
  //       }),
  //     );
  //     if(!mounted){
  //       return;
  //     }
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(data["message"])),
  //       );
  //       _fetchClaimedLeads(); // Refresh the list

  //       // Set a flag to indicate data changed (for when user eventually navigates back)
  //       SharedPreferences prefs = await SharedPreferences.getInstance();
  //       await prefs.setBool('claims_data_changed', true);
  //     } else {
  //       final error = jsonDecode(response.body);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(error["error"] ?? "Failed to release lead")),
  //       );
  //     }
  //   } catch (e) {
  //     if(!mounted){
  //       return;
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Error: $e")),
  //     );
  //   }
  // }
}
