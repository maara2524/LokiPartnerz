import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'bbm_admin_theme.dart';
import 'admin_widgets.dart';

String _adminText(Map<String, dynamic> data, String key, [String fallback = '']) {
  final value = data[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _adminInt(Map<String, dynamic> data, String key, [int fallback = 0]) {
  final value = data[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _adminBool(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}

List<Map<String, dynamic>> _adminMapList(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _adminStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'booked_outside_bbm':
      return 'Booked outside';
    case 'booked_inside_bbm':
      return 'Booked inside';
    case 'follow_up':
      return 'Follow up';
    default:
      return status
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

String _adminFilterStatusValue(String label) {
  final value = label.toLowerCase().replaceAll(' ', '_');
  return value == 'booked_outside' ? 'booked_outside_bbm' : value;
}

class AdminLeadsPage extends StatefulWidget {
  const AdminLeadsPage({super.key});

  @override
  State<AdminLeadsPage> createState() => _AdminLeadsPageState();
}

class _AdminLeadsPageState extends State<AdminLeadsPage> {
  final _api = const AdminApiService();
  String _filterStatus = 'All';
  String _filterCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _leads = [];
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> get _filtered {
    return _leads.where((l) {
      final query = _searchQuery.trim().toLowerCase();
      final queryDigits = query.replaceAll(RegExp(r'\D'), '');
      final customer = _adminText(l, 'customer').toLowerCase();
      final phone = _adminText(l, 'phone').toLowerCase();
      final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
      final matchSearch = query.isEmpty ||
          customer.contains(query) ||
          phone.contains(query) ||
          (queryDigits.isNotEmpty && phoneDigits.contains(queryDigits));
      final matchStatus = _filterStatus == 'All' ||
          _adminText(l, 'status') == _adminFilterStatusValue(_filterStatus);
      final matchCat = _filterCategory == 'All' || _adminText(l, 'services') == _filterCategory;
      return matchSearch && matchStatus && matchCat;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new': return BbmAdminTheme.accentAmber;
      case 'contacted': return BbmAdminTheme.accentIndigo;
      case 'claimed': return BbmAdminTheme.purple600;
      case 'booked': return BbmAdminTheme.statusActive;
      case 'booked_outside_bbm': return BbmAdminTheme.accentAmber;
      case 'booked_inside_bbm': return BbmAdminTheme.statusActive;
      case 'follow_up': return BbmAdminTheme.accentTeal;
      case 'closed': return BbmAdminTheme.textMuted;
      default: return BbmAdminTheme.textMuted;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final leads = await _api.fetchLeads();
      if (!mounted) return;
      setState(() => _leads = leads);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = _filtered;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              AdminGradientButton(label: 'Retry', onTap: _loadLeads),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: leads.isEmpty
              ? Center(child: Text('No leads found', style: const TextStyle(color: BbmAdminTheme.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: leads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildLeadCard(leads[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: BbmAdminTheme.bgPrimary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          AdminSearchBar(
            hint: 'Search by customer name or phone...',
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
          const SizedBox(height: 10),
          AdminFilterChips(
            options: const ['All', 'New', 'Claimed', 'Contacted', 'Follow Up', 'Booked', 'Booked Outside', 'Closed'],
            selected: _filterStatus,
            onSelected: (v) => setState(() => _filterStatus = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${_filtered.length} lead${_filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary, fontWeight: FontWeight.w500)),
              const Spacer(),
              _categoryDropdown(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryDropdown() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterCategory,
          icon: const Icon(Icons.expand_more, size: 15, color: BbmAdminTheme.textSecondary),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BbmAdminTheme.textSecondary),
          items: ['All', 'Makeup', 'Photography', 'Events', 'Others']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _filterCategory = v!),
        ),
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final status = _adminText(lead, 'status', 'new');
    final statusColor = _statusColor(status);
    final claimCount = _adminInt(lead, 'claim_count');
    final maxClaims = _adminInt(lead, 'max_claims');
    final isLocked = _adminBool(lead, 'locked');
    final progress = maxClaims > 0 ? (claimCount / maxClaims).clamp(0.0, 1.0).toDouble() : 0.0;
    final bookedBy = _adminText(lead, 'booked_by');
    final bookedAt = _adminText(lead, 'booked_at');
    final claimedBy = _adminText(lead, 'claimed_by', '-');

    return GestureDetector(
      onTap: () => _openLeadDetail(lead),
      child: Container(
        decoration: BbmAdminTheme.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('#${lead['id']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(_adminText(lead, 'customer', 'Unknown'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: BbmAdminTheme.textPrimary)),
                        ),
                        StatusBadge(label: _adminStatusLabel(status), color: statusColor, fontSize: 10),
                      ]),
                      const SizedBox(height: 2),
                      Text('${_adminText(lead, 'event', 'Event')} - ${_adminText(lead, 'location', 'Location')}',
                        style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniTag(Icons.calendar_today_outlined, _adminText(lead, 'date', '-')),
                const SizedBox(width: 8),
                _miniTag(Icons.brush_outlined, _adminText(lead, 'services', '-')),
                const SizedBox(width: 8),
                _miniTag(Icons.currency_rupee_outlined, _adminText(lead, 'budget', '-')),
              ],
            ),
            if (bookedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailTag(
                Icons.verified_outlined,
                'Booked by $bookedBy${bookedAt.isNotEmpty ? ' at $bookedAt' : ''}',
              ),
            ] else if (claimedBy != '-') ...[
              const SizedBox(height: 8),
              _detailTag(Icons.person_outline, 'Current claimant: $claimedBy'),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Claims: $claimCount / $maxClaims', style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textSecondary)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: BbmAdminTheme.bgMuted,
                          valueColor: AlwaysStoppedAnimation(statusColor),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isLocked) Icon(Icons.lock_outline, size: 16, color: BbmAdminTheme.textMuted),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: BbmAdminTheme.textMuted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: BbmAdminTheme.textMuted),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _detailTag(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: BbmAdminTheme.purple500),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: BbmAdminTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _openLeadDetail(Map<String, dynamic> lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeadDetailSheet(
        api: _api,
        lead: lead,
        statusColor: _statusColor(_adminText(lead, 'status', 'new')),
        onUpdate: (updatedLead) async {
          await _api.updateLead({
            'id': updatedLead['id'],
            'status': updatedLead['status'],
            'location': updatedLead['location'],
            'budget': updatedLead['budget'],
            'max_claims': updatedLead['max_claims'],
          });
          setState(() {
            final idx = _leads.indexWhere((l) => l['id'] == updatedLead['id']);
            if (idx != -1) _leads[idx] = updatedLead;
          });
        },
        onUnlock: (id) async {
          await _api.unlockLead(id);
          setState(() {
            final idx = _leads.indexWhere((l) => l['id'] == id);
            if (idx != -1) {
              _leads[idx]['locked'] = false;
              _leads[idx]['claimed_by'] = '-';
            }
          });
        },
        onDelete: (id) async {
          await _api.deleteLead(id);
          setState(() => _leads.removeWhere((l) => l['id'] == id));
          if (!mounted) return ;
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─── Lead Detail Sheet ──────────────────────────────────────────────────────────
class _LeadDetailSheet extends StatefulWidget {
  final AdminApiService api;
  final Map<String, dynamic> lead;
  final Color statusColor;
  final Future<void> Function(Map<String, dynamic>) onUpdate;
  final Future<void> Function(int) onUnlock;
  final Future<void> Function(int) onDelete;

  const _LeadDetailSheet({
    required this.api,
    required this.lead,
    required this.statusColor,
    required this.onUpdate,
    required this.onUnlock,
    required this.onDelete,
  });

  @override
  State<_LeadDetailSheet> createState() => _LeadDetailSheetState();
}

class _LeadDetailSheetState extends State<_LeadDetailSheet> {
  late Map<String, dynamic> _lead;
  bool _editMode = false;
  late TextEditingController _budgetCtrl;
  late TextEditingController _locationCtrl;
  late String _selectedStatus;
  late int _maxClaims;
  bool _loadingDetail = true;
  String? _detailError;
  List<Map<String, dynamic>> _claimHistory = [];
  List<Map<String, dynamic>> _timeline = [];
  // bool _saving = false;

  final List<String> _statuses = ['new', 'contacted', 'claimed', 'follow_up', 'booked', 'booked_outside_bbm', 'closed'];

  @override
  void initState() {
    super.initState();
    _lead = Map.from(widget.lead);
    _budgetCtrl = TextEditingController(text: _adminText(_lead, 'budget'));
    _locationCtrl = TextEditingController(text: _adminText(_lead, 'location'));
    _selectedStatus = _adminText(_lead, 'status', 'new');
    _maxClaims = _adminInt(_lead, 'max_claims');
    _loadLeadDetail();
  }

  Future<void> _loadLeadDetail({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loadingDetail = true;
        _detailError = null;
      });
    }

    try {
      final detail = await widget.api.fetchLeadDetail(_adminInt(_lead, 'id'));
      final leadData = Map<String, dynamic>.from(detail['lead'] as Map);
      if (!mounted) return;
      setState(() {
        _detailError = null;
        _lead = {..._lead, ...leadData};
        _claimHistory = _adminMapList(detail['claim_history']);
        _timeline = _adminMapList(detail['timeline']);
        if (!_editMode) {
          _selectedStatus = _adminText(_lead, 'status', 'new');
          _maxClaims = _adminInt(_lead, 'max_claims');
          _budgetCtrl.text = _adminText(_lead, 'budget');
          _locationCtrl.text = _adminText(_lead, 'location');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailError = e.toString());
    } finally {
      if (mounted && showLoading) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'new': return BbmAdminTheme.accentAmber;
      case 'contacted': return BbmAdminTheme.accentIndigo;
      case 'claimed': return BbmAdminTheme.purple600;
      case 'booked': return BbmAdminTheme.statusActive;
      case 'booked_outside_bbm': return BbmAdminTheme.accentAmber;
      case 'booked_inside_bbm': return BbmAdminTheme.statusActive;
      case 'follow_up': return BbmAdminTheme.accentTeal;
      case 'closed': return BbmAdminTheme.textMuted;
      default: return BbmAdminTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: BbmAdminTheme.bgPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDD6FE), borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Text('Lead #${_lead['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BbmAdminTheme.textPrimary)),
                  const Spacer(),
                  if (!_editMode)
                    GestureDetector(
                      onTap: () => setState(() => _editMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: BbmAdminTheme.purple100, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Edit', style: TextStyle(color: BbmAdminTheme.purple600, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  if (_editMode) ...[
                    GestureDetector(
                      onTap: _saveChanges,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(gradient: BbmAdminTheme.brandGradient, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: BbmAdminTheme.bgMuted, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.close, size: 18, color: BbmAdminTheme.textSecondary)),
                  ),
                ],
              ),
            ),
            Divider(color: BbmAdminTheme.bgMuted),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _buildStatusBanner(),
                  if (_loadingDetail) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (_detailError != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailError(),
                  ],
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildClaimsCard(),
                  const SizedBox(height: 16),
                  _buildTimelineCard(),
                  const SizedBox(height: 16),
                  _buildDangerZone(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusColor(_selectedStatus).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor(_selectedStatus).withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _adminText(_lead, 'customer', 'Unknown'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: BbmAdminTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: _adminStatusLabel(_selectedStatus), color: _statusColor(_selectedStatus)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${_adminText(_lead, 'event', 'Event')} - ${_adminText(_lead, 'date', 'Date')}', style: const TextStyle(color: BbmAdminTheme.textSecondary, fontSize: 13)),
          if (_adminText(_lead, 'booked_by').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 15, color: BbmAdminTheme.statusActive),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Booked by ${_adminText(_lead, 'booked_by')}${_adminText(_lead, 'booked_at').isNotEmpty ? ' at ${_adminText(_lead, 'booked_at')}' : ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BbmAdminTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          if (_editMode) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _statuses.map((s) {
                final isSel = _selectedStatus == s;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStatus = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel ? _statusColor(s) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _statusColor(s).withValues(alpha: 0.5), width: 1),
                    ),
                    child: Text(
                      _adminStatusLabel(s).toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isSel ? Colors.white : _statusColor(s)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lead Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BbmAdminTheme.textPrimary)),
          const SizedBox(height: 12),
          _infoRow('Phone', _adminText(_lead, 'phone', '-'), Icons.phone_outlined),
          if (_adminText(_lead, 'email').isNotEmpty)
            _infoRow('Email', _adminText(_lead, 'email'), Icons.email_outlined),
          _infoRow('Service', _adminText(_lead, 'services', '-'), Icons.brush_outlined),
          _infoRow('Source', _adminText(_lead, 'source', '-'), Icons.campaign_outlined),
          if (_editMode) ...[
            const SizedBox(height: 12),
            AdminEditField(label: 'Location', controller: _locationCtrl),
            const SizedBox(height: 10),
            AdminEditField(label: 'Budget Range', controller: _budgetCtrl),
            const SizedBox(height: 10),
            _maxClaimsSelector(),
          ] else ...[
            _infoRow('Location', _adminText(_lead, 'location', '-'), Icons.location_on_outlined),
            _infoRow('Budget', _adminText(_lead, 'budget', '-'), Icons.currency_rupee_outlined),
            _infoRow('Max Claims', '${_adminInt(_lead, 'max_claims')}', Icons.people_outline),
            if (_adminText(_lead, 'requirements').isNotEmpty)
              _infoRow('Details', _adminText(_lead, 'requirements'), Icons.notes_outlined),
            if (_adminText(_lead, 'created_at').isNotEmpty)
              _infoRow('Created', _adminText(_lead, 'created_at'), Icons.history_outlined),
            if (_adminText(_lead, 'updated_at').isNotEmpty)
              _infoRow('Updated', _adminText(_lead, 'updated_at'), Icons.update_outlined),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: BbmAdminTheme.purple400),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BbmAdminTheme.textPrimary))),
        ],
      ),
    );
  }

  Widget _maxClaimsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Max Claims Allowed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BbmAdminTheme.textSecondary, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3, 5, 10].map((n) {
            final isSel = _maxClaims == n;
            return GestureDetector(
              onTap: () => setState(() => _maxClaims = n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: isSel ? BbmAdminTheme.brandGradient : null,
                  color: isSel ? null : BbmAdminTheme.bgMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('$n', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isSel ? Colors.white : BbmAdminTheme.textSecondary)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildClaimsCard() {
    final claimCount = _adminInt(_lead, 'claim_count');
    final maxClaims = _adminInt(_lead, 'max_claims');
    final progress = maxClaims > 0 ? (claimCount / maxClaims).clamp(0.0, 1.0).toDouble() : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Claim Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BbmAdminTheme.textPrimary)),
              const Spacer(),
              Text('$claimCount / $maxClaims',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BbmAdminTheme.purple600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: BbmAdminTheme.bgMuted,
              valueColor: const AlwaysStoppedAnimation(BbmAdminTheme.purple500),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow('Current', _adminText(_lead, 'claimed_by', '-'), Icons.person_outline),
          _infoRow('Lock Status', _adminBool(_lead, 'locked') ? 'Locked' : 'Unlocked', Icons.lock_outline),
          if (_claimHistory.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(color: BbmAdminTheme.bgMuted),
            const SizedBox(height: 6),
            const Text('Past Claimed Users', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BbmAdminTheme.textSecondary)),
            const SizedBox(height: 8),
            ..._claimHistory.map(_claimHistoryRow),
          ] else if (!_loadingDetail) ...[
            const SizedBox(height: 6),
            const Text('No claim history found', style: TextStyle(fontSize: 12, color: BbmAdminTheme.textMuted)),
          ],
          if (_adminBool(_lead, 'locked')) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                widget.onUnlock(_adminInt(_lead, 'id')).then((_) {
                  if (!mounted) return;
                  setState(() {
                    _lead['locked'] = false;
                    _lead['claimed_by'] = '-';
                  });
                  _loadLeadDetail(showLoading: false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead unlocked')));
                }).catchError((Object error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: BbmAdminTheme.purple100, borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.lock_open_outlined, color: BbmAdminTheme.purple600, size: 18),
                  SizedBox(width: 8),
                  Text('Force Unlock Lead', style: TextStyle(color: BbmAdminTheme.purple600, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _detailError ?? 'Unable to load lead history',
              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _loadLeadDetail(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _claimHistoryRow(Map<String, dynamic> item) {
    final name = _adminText(item, 'user_name', 'Unknown');
    final business = _adminText(item, 'business_name');
    final phone = _adminText(item, 'phone');
    final location = _adminText(item, 'location');
    final claimTime = _adminText(item, 'claim_time');
    final releaseTime = _adminText(item, 'release_time');
    final finalStatus = _adminText(item, 'final_status');
    final releaseReason = _adminText(item, 'release_reason');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: BbmAdminTheme.purple100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_outline, size: 15, color: BbmAdminTheme.purple600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BbmAdminTheme.textPrimary)),
                if (business.isNotEmpty)
                  Text(business, style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary)),
                if (phone.isNotEmpty || location.isNotEmpty)
                  Text(
                    [phone, location].where((v) => v.isNotEmpty).join(' - '),
                    style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textMuted),
                  ),
                if (claimTime.isNotEmpty)
                  Text('Claimed: $claimTime', style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textSecondary)),
                if (releaseTime.isNotEmpty)
                  Text('Released: $releaseTime', style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textSecondary)),
                if (finalStatus.isNotEmpty || releaseReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (finalStatus.isNotEmpty) _smallChip(_adminStatusLabel(finalStatus), BbmAdminTheme.accentTeal),
                      if (releaseReason.isNotEmpty) _smallChip(_adminStatusLabel(releaseReason), BbmAdminTheme.textMuted),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lead History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BbmAdminTheme.textPrimary)),
          const SizedBox(height: 12),
          if (_loadingDetail && _timeline.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_timeline.isEmpty)
            const Text('No history found', style: TextStyle(fontSize: 12, color: BbmAdminTheme.textMuted))
          else
            ..._timeline.map(_timelineRow),
        ],
      ),
    );
  }

  Widget _timelineRow(Map<String, dynamic> item) {
    final type = _adminText(item, 'type', 'activity');
    final status = _adminText(item, 'status');
    final title = _adminText(item, 'title', 'Activity');
    final actor = _adminText(item, 'actor', 'Unknown');
    final time = _adminText(item, 'time');
    final description = _adminText(item, 'description');
    final color = _historyColor(type, status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_historyIcon(type), size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BbmAdminTheme.textPrimary)),
                    ),
                    if (status.isNotEmpty) _smallChip(_adminStatusLabel(status), color),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [actor, time].where((v) => v.isNotEmpty).join(' - '),
                  style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textMuted, fontWeight: FontWeight.w600),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  IconData _historyIcon(String type) {
    switch (type) {
      case 'claim':
        return Icons.person_add_alt_1_outlined;
      case 'release':
        return Icons.lock_open_outlined;
      case 'status':
        return Icons.swap_horiz_outlined;
      case 'note':
        return Icons.sticky_note_2_outlined;
      case 'lead_created':
        return Icons.add_circle_outline;
      default:
        return Icons.history_outlined;
    }
  }

  Color _historyColor(String type, String status) {
    if (type == 'status' && status.isNotEmpty) {
      return _statusColor(status);
    }

    switch (type) {
      case 'claim':
        return BbmAdminTheme.purple600;
      case 'release':
        return BbmAdminTheme.textMuted;
      case 'note':
        return BbmAdminTheme.accentTeal;
      case 'activity':
        return BbmAdminTheme.accentIndigo;
      case 'lead_created':
        return BbmAdminTheme.accentAmber;
      default:
        return BbmAdminTheme.textMuted;
    }
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danger Zone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final confirmed = await showAdminConfirmDialog(context,
                title: 'Delete Lead?',
                message: 'Permanently deletes lead #${_lead['id']}. All claims will be lost.',
                confirmLabel: 'Delete',
                isDestructive: true,
              );
              if (confirmed != true) return;
              widget.onDelete(_adminInt(_lead, 'id')).catchError((Object error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
                );
              });
            },
            child: const Row(children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 10),
              Text('Delete This Lead', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 13)),
              Spacer(),
              Icon(Icons.chevron_right, color: Colors.red, size: 18),
            ]),
          ),
        ],
      ),
    );
  }

  void _saveChanges() {
    // setState(() => _saving = true);
    final updatedLead = {
      ..._lead,
      'status': _selectedStatus,
      'budget': _budgetCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'max_claims': _maxClaims,
    };
    widget.onUpdate(updatedLead).then((_) {
      if (!mounted) return;
      setState(() {
        _lead = updatedLead;
        _editMode = false;
        // _saving = false;
      });
      _loadLeadDetail(showLoading: false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead updated'), backgroundColor: Color(0xFF10B981)));
    }).catchError((Object error) {
      if (!mounted) return;
      // setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    });
  }
}
