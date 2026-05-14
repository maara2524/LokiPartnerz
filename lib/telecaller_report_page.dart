import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'theme/bbm_theme.dart';

class TelecallerReportPage extends StatefulWidget {
  const TelecallerReportPage({super.key});

  @override
  State<TelecallerReportPage> createState() => _TelecallerReportPageState();
}

class _TelecallerReportPageState extends State<TelecallerReportPage> {
  static const String _allArtistsLabel = 'All Artists';
  static const String _allStatusLabel = 'All Status';

  List<Map<String, dynamic>> _artists = [];
  List<String> _statuses = [];
  List<Map<String, dynamic>> _reportLeads = [];

  int? _selectedArtistId;
  String _selectedStatus = _allStatusLabel;
  DateTime? _selectedDate;
  DateTimeRange? _selectedDateRange;
  bool _useDateRange = false;

  bool _isBootstrapping = true;
  bool _isLoadingReport = false;
  bool _isGeneratingPdf = false;
  String? _errorMessage;

  int get _activeFilterCount {
    var count = 0;
    if (_selectedArtistId != null) count++;
    if (_selectedStatus != _allStatusLabel) count++;
    if (_useDateRange) {
      if (_selectedDateRange != null) count++;
    } else {
      if (_selectedDate != null) count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() {
      _isBootstrapping = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Session expired. Please log in again.";
          _isBootstrapping = false;
        });
        return;
      }

