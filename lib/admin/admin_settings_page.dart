import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_api_service.dart';
import 'admin_widgets.dart';
import 'bbm_admin_theme.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _api = const AdminApiService();
  final _appVersionCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();
  final _updateMessageCtrl = TextEditingController();
  final _apiBaseCtrl = TextEditingController();

  bool _loading = true, _forceUpdate = false, _fcm = true, _meta = true;
  bool _leadLock = true, _autoRelease = true, _introVideo = true, _maint = false;
  bool _savingVersion = false, _savingToggles = false, _savingApi = false;
  bool _runningDanger = false, _signingOut = false;
  String? _error;
  List<Map<String, dynamic>> _ui = [];
  List<Map<String, dynamic>> _telecallers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _appVersionCtrl.dispose();
    _minVersionCtrl.dispose();
    _updateMessageCtrl.dispose();
    _apiBaseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            AdminGradientButton(label: 'Retry', onTap: () => _load()),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _identity(),
        const SizedBox(height: 20),
        const AdminSectionHeader(title: 'App Version Control'),
        _versionCard(),
        const SizedBox(height: 20),
        const AdminSectionHeader(title: 'System Toggles'),
        _togglesCard(),
        const SizedBox(height: 20),
        const AdminSectionHeader(title: 'UI Content Config'),
        _uiCard(),
        const SizedBox(height: 20),
        AdminSectionHeader(title: 'Telecaller Management', actionLabel: '+ Add', onAction: _showAddTelecaller),
        _telecallerCard(),
        const SizedBox(height: 20),
        const AdminSectionHeader(title: 'API / Backend'),
        _apiCard(),
        const SizedBox(height: 20),
        _dangerCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _identity() {
    final host = Uri.tryParse(_apiBaseCtrl.text.trim())?.host;
    final hostLabel = (host?.isNotEmpty ?? false) ? host! : (_apiBaseCtrl.text.trim().isEmpty ? 'Not configured' : _apiBaseCtrl.text.trim());
    final versionLabel = _appVersionCtrl.text.trim().isEmpty ? 'Version unavailable' : 'v${_appVersionCtrl.text.trim()}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: BbmAdminTheme.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: BbmAdminTheme.purple700.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('BBM Administrator', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('Full system access · Role: Admin', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [_PillTag(hostLabel), const SizedBox(width: 6), _PillTag(versionLabel)]),
          ]),
        ),
      ]),
    );
  }

  Widget _versionCard() {
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        AdminEditField(label: 'Current App Version', controller: _appVersionCtrl),
        const SizedBox(height: 12),
        AdminEditField(label: 'Minimum Required Version', controller: _minVersionCtrl),
        const SizedBox(height: 12),
        AdminEditField(label: 'Force Update Message', controller: _updateMessageCtrl, maxLines: 3),
        const SizedBox(height: 14),
        _toggleRow('Force Update Required', _forceUpdate, (v) => setState(() => _forceUpdate = v)),
        const SizedBox(height: 14),
        AdminGradientButton(label: 'Save Version Config', icon: Icons.save_outlined, isLoading: _savingVersion, onTap: _saveVersion),
      ]),
    );
  }

  Widget _togglesCard() {
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(children: [
        _toggleTile('FCM Push Notifications', 'Send lead alerts to artists', Icons.notifications_outlined, _fcm, (v) => setState(() => _fcm = v)),
        _divider(),
        _toggleTile('Meta/Facebook Events', 'Track onboarding funnel analytics', Icons.campaign_outlined, _meta, (v) => setState(() => _meta = v)),
        _divider(),
        _toggleTile('Lead Claim Lock', 'Enforce claim lock duration per plan', Icons.lock_outline, _leadLock, (v) => setState(() => _leadLock = v)),
        _divider(),
        _toggleTile('Auto-Release Leads', 'Release unclaimed leads automatically', Icons.timer_outlined, _autoRelease, (v) => setState(() => _autoRelease = v)),
        _divider(),
        _toggleTile('Subscription Intro Video', 'Show video on subscription page', Icons.play_circle_outline, _introVideo, (v) => setState(() => _introVideo = v)),
        _divider(),
        _toggleTile('Maintenance Mode', 'Blocks all artist app access', Icons.build_outlined, _maint, (v) => setState(() => _maint = v), isDestructive: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AdminGradientButton(label: 'Save System Toggles', icon: Icons.tune_outlined, isLoading: _savingToggles, onTap: _saveToggles),
        ),
      ]),
    );
  }

  Widget _toggleTile(String title, String sub, IconData icon, bool value, ValueChanged<bool> onChanged, {bool isDestructive = false}) {
    final color = isDestructive ? Colors.red : BbmAdminTheme.purple600;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDestructive ? Colors.red : BbmAdminTheme.textPrimary)),
            Text(sub, style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textMuted)),
          ]),
        ),
        Switch(value: value, activeThumbColor: isDestructive ? Colors.red : BbmAdminTheme.purple600, onChanged: onChanged),
      ]),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BbmAdminTheme.textPrimary)),
      const Spacer(),
      Switch(value: value, activeThumbColor: BbmAdminTheme.purple600, onChanged: onChanged),
    ]);
  }

  Widget _uiCard() {
    if (_ui.isEmpty) return _empty('No UI config rows found.');
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(children: _ui.asMap().entries.map((entry) {
        final item = entry.value;
        final last = entry.key == _ui.length - 1;
        return Column(children: [
          GestureDetector(
            onTap: () => _editUi(entry.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [_screenTag(item['screen'] as String), const SizedBox(width: 6), Text(item['key'] as String, style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textMuted))]),
                    const SizedBox(height: 4),
                    Text(item['value'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: BbmAdminTheme.textPrimary, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const Icon(Icons.edit_outlined, size: 16, color: BbmAdminTheme.textMuted),
              ]),
            ),
          ),
          if (!last) _divider(),
        ]);
      }).toList()),
    );
  }

  Widget _screenTag(String screen) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: BbmAdminTheme.purple100, borderRadius: BorderRadius.circular(5)),
    child: Text(screen, style: const TextStyle(fontSize: 9, color: BbmAdminTheme.purple600, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  );

  Widget _telecallerCard() {
    if (_telecallers.isEmpty) return _empty('No telecallers have been added yet.');
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(children: _telecallers.asMap().entries.map((entry) {
        final tc = entry.value;
        final last = entry.key == _telecallers.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: BbmAdminTheme.brandGradient, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text((tc['name'] as String).split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tc['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BbmAdminTheme.textPrimary)),
                  Text('${tc['phone']}  ·  @${tc['username']}', style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textSecondary)),
                ]),
              ),
              StatusBadge(label: tc['status'] as String, color: BbmAdminTheme.statusColor(tc['status'] as String), fontSize: 10),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  final ok = await showAdminConfirmDialog(context, title: 'Remove Telecaller?', message: 'This will revoke their telecaller access.', confirmLabel: 'Remove', isDestructive: true);
                  if (ok == true) await _removeTelecaller(tc);
                },
                child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
              ),
            ]),
          ),
          if (!last) _divider(),
        ]);
      }).toList()),
    );
  }

  Widget _apiCard() {
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        AdminEditField(label: 'API Base URL', controller: _apiBaseCtrl),
        const SizedBox(height: 12),
        const AdminEditField(label: 'Razorpay Key ID', initialValue: 'rzp_live_••••••••••••', readOnly: true, hint: 'Stored in backend securely'),
        const SizedBox(height: 14),
        AdminGradientButton(label: 'Save API Config', icon: Icons.cloud_upload_outlined, isLoading: _savingApi, onTap: _saveApi),
      ]),
    );
  }

  Widget _dangerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade100, width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Danger Zone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
        const SizedBox(height: 14),
        _dangerItem(
          icon: Icons.cleaning_services_outlined,
          label: 'Release All Locked Leads',
          sub: _runningDanger ? 'Releasing locked leads now...' : 'Force-unlocks every lead currently locked',
          onTap: _runningDanger ? null : () async {
            final ok = await showAdminConfirmDialog(context, title: 'Release All Leads?', message: 'All locked leads will be released immediately.', confirmLabel: 'Release', isDestructive: true);
            if (ok == true) await _releaseAll();
          },
        ),
        _divider(),
        _dangerItem(
          icon: Icons.logout_outlined,
          label: 'Admin Sign Out',
          sub: _signingOut ? 'Ending your current admin session...' : 'Ends your current admin session',
          onTap: _signingOut ? null : () async {
            final ok = await showAdminConfirmDialog(context, title: 'Sign Out?', message: 'You will be returned to the login screen.', confirmLabel: 'Sign Out');
            if (ok == true) await _signOut();
          },
        ),
      ]),
    );
  }

  Widget _dangerItem({required IconData icon, required String label, required String sub, required Future<void> Function()? onTap}) {
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap(),
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.red, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
              Text(sub, style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textMuted)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.red, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: BbmAdminTheme.bgMuted, indent: 16, endIndent: 16);

  Widget _empty(String text) => Container(
    decoration: BbmAdminTheme.cardDecoration,
    padding: const EdgeInsets.all(16),
    child: Text(text, style: const TextStyle(fontSize: 13, color: BbmAdminTheme.textSecondary)),
  );

  void _editUi(int index) {
    final item = _ui[index];
    final ctrl = TextEditingController(text: item['value'] as String);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: BbmAdminTheme.bgPrimary, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit: ${item['key']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BbmAdminTheme.textPrimary)),
            const SizedBox(height: 14),
            AdminEditField(label: 'Value', controller: ctrl, maxLines: 3),
            const SizedBox(height: 16),
            AdminGradientButton(label: 'Update', onTap: () async {
              try {
                final res = await _api.updateUiConfig({'id': item['id'], 'screen': item['screen'], 'key': item['key'], 'value': ctrl.text.trim(), 'status': item['status'] ?? 1});
                if (!mounted) return;
                setState(() => _ui[index] = {...item, 'id': res['id'] ?? item['id'], 'value': ctrl.text.trim()});
                Navigator.pop(context);
                _ok('UI content updated');
              } catch (e) {
                if (mounted) _fail(e);
              }
            }),
          ]),
        ),
      ),
    );
  }

  void _showAddTelecaller() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: BbmAdminTheme.bgPrimary, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Telecaller', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BbmAdminTheme.textPrimary)),
            const SizedBox(height: 16),
            AdminEditField(label: 'Name', controller: nameCtrl),
            const SizedBox(height: 12),
            AdminEditField(label: 'Phone', controller: phoneCtrl, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            AdminGradientButton(label: 'Create Telecaller Account', icon: Icons.person_add_outlined, onTap: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                _fail('Name and phone are required');
                return;
              }
              try {
                final res = await _api.createTelecaller({'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim()});
                if (!mounted) return;
                Navigator.pop(context);
                await _load(showLoader: false);
                final u = (res['username'] ?? '').toString();
                final p = (res['temporary_password'] ?? '').toString();
                if (mounted) _ok(u.isEmpty ? 'Telecaller created successfully' : 'Telecaller created. Username: $u, Temp password: $p');
              } catch (e) {
                if (mounted) _fail(e);
              }
            }),
          ]),
        ),
      ),
    );
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      final data = await _api.fetchSettings();
      final version = Map<String, dynamic>.from(data['version'] as Map);
      final toggles = Map<String, dynamic>.from(data['toggles'] as Map);
      final api = Map<String, dynamic>.from(data['api'] as Map);
      if (!mounted) return;
      setState(() {
        _appVersionCtrl.text = '${version['latest_version'] ?? ''}';
        _minVersionCtrl.text = '${version['minimum_version'] ?? ''}';
        _updateMessageCtrl.text = '${version['update_message'] ?? ''}';
        _apiBaseCtrl.text = '${api['base_url'] ?? ''}';
        _forceUpdate = version['update_required'] == true;
        _fcm = toggles['fcm_enabled'] == true;
        _meta = toggles['meta_events_enabled'] == true;
        _leadLock = toggles['lead_lock_enabled'] == true;
        _autoRelease = toggles['auto_release_enabled'] == true;
        _introVideo = toggles['subscription_intro_video'] == true;
        _maint = toggles['maintenance_mode'] == true;
        _ui = List<Map<String, dynamic>>.from(data['ui_config'] as List);
        _telecallers = List<Map<String, dynamic>>.from(data['telecallers'] as List);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted && showLoader) setState(() => _loading = false);
    }
  }

  Future<void> _saveVersion() async {
    setState(() => _savingVersion = true);
    try {
      await _api.updateVersion({'latest_version': _appVersionCtrl.text.trim(), 'minimum_version': _minVersionCtrl.text.trim(), 'update_required': _forceUpdate, 'update_message': _updateMessageCtrl.text.trim()});
      if (mounted) _ok('Version config saved');
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _savingVersion = false);
    }
  }

  Future<void> _saveToggles() async {
    setState(() => _savingToggles = true);
    try {
      await _api.updateToggles({'fcm_enabled': _fcm, 'meta_events_enabled': _meta, 'lead_lock_enabled': _leadLock, 'auto_release_enabled': _autoRelease, 'subscription_intro_video': _introVideo, 'maintenance_mode': _maint});
      if (mounted) _ok('System toggles updated');
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _savingToggles = false);
    }
  }

  Future<void> _saveApi() async {
    setState(() => _savingApi = true);
    try {
      await _api.updateToggles({'api_base_url': _apiBaseCtrl.text.trim()});
      if (mounted) _ok('API config saved');
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _savingApi = false);
    }
  }

  Future<void> _removeTelecaller(Map<String, dynamic> tc) async {
    try {
      await _api.removeTelecaller(id: tc['id'] as int, userId: tc['user_id'] as int?);
      if (!mounted) return;
      setState(() => _telecallers.removeWhere((item) => item['id'] == tc['id']));
      _ok('Telecaller access revoked');
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _releaseAll() async {
    setState(() => _runningDanger = true);
    try {
      final res = await _api.releaseAllLockedLeads();
      if (mounted) _ok('Released ${(res['released_count'] ?? 0)} locked leads');
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _runningDanger = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['auth_token', 'role', 'user_id', 'level', 'username', 'status', 'business_name']) {
        await prefs.remove(key);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _ok(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF10B981)));
  void _fail(Object err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString()), backgroundColor: Colors.red));
}

class _PillTag extends StatelessWidget {
  final String label;
  const _PillTag(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
