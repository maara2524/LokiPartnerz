import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'utils/network_utils.dart';

class TelecallerLeadsPage extends StatefulWidget {
  final Function(int)? onCountChanged;

  const TelecallerLeadsPage({super.key, this.onCountChanged});

  @override
  State<TelecallerLeadsPage> createState() => _TelecallerLeadsPageState();
}

enum TelecallerLeadsErrorType { none, network, sessionExpired, unknown }

class _TelecallerLeadsPageState extends State<TelecallerLeadsPage> {
  static const List<String> _fallbackStatusOptions = [
    "new",
    "contacted",
    "ringing",
    "interested",
    "not interested",
    "callback_needed",
    "assigned",
    "Booked Outside",
    "booked",
    "no_response",
    "closed",
    "busy",
  ];

  List<Map<String, dynamic>> interactedLeads = [];
  List<Map<String, dynamic>> filteredLeads = [];
  List<String> statusFilterOptions = [];
  bool isLoading = true;
  String? errorMessage;
  TelecallerLeadsErrorType errorType = TelecallerLeadsErrorType.none;
  final TextEditingController searchController = TextEditingController();
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
        _fetchInteractedLeads();
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
    final isConnected = await NetworkUtils.hasInternetConnection();

    if (!mounted) return;

    setState(() {
      _hasInternet = isConnected;
    });

