import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'bbm_admin_theme.dart';
import 'admin_widgets.dart';

class AdminUserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final Future<void> Function(Map<String, dynamic> updatedUser) onSave;
  final Future<void> Function(int id, String newStatus) onStatusToggle;
  final Future<void> Function(int id) onDelete;

  const AdminUserDetailSheet({
    super.key,
    required this.user,
    required this.onSave,
    required this.onStatusToggle,
    required this.onDelete,
  });

  @override
  State<AdminUserDetailSheet> createState() => _AdminUserDetailSheetState();
}

class _AdminUserDetailSheetState extends State<AdminUserDetailSheet> {
  late Map<String, dynamic> _user;
  bool _editMode = false;
  bool _saving = false;
  bool _busy = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _businessCtrl;
  late TextEditingController _locationCtrl;
  late int _selectedLevel;

  @override
  void initState() {
    super.initState();
    _user = Map.from(widget.user);
    _nameCtrl = TextEditingController(text: _user['name'] as String);
    _phoneCtrl = TextEditingController(text: _user['phone'] as String);
    _businessCtrl = TextEditingController(text: _user['business'] as String);
    _locationCtrl = TextEditingController(text: _user['location'] as String);
    _selectedLevel = _user['level'] as int;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    final updatedUser = {
      ..._user,
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'business': _businessCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'level': _selectedLevel,
    };

    try {
      await widget.onSave(updatedUser);
      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _editMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus() async {
    final isActive = _user['status'] == 'active';
    final confirmed = await showAdminConfirmDialog(
      context,
      title: isActive ? 'Deactivate User?' : 'Activate User?',
      message: isActive
          ? 'This will revoke lead access and downgrade to level 5.'
          : 'This will activate the user and restore level 3 access.',
      confirmLabel: isActive ? 'Deactivate' : 'Activate',
      isDestructive: isActive,
    );
    if (confirmed != true) return;
    final newStatus = isActive ? 'inactive' : 'active';
    setState(() => _busy = true);
    try {
      await widget.onStatusToggle(_user['id'] as int, newStatus);
      if (!mounted) return;
      setState(() {
        _user['status'] = newStatus;
        _user['level'] = newStatus == 'active' ? 3 : 5;
        _selectedLevel = _user['level'] as int;
      });
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Delete User?',
      message:
          'This permanently deletes ${_user['name']}. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete(_user['id'] as int);
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _user['status'] == 'active';
    final isTelecaller = _user['role'] == 'telecaller';

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDD6FE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _buildSheetHeader(isActive),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _buildProfileCard(isActive, isTelecaller),
                  const SizedBox(height: 20),
                  _buildEditSection(isTelecaller),
                  const SizedBox(height: 20),
                  if (!isTelecaller) ...[
                    _buildSubscriptionSection(),
                    const SizedBox(height: 20),
                  ],
                  _buildDangerZone(isActive),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHeader(bool isActive) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Text(
            'User Detail',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: BbmAdminTheme.textPrimary,
            ),
          ),
          const Spacer(),
          if (!_editMode) ...[
            _headerAction(
              Icons.edit_outlined,
              BbmAdminTheme.purple600,
              () => setState(() => _editMode = true),
            ),
            const SizedBox(width: 8),
          ],
          if (_editMode)
            AdminGradientButton(
              label: 'Save',
              onTap: _saveChanges,
              isLoading: _saving,
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: BbmAdminTheme.bgMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: BbmAdminTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildProfileCard(bool isActive, bool isTelecaller) {
    final initials = (_user['name'] as String)
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: BbmAdminTheme.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BbmAdminTheme.purple700.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${_user['username']}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _whiteTag(isActive ? '● Active' : '○ Inactive'),
                    const SizedBox(width: 6),
                    _whiteTag(
                      isTelecaller
                          ? 'Telecaller'
                          : 'Artist · L${_user['level']}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEditSection(bool isTelecaller) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Profile Information'),
          const SizedBox(height: 14),
          AdminEditField(
            label: 'Full Name',
            controller: _nameCtrl,
            readOnly: !_editMode,
          ),
          const SizedBox(height: 12),
          AdminEditField(
            label: 'Phone / WhatsApp',
            controller: _phoneCtrl,
            readOnly: !_editMode,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          AdminEditField(
            label: 'Business Name',
            controller: _businessCtrl,
            readOnly: !_editMode,
          ),
          const SizedBox(height: 12),
          AdminEditField(
            label: 'Location',
            controller: _locationCtrl,
            readOnly: !_editMode,
          ),
          if (!isTelecaller && _editMode) ...[
            const SizedBox(height: 14),
            _sectionTitle('Artist Level'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 4, 5].map((lvl) {
                final isSelected = _selectedLevel == lvl;
                return GestureDetector(
                  onTap: () => setState(() => _selectedLevel = lvl),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected ? BbmAdminTheme.brandGradient : null,
                      color: isSelected ? null : BbmAdminTheme.bgMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'L$lvl · ${BbmAdminTheme.levelLabel(lvl)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : BbmAdminTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (!_editMode) ...[
            const SizedBox(height: 12),
            _infoRow('Joined', _user['joined'] as String),
            const SizedBox(height: 6),
            _infoRow('Role', (_user['role'] as String).toUpperCase()),
            const SizedBox(height: 6),
            if (!isTelecaller)
              _infoRow('Category', _user['category'] as String),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Subscription'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  'Plan',
                  _user['plan'] as String,
                  BbmAdminTheme.purple600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  'Total Claims',
                  '${_user['claims']}',
                  BbmAdminTheme.accentIndigo,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  'Level',
                  'L${_user['level']}',
                  BbmAdminTheme.levelColor(_user['level'] as int),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showGrantPlanDialog,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BbmAdminTheme.purple50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.card_giftcard_outlined,
                    color: BbmAdminTheme.purple600,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Grant / Override Plan',
                    style: TextStyle(
                      color: BbmAdminTheme.purple600,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: BbmAdminTheme.purple400,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(bool isActive) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danger Zone',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 14),
          _dangerAction(
            icon: isActive ? Icons.block_outlined : Icons.check_circle_outline,
            label: isActive ? 'Deactivate Account' : 'Activate Account',
            sub: isActive
                ? 'Revoke access & downgrade to L5'
                : 'Restore access & upgrade to L3',
            color: isActive ? Colors.orange : BbmAdminTheme.statusActive,
            onTap: _busy ? () {} : _toggleStatus,
          ),
          Divider(height: 20, color: Colors.red.shade50),
          _dangerAction(
            icon: Icons.delete_outline,
            label: 'Delete User',
            sub: 'Permanently removes from the system',
            color: Colors.red,
            onTap: _busy ? () {} : _confirmDelete,
          ),
        ],
      ),
    );
  }

  Widget _dangerAction({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: BbmAdminTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: color.withValues(alpha: 0.5),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: BbmAdminTheme.textPrimary,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: BbmAdminTheme.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BbmAdminTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: BbmAdminTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showGrantPlanDialog() {
    String selectedPlan = 'Basic';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Grant Plan',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: BbmAdminTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Trial', 'Basic', 'Extended'].map((plan) {
              return RadioGroup<String>(
                groupValue: selectedPlan,

                onChanged: (v) {
                  setS(() {
                    selectedPlan = v!;
                  });
                },

                child: RadioListTile<String>(
                  value: plan,
                  title: Text(plan),
                  activeColor: BbmAdminTheme.purple600,
                  contentPadding: EdgeInsets.zero,
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final planSlug = selectedPlan == 'Extended'
                    ? 'extended_basic'
                    : selectedPlan == 'Basic'
                    ? 'basic'
                    : 'trial';
                widget
                    .onSave({..._user, 'grant_plan_slug': planSlug})
                    .then((_) {
                      if (!mounted) return;
                      setState(() {
                        _user['plan'] = selectedPlan;
                        _user['status'] = 'active';
                        _user['level'] = selectedPlan == 'Extended'
                            ? 2
                            : selectedPlan == 'Basic'
                            ? 3
                            : 4;
                        _selectedLevel = _user['level'] as int;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$selectedPlan plan granted'),
                          backgroundColor: BbmAdminTheme.purple600,
                        ),
                      );
                    })
                    .catchError((Object error) {
                      if (!mounted) return;
                      final message = error is AdminApiException
                          ? error.message
                          : error.toString();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    });
              },
              child: const Text(
                'Grant',
                style: TextStyle(
                  color: BbmAdminTheme.purple600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