      await _fetchArtists(token);
      await _fetchStatuses(token);
      await _fetchReport(token: token);

      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Unable to load report data. Please try again.";
        _isBootstrapping = false;
      });
    }
  }

  Future<void> _fetchArtists(String token) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.eliteArtistsEndpoint}?token=$token"),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return;

    final items = (decoded["artists"] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (!mounted) return;
    setState(() {
      _artists = items;
    });
  }

  Future<void> _fetchStatuses(String token) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.getFollowupStatusEndpoint}?token=$token"),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return;

    final items = (decoded["statuses"] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    if (!mounted) return;
    setState(() {
      _statuses = items;
      if (_selectedStatus != _allStatusLabel &&
          !_statuses.contains(_selectedStatus)) {
        _selectedStatus = _allStatusLabel;
      }
    });
  }

  Future<void> _fetchReport({String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = token ?? prefs.getString("auth_token");

    if (authToken == null || authToken.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Session expired. Please log in again.";
        _isLoadingReport = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingReport = true;
        _errorMessage = null;
      });
    }

    try {
      final queryParameters = <String, String>{'token': authToken};

      if (_selectedArtistId != null) {
        queryParameters['artist_id'] = _selectedArtistId.toString();
      }

      if (_selectedStatus != _allStatusLabel) {
        queryParameters['status'] = _selectedStatus;
      }

      if (_useDateRange) {
        if (_selectedDateRange != null) {
          queryParameters['from_date'] = _apiDate(_selectedDateRange!.start);
          queryParameters['to_date'] = _apiDate(_selectedDateRange!.end);
        }
      } else if (_selectedDate != null) {
        queryParameters['report_date'] = _apiDate(_selectedDate!);
      }

      final uri = Uri.parse(
        ApiConfig.telecallerReportEndpoint,
      ).replace(queryParameters: queryParameters);

      final response = await http.get(uri);
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Invalid response format");
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw Exception(
          decoded['error'] ?? decoded['message'] ?? 'Failed to load report',
        );
      }

      final leads = (decoded['leads'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (!mounted) return;
      setState(() {
        _reportLeads = leads;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Unable to load report results. Please try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReport = false;
          _isBootstrapping = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(2024),
      lastDate: today,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2024),
      lastDate: today,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDateRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedArtistId = null;
      _selectedStatus = _allStatusLabel;
      _selectedDate = null;
      _selectedDateRange = null;
      _useDateRange = false;
    });
    await _fetchReport();
  }

  String _displayDate(DateTime? date) {
    if (date == null) return 'Select Date';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatIst12(String raw) {
    if (raw.trim().isEmpty) return '-';

    try {
      final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
      final parsed = DateTime.parse(normalized);
      final ist = parsed.isUtc
          ? parsed.add(const Duration(hours: 5, minutes: 30))
          : parsed;

      final day = ist.day.toString().padLeft(2, '0');
      final month = ist.month.toString().padLeft(2, '0');
      final year = ist.year.toString();
      var hour = ist.hour;
      final minute = ist.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourText = hour.toString().padLeft(2, '0');

      return '$day/$month/$year $hourText:$minute $period';
    } catch (_) {
      return raw;
    }
  }

  String _dateSelectionLabel() {
    if (_useDateRange) {
      if (_selectedDateRange == null) return 'Select Date Range';
      return '${_displayDate(_selectedDateRange!.start)} - ${_displayDate(_selectedDateRange!.end)}';
    }
    return _displayDate(_selectedDate);
  }

  String _selectedArtistLabel() {
    if (_selectedArtistId == null) return _allArtistsLabel;
    final artist = _artists.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == _selectedArtistId,
      orElse: () => null,
    );
    return (artist?['name'] ?? _allArtistsLabel).toString();
  }

  Future<void> _downloadPdfReport() async {
    if (_isGeneratingPdf) return;

    if (_reportLeads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available to export.')),
      );
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = true;
        });
      }

      final pdfBytes = await _buildPdfBytes();
      final fileDate = DateTime.now();
      final fileName =
          'telecaller_report_${fileDate.year}${fileDate.month.toString().padLeft(2, '0')}${fileDate.day.toString().padLeft(2, '0')}.pdf';

      await Printing.layoutPdf(name: fileName, onLayout: (_) async => pdfBytes);
    } catch (e) {
      debugPrint('Debug : PDF generation error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not generate PDF report. Please check setup and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Telecaller Lead Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on: ${_formatIst12(DateTime.now().toIso8601String())}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Applied Filters',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Elite Artist: ${_selectedArtistLabel()}'),
                pw.Text('Updated Date: ${_dateSelectionLabel()}'),
                pw.Text('Status: $_selectedStatus'),
                pw.Text('Total Leads: ${_reportLeads.length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          ..._reportLeads.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final lead = entry.value;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '$index. ${(lead['customer_name'] ?? 'Unknown').toString()}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Text(
                        'Lead ID: ${lead['id']}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Assigned Artist: ${(lead['assigned_artist_name'] ?? 'Unassigned').toString()}',
                  ),
                  pw.Text(
                    'Report Date: ${(lead['report_date'] ?? '-').toString()}',
                  ),
                  pw.Text(
                    'Event Date: ${(lead['event_date'] ?? '').toString().split('T').first}',
                  ),
                  pw.Text('Location: ${(lead['location'] ?? '-').toString()}'),
                  pw.Text(
                    'Event Type: ${(lead['event_type'] ?? '-').toString()}',
                  ),
                  pw.Text(
                    'Budget: ${(lead['budget_range'] ?? 'Not Specified').toString()}',
                  ),
                  pw.Text('Status: ${(lead['status'] ?? 'new').toString()}'),
                  pw.Text(
                    'Updated: ${_formatIst12((lead['updated_at'] ?? '').toString())}',
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: BBMTheme.primaryLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInitialData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildFilterCard(),
              const SizedBox(height: 16),
              _buildResultsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BBMTheme.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: BBMTheme.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lead Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Filter leads by elite artist, updated date, and status.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryPill('Active Filters: $_activeFilterCount'),
              _summaryPill('Results: ${_reportLeads.length}'),
              GestureDetector(
                onTap: _isGeneratingPdf ? null : _downloadPdfReport,
                child: _isGeneratingPdf
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : _summaryPill('Download PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BBMTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BBMTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Particular Date'),
                  selected: !_useDateRange,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _useDateRange = false;
                      _selectedDateRange = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Date Range'),
                  selected: _useDateRange,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _useDateRange = true;
                      _selectedDate = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int?>(
            initialValue: _selectedArtistId,
            decoration: _inputDecoration(
              label: 'Elite Artist',
              icon: Icons.person_search_outlined,
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text(_allArtistsLabel),
              ),
              ..._artists.map(
                (artist) => DropdownMenuItem<int?>(
                  value: artist['id'] as int?,
                  child: Text((artist['name'] ?? 'Unknown Artist').toString()),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedArtistId = value;
              });
            },
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _useDateRange ? _pickDateRange : _pickDate,
            child: InputDecorator(
              decoration: _inputDecoration(
                label: _useDateRange ? 'Updated Date Range' : 'Updated Date',
                icon: _useDateRange
                    ? Icons.date_range_outlined
                    : Icons.calendar_today_outlined,
              ),
              child: Text(
                _dateSelectionLabel(),
                style: TextStyle(
                  color:
                      (_useDateRange
                          ? _selectedDateRange == null
                          : _selectedDate == null)
                      ? BBMTheme.textSecondary
                      : BBMTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            decoration: _inputDecoration(
              label: 'Status',
              icon: Icons.flag_outlined,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: _allStatusLabel,
                child: Text(_allStatusLabel),
              ),
              ..._statuses.map(
                (status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedStatus = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clearFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BBMTheme.primaryLight,
                    foregroundColor: BBMTheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingReport ? null : _fetchReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BBMTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isLoadingReport
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.filter_alt_outlined),
                  label: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BBMTheme.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 52, color: BBMTheme.danger),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BBMTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reportLeads.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BBMTheme.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.summarize_outlined,
              size: 56,
              color: BBMTheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Report Data Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: BBMTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Artist: ${_selectedArtistLabel()}\nUpdated Date: ${_dateSelectionLabel()}\nStatus: $_selectedStatus',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: BBMTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(children: _reportLeads.map(_buildLeadCard).toList());
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final status = (lead['status'] ?? 'new').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BBMTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (lead['customer_name'] ?? 'Unknown').toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: BBMTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: BBMTheme.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ID ${lead['id']}',
                  style: const TextStyle(
                    color: BBMTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow(
            '🎨 Artist',
            (lead['assigned_artist_name'] ?? 'Unassigned').toString(),
          ),

          _detailRow(
            '📅 Event Date',
            (lead['event_date'] ?? '').toString().split('T').first,
          ),
          _detailRow('📍 Location', (lead['location'] ?? '-').toString()),
          _detailRow('🎉 Event Type', (lead['event_type'] ?? '-').toString()),
          _detailRow(
            '💰 Budget',
            (lead['budget_range'] ?? 'Not Specified').toString(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Updated: ${_formatIst12((lead['updated_at'] ?? '').toString())}',
                style: const TextStyle(
                  color: BBMTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        '$label: ${value.isEmpty ? '-' : value}',
        style: const TextStyle(color: BBMTheme.textPrimary, fontSize: 14),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
      case 'assigned':
      case 'interested':
        return BBMTheme.success;
      case 'contacted':
      case 'ringing':
      case 'callback_needed':
      case 'busy':
        return BBMTheme.warning;
      case 'closed':
      case 'not_interested':
      case 'no_response':
        return BBMTheme.danger;
      default:
        return BBMTheme.primary;
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: BBMTheme.primary),
      filled: true,
      fillColor: BBMTheme.primaryLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BBMTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BBMTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BBMTheme.primary, width: 1.3),
      ),
    );
  }
}