    if (isConnected) {
      await _fetchInteractedLeads();
    }
  }

  void _filterLeads() {
    if (!mounted) return;

    setState(() {
      filteredLeads = _applyFilters(interactedLeads);
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> leads) {
    final query = searchController.text.trim().toLowerCase();

    return leads.where((lead) {
      final name = (lead["customer_name"] ?? "").toString().toLowerCase();
      final status = _displayStatus(lead);
      final statusLabel = _statusLabel(status).toLowerCase();

      final matchesSearch =
          query.isEmpty || name.contains(query) || statusLabel.contains(query);
      final matchesStatus =
          selectedFilterStatus == null ||
          _normalizeStatus(status) == _normalizeStatus(selectedFilterStatus!);
      final matchesDate =
          selectedFilterDate == null ||
          _isSameDate(_parseLeadDate(lead), selectedFilterDate);

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  String _displayStatus(Map<String, dynamic> lead) {
    return (lead["display_status"] ?? lead["status"] ?? "new")
        .toString()
        .trim();
  }

  String _normalizeStatus(String status) {
    return status.trim().toLowerCase().replaceAll("_", " ");
  }

  String _statusLabel(String status) {
    final normalized = _normalizeStatus(status);

    switch (normalized) {
      case "new":
        return "New";
      case "contacted":
        return "Contacted";
      case "ringing":
        return "Ringing";
      case "interested":
        return "Interested";
      case "not interested":
        return "Not Interested";
      case "callback needed":
        return "Callback Needed";
      case "assigned":
        return "Assigned";
      case "booked":
        return "Booked";
      case "booked outside":
      case "booked outside bbm":
        return "Booked Outside";
      case "no response":
        return "No Response";
      case "closed":
        return "Closed";
      case "busy":
        return "Busy";
      default:
        return status
            .replaceAll("_", " ")
            .split(" ")
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(" ");
    }
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

  List<String> _deriveStatusFilterOptions(
    List<Map<String, dynamic>> leads, [
    Iterable<String> extraStatuses = const [],
  ]) {
    final options = <String>[];

    void addOption(String value) {
      if (value.trim().isEmpty) return;
      final alreadyAdded = options.any(
        (option) => _normalizeStatus(option) == _normalizeStatus(value),
      );
      if (!alreadyAdded) {
        options.add(value);
      }
    }

    for (final status in _fallbackStatusOptions) {
      addOption(status);
    }

    for (final status in extraStatuses) {
      addOption(status);
    }

    for (final lead in leads) {
      addOption(_displayStatus(lead));
    }

    return options;
  }

  Future<List<String>> _fetchStatusFilterOptions(String token) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.getFollowupStatusEndpoint}?token=$token"),
      );
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];

      return (decoded["statuses"] as List? ?? [])
          .map((status) => status.toString())
          .where((status) => status.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _fetchInteractedLeads() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await NetworkUtils.checkConnectivity();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null) {
        if (!mounted) return;

        setState(() {
          errorType = TelecallerLeadsErrorType.sessionExpired;
          errorMessage = "Your session has expired. Please log in again.";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.telecallerMyLeadsEndpoint}?token=$token"),
      );

      Map<String, dynamic>? data;

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      final errorText = (data?["error"] ?? data?["message"] ?? "")
          .toString()
          .toLowerCase();
      final isTokenError =
          response.statusCode == 401 ||
          errorText.contains("token") ||
          errorText.contains("session");

      if (response.statusCode == 200) {
        if (isTokenError) {
          if (!mounted) return;

          setState(() {
            errorType = TelecallerLeadsErrorType.sessionExpired;
            errorMessage = "Your account was logged in on another device.";
            isLoading = false;
          });
          return;
        }

        final leads = List<Map<String, dynamic>>.from(
          data?["leads"] ?? data?["interacted_leads"] ?? [],
        );
        final fetchedStatuses = await _fetchStatusFilterOptions(token);

        if (!mounted) return;

        setState(() {
          interactedLeads = leads;
          statusFilterOptions = _deriveStatusFilterOptions(
            leads,
            fetchedStatuses,
          );
          if (selectedFilterStatus != null &&
              !statusFilterOptions.any(
                (status) =>
                    _normalizeStatus(status) ==
                    _normalizeStatus(selectedFilterStatus!),
              )) {
            selectedFilterStatus = null;
          }
          filteredLeads = _applyFilters(leads);
          errorType = TelecallerLeadsErrorType.none;
          errorMessage = null;
          isLoading = false;
        });

        widget.onCountChanged?.call(leads.length);
      } else {
        if (!mounted) return;

        setState(() {
          errorType = isTokenError
              ? TelecallerLeadsErrorType.sessionExpired
              : TelecallerLeadsErrorType.unknown;
          errorMessage = isTokenError
              ? "Your account was logged in on another device."
              : ((data?["error"] ??
                        data?["message"] ??
                        "Unable to load interacted leads.")
                    .toString());
          isLoading = false;
        });
      }
    } on NetworkException catch (e) {
      if (!mounted) return;

      setState(() {
        errorType = TelecallerLeadsErrorType.network;
        errorMessage = e.message;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorType = TelecallerLeadsErrorType.unknown;
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
              "No Internet Connection",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Please check your internet connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchInteractedLeads,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    DateTime? draftDate = selectedFilterDate;
    String draftStatus = selectedFilterStatus ?? "all";
    final statusOptions = statusFilterOptions.isNotEmpty
        ? statusFilterOptions
        : _deriveStatusFilterOptions(interactedLeads);

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
                      items: [
                        const DropdownMenuItem<String>(
                          value: "all",
                          child: Text("All statuses"),
                        ),
                        ...statusOptions.map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ),
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
                                filteredLeads = _applyFilters(interactedLeads);
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

  @override
  Widget build(BuildContext context) {
    final myLeadsCount = interactedLeads.length;

    if (!_hasInternet) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text(
            "My Leads ($myLeadsCount)",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: _buildNoInternetView(),
      );
    }

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Padding(padding: const EdgeInsets.all(12.0), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorType != TelecallerLeadsErrorType.none) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (errorType == TelecallerLeadsErrorType.network)
              ElevatedButton.icon(
                onPressed: _fetchInteractedLeads,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            if (errorType == TelecallerLeadsErrorType.sessionExpired)
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

    if (interactedLeads.isEmpty) {
      return const Center(child: Text("No interacted leads found"));
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
                      hintText: "Search leads by name or status...",
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
                      ? "No leads match your filters"
                      : "No interacted leads found",
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchInteractedLeads,
                child: ListView.builder(
                  itemCount: filteredLeads.length,
                  itemBuilder: (context, index) {
                    return _buildLeadCard(lead: filteredLeads[index]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeadCard({required Map<String, dynamic> lead}) {
    final name = lead["customer_name"] ?? "Unknown";
    final date = lead["event_date"] ?? "";
    final status = _displayStatus(lead);
    final statusLabel = _statusLabel(status);

    Color statusColor;
    switch (_normalizeStatus(status)) {
      case "booked":
      case "assigned":
      case "interested":
        statusColor = Colors.green;
        break;
      case "contacted":
      case "ringing":
      case "callback needed":
      case "busy":
        statusColor = Colors.orange;
        break;
      case "closed":
      case "not interested":
      case "no response":
      case "booked outside":
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, "/lead_detail", arguments: lead).then((
            _,
          ) {
            _fetchInteractedLeads();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text("Event Date: ${date.toString().split('T').first}"),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
