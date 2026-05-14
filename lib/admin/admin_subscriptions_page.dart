import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'bbm_admin_theme.dart';
import 'admin_widgets.dart';

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _api = const AdminApiService();
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic> _globalSettings = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              AdminGradientButton(label: 'Retry', onTap: _loadSubscriptions),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildPlansTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.fetchSubscriptions();
      if (!mounted) return;
      setState(() {
        _plans = List<Map<String, dynamic>>.from(data['plans'] as List);
        _history = List<Map<String, dynamic>>.from(data['history'] as List);
        _globalSettings = Map<String, dynamic>.from(
          data['global_settings'] as Map,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: BbmAdminTheme.purple700,
        unselectedLabelColor: BbmAdminTheme.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorColor: BbmAdminTheme.purple600,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Plans & System Settings'),
          Tab(text: 'Subscription History'),
        ],
      ),
    );
  }

  Widget _buildPlansTab() {
    final activePlans = _plans.where((p) => p['active'] as bool).toList();
    final total = _history.length;
    final activeCount = _history.where((h) => h['status'] == 'active').length;
    final revenue = _history.fold<int>(0, (sum, h) => sum + (h['amount'] as int));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRevenueBanner(total, activeCount, revenue),
        const SizedBox(height: 20),
        const AdminSectionHeader(title: 'Plans (System Settings)'),
        ...activePlans.map((plan) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPlanCard(plan),
        )),
        const SizedBox(height: 8),
        const AdminSectionHeader(title: 'Global Settings'),
        _buildGlobalSettings(),
      ],
    );
  }

  Widget _buildRevenueBanner(int total, int active, int revenue) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: BbmAdminTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: BbmAdminTheme.purple700.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bannerKpi('Total Subs', '$total'),
          _vDivider(),
          _bannerKpi('Active', '$active'),
          _vDivider(),
          _bannerKpi('Revenue', '₹${_formatNumber(revenue)}'),
        ],
      ),
    );
  }

  Widget _bannerKpi(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 11)),
      ],
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2));

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final levelColor = BbmAdminTheme.levelColor(plan['level'] as int);
    return GestureDetector(
      onTap: () => _openPlanEditor(plan),
      child: Container(
        decoration: BbmAdminTheme.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('L${plan['level']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: levelColor)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(plan['name'] as String,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BbmAdminTheme.textPrimary)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${plan['price']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BbmAdminTheme.textPrimary)),
                    Text('${plan['subscribers']} subscribers', style: const TextStyle(fontSize: 10, color: BbmAdminTheme.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _settingChip('${plan['total_claims']} total claims', Icons.assignment_outlined),
                _settingChip('${plan['daily_claims']}/day', Icons.today_outlined),
                _settingChip('${plan['duration_days']}d duration', Icons.calendar_month_outlined),
                _settingChip('${plan['visibility_delay_hours']}h delay', Icons.visibility_outlined),
              ],
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_outlined, size: 14, color: BbmAdminTheme.purple500),
                SizedBox(width: 4),
                Text('Edit Settings', style: TextStyle(fontSize: 12, color: BbmAdminTheme.purple500, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BbmAdminTheme.bgMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: BbmAdminTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGlobalSettings() {
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        children: [
          _globalSettingRow('Lead auto-release (inactive)', '${_globalSettings['lead_auto_release_hours'] ?? 0} hours', Icons.timer_outlined),
          Divider(height: 1, color: BbmAdminTheme.bgMuted),
          _globalSettingRow('Lead visibility delay (Basic)', '${_globalSettings['lead_visibility_delay_hours'] ?? 0} hours', Icons.visibility_outlined),
          Divider(height: 1, color: BbmAdminTheme.bgMuted),
          _globalSettingRow('Claim lock duration', '${_globalSettings['claim_lock_duration_hours'] ?? 0} hours', Icons.lock_clock_outlined),
          Divider(height: 1, color: BbmAdminTheme.bgMuted),
          _globalSettingRow('Max claims per lead', '${_globalSettings['max_claims_per_lead'] ?? 0}', Icons.people_outline),
          Divider(height: 1, color: BbmAdminTheme.bgMuted),
          _globalSettingRow('FCM push notifications', (_globalSettings['fcm_push_notifications'] ?? false) ? 'Enabled' : 'Disabled', Icons.notifications_outlined),
        ],
      ),
    );
  }

  Widget _globalSettingRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: BbmAdminTheme.purple400),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: BbmAdminTheme.textPrimary))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BbmAdminTheme.purple600)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 16, color: BbmAdminTheme.textMuted),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('${_history.length} records', style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary)),
              const Spacer(),
              _statusSummary('Active', _history.where((h) => h['status'] == 'active').length, BbmAdminTheme.statusActive),
              const SizedBox(width: 10),
              _statusSummary('Expired', _history.where((h) => h['status'] == 'expired').length, BbmAdminTheme.statusInactive),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildHistoryCard(_history[i]),
          ),
        ),
      ],
    );
  }

  Widget _statusSummary(String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$count $label', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> h) {
    final isActive = h['status'] == 'active';
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: BbmAdminTheme.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_membership, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(h['user'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: BbmAdminTheme.textPrimary))),
                  StatusBadge(label: h['status'] as String, color: isActive ? BbmAdminTheme.statusActive : BbmAdminTheme.statusInactive, fontSize: 10),
                ]),
                const SizedBox(height: 2),
                Text(h['plan'] as String, style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary)),
                const SizedBox(height: 5),
                Row(children: [
                  Text('₹${h['amount']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BbmAdminTheme.purple600)),
                  const SizedBox(width: 8),
                  Text('·  ${h['date']}', style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textMuted)),
                  const Spacer(),
                  Text('Exp: ${h['expiry']}', style: TextStyle(fontSize: 10, color: isActive ? BbmAdminTheme.statusActive : BbmAdminTheme.textMuted, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openPlanEditor(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanEditorSheet(
        plan: plan,
        onSave: (updated) {
          _api.updatePlan(updated).then((_) {
            if (!mounted) return;
            setState(() {
              final idx = _plans.indexWhere((p) => p['id'] == updated['id']);
              if (idx != -1) _plans[idx] = updated;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Plan settings saved'), backgroundColor: Color(0xFF10B981)),
            );
          }).catchError((Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
            );
          });
        },
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Plan Editor Sheet ───────────────────────────────────────────────────────────
class _PlanEditorSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Function(Map<String, dynamic>) onSave;
  const _PlanEditorSheet({required this.plan, required this.onSave});

  @override
  State<_PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends State<_PlanEditorSheet> {
  late Map<String, dynamic> _plan;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _totalClaimsCtrl;
  late TextEditingController _dailyClaimsCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _visDelayCtrl;
  late TextEditingController _lockDurationCtrl;
  late TextEditingController _autoReleaseCtrl;

  @override
  void initState() {
    super.initState();
    _plan = Map.from(widget.plan);
    _nameCtrl = TextEditingController(text: '${_plan['name']}');
    _priceCtrl = TextEditingController(text: '${_plan['price']}');
    _totalClaimsCtrl = TextEditingController(text: '${_plan['total_claims']}');
    _dailyClaimsCtrl = TextEditingController(text: '${_plan['daily_claims']}');
    _durationCtrl = TextEditingController(text: '${_plan['duration_days']}');
    _visDelayCtrl = TextEditingController(text: '${_plan['visibility_delay_hours']}');
    _lockDurationCtrl = TextEditingController(text: '${_plan['claim_lock_duration_hours']}');
    _autoReleaseCtrl = TextEditingController(text: '${_plan['auto_release_hours']}');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _priceCtrl, _totalClaimsCtrl, _dailyClaimsCtrl, _durationCtrl, _visDelayCtrl, _lockDurationCtrl, _autoReleaseCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
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
              child: Row(children: [
                const Text('Edit Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BbmAdminTheme.textPrimary)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: BbmAdminTheme.bgMuted, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close, size: 18, color: BbmAdminTheme.textSecondary))),
              ]),
            ),
            Divider(color: BbmAdminTheme.bgMuted),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  AdminEditField(label: 'Plan Name', controller: _nameCtrl),
                  const SizedBox(height: 12),
                  AdminEditField(label: 'Price (₹)', controller: _priceCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  AdminEditField(label: 'Duration (days)', controller: _durationCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 18),
                  const Text('Claim Limits', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BbmAdminTheme.textPrimary)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: AdminEditField(label: 'Total Claims', controller: _totalClaimsCtrl, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: AdminEditField(label: 'Daily Claims', controller: _dailyClaimsCtrl, keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 18),
                  const Text('Timing Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BbmAdminTheme.textPrimary)),
                  const SizedBox(height: 12),
                  AdminEditField(label: 'Visibility Delay (hours)', controller: _visDelayCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  AdminEditField(label: 'Claim Lock Duration (hours)', controller: _lockDurationCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  AdminEditField(label: 'Auto-Release Inactive (hours)', controller: _autoReleaseCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 18),
                  Row(children: [
                    const Text('Can Claim Leads', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BbmAdminTheme.textPrimary)),
                    const Spacer(),
                    Switch(
                      value: _plan['can_claim'] as bool,
                      activeThumbColor: BbmAdminTheme.purple600,
                      onChanged: (v) => setState(() => _plan['can_claim'] = v),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  AdminGradientButton(
                    label: 'Save Plan Settings',
                    icon: Icons.save_outlined,
                    onTap: () {
                      _plan['name'] = _nameCtrl.text.trim();
                      _plan['price'] = int.tryParse(_priceCtrl.text) ?? _plan['price'];
                      _plan['total_claims'] = int.tryParse(_totalClaimsCtrl.text) ?? _plan['total_claims'];
                      _plan['daily_claims'] = int.tryParse(_dailyClaimsCtrl.text) ?? _plan['daily_claims'];
                      _plan['duration_days'] = int.tryParse(_durationCtrl.text) ?? _plan['duration_days'];
                      _plan['visibility_delay_hours'] = int.tryParse(_visDelayCtrl.text) ?? _plan['visibility_delay_hours'];
                      _plan['claim_lock_duration_hours'] = int.tryParse(_lockDurationCtrl.text) ?? _plan['claim_lock_duration_hours'];
                      _plan['auto_release_hours'] = int.tryParse(_autoReleaseCtrl.text) ?? _plan['auto_release_hours'];
                      widget.onSave(_plan);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
