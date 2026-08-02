import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'bbm_admin_theme.dart';
import 'admin_widgets.dart';
import 'admin_user_detail_sheet.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _api = const AdminApiService();
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';
  String _filterRole = 'All';
  String _searchQuery = '';
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _allUsers = [];

  List<Map<String, dynamic>> get _filtered {
    return _allUsers.where((u) {
      final matchSearch = _searchQuery.isEmpty ||
          (u['name'] as String).toLowerCase().contains(_searchQuery) ||
          (u['username'] as String).toLowerCase().contains(_searchQuery) ||
          (u['business'] as String).toLowerCase().contains(_searchQuery);
      final matchStatus = _filterStatus == 'All' || u['status'] == _filterStatus.toLowerCase();
      final matchRole = _filterRole == 'All' ||
          (_filterRole == 'Artist' && u['role'] == 'artist') ||
          (_filterRole == 'Telecaller' && u['role'] == 'telecaller');
      return matchSearch && matchStatus && matchRole;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await _api.fetchUsers();
      if (!mounted) return;
      setState(() => _allUsers = users);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminUserDetailSheet(
        user: user,
        onSave: (updatedUser) async {
          if (updatedUser['grant_plan_slug'] != null) {
            await _api.grantPlan(
              updatedUser['id'] as int,
              updatedUser['grant_plan_slug'] as String,
            );
            await _loadUsers();
            return;
          }

          await _api.updateUser({
            'id': updatedUser['id'],
            'name': updatedUser['name'],
            'phone': updatedUser['phone'],
            'business': updatedUser['business'],
            'location': updatedUser['location'],
            'level': updatedUser['level'],
          });
          setState(() {
            final idx = _allUsers.indexWhere((u) => u['id'] == updatedUser['id']);
            if (idx != -1) {
              _allUsers[idx] = updatedUser;
            }
          });
        },
        onStatusToggle: (id, newStatus) async {
          await _api.toggleUserStatus(id, newStatus);
          setState(() {
            final idx = _allUsers.indexWhere((u) => u['id'] == id);
            if (idx != -1) {
              _allUsers[idx]['status'] = newStatus;
              _allUsers[idx]['level'] = newStatus == 'active' ? 3 : 5;
            }
          });
        },
        onClaimLimitUpdate: (id, maxClaimLimit) async {
          final response = await _api.updateUserClaimLimit(id, maxClaimLimit);
          await _loadUsers();
          return response;
        },
        onDelete: (id) async {
          await _api.deleteUser(id);
          setState(() => _allUsers.removeWhere((u) => u['id'] == id));
          if (!mounted) return ;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted'), backgroundColor: Colors.red),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
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
              AdminGradientButton(label: 'Retry', onTap: _loadUsers),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: users.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildUserCard(users[i]),
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
            hint: 'Search by name, username, business…',
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AdminFilterChips(
                  options: const ['All', 'Active', 'Inactive'],
                  selected: _filterStatus,
                  onSelected: (v) => setState(() => _filterStatus = v),
                ),
              ),
              const SizedBox(width: 8),
              _roleDropdown(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_filtered.length} user${_filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showAddUserSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: BbmAdminTheme.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: BbmAdminTheme.purple600.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 15),
                      SizedBox(width: 4),
                      Text('Add User', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
        boxShadow: [BoxShadow(color: BbmAdminTheme.purple700.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterRole,
          icon: const Icon(Icons.expand_more, size: 16, color: BbmAdminTheme.textSecondary),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BbmAdminTheme.textSecondary),
          items: ['All', 'Artist', 'Telecaller'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _filterRole = v!),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isTelecaller = user['role'] == 'telecaller';
    final claims = _intValue(user, 'claims');
    final claimLimit = _intValue(user, 'claim_limit');

    return GestureDetector(
      onTap: () => _openUserDetail(user),
      child: Container(
        decoration: BbmAdminTheme.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _buildAvatar(user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: BbmAdminTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(
                        label: user['status'] as String,
                        color: BbmAdminTheme.statusColor(user['status'] as String),
                        fontSize: 10,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user['business'] as String,
                    style: const TextStyle(fontSize: 12, color: BbmAdminTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _tag(
                        isTelecaller ? 'Telecaller' : 'L${user['level']} · ${user['plan']}',
                        isTelecaller ? BbmAdminTheme.accentTeal : BbmAdminTheme.levelColor(user['level'] as int),
                      ),
                      const SizedBox(width: 6),
                      if (!isTelecaller) _tag(user['category'] as String, BbmAdminTheme.accentIndigo),
                      const Spacer(),
                      if (!isTelecaller)
                        Text(
                          '$claims / $claimLimit leads',
                          style: const TextStyle(fontSize: 11, color: BbmAdminTheme.textMuted),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: BbmAdminTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> user) {
    final initials = (user['name'] as String)
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: BbmAdminTheme.brandGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: BbmAdminTheme.purple600.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Center(
        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  int _intValue(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: BbmAdminTheme.purple400.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('No users found', style: TextStyle(color: BbmAdminTheme.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showAddUserSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddUserSheet(
        onAdd: (user) async {
          final response = await _api.createUser(user);
          await _loadUsers();
          if (!mounted) return;
          final password = (response['temporary_password'] ?? '').toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User created. Temporary password: $password'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }
}

// ─── Add User Sheet ────────────────────────────────────────────────────────────
class _AddUserSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onAdd;
  const _AddUserSheet({required this.onAdd});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  String _role = 'artist';
  String _category = 'Makeup';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AdminBottomSheet(
      title: 'Add New User',
      child: Column(
        children: [
          AdminEditField(label: 'Full Name', controller: _nameCtrl, hint: 'e.g. Priya Sharma'),
          const SizedBox(height: 14),
          AdminEditField(label: 'Username', controller: _usernameCtrl, hint: 'e.g. priya.sharma'),
          const SizedBox(height: 14),
          AdminEditField(label: 'Phone / WhatsApp', controller: _phoneCtrl, keyboardType: TextInputType.phone, hint: '9876543210'),
          const SizedBox(height: 14),
          AdminEditField(label: 'Business Name', controller: _businessCtrl, hint: 'e.g. Priya Bridal Studio'),
          const SizedBox(height: 14),
          _dropdownField('Role', _role, ['artist', 'telecaller'], (v) => setState(() => _role = v!)),
          const SizedBox(height: 14),
          if (_role == 'artist')
            _dropdownField('Category', _category, ['Makeup', 'Photography', 'Events (Dance, Catering etc.)', 'Others'], (v) => setState(() => _category = v!)),
          if (_role == 'artist') const SizedBox(height: 14),
          AdminGradientButton(
            label: 'Create User',
            icon: Icons.person_add_outlined,
            isLoading: _saving,
            onTap: () async {
              if (_nameCtrl.text.isEmpty || _usernameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
              setState(() => _saving = true);
              try {
                await widget.onAdd({
                'name': _nameCtrl.text.trim(),
                'username': _usernameCtrl.text.trim(),
                'phone': _phoneCtrl.text.trim(),
                'business': _businessCtrl.text.trim(),
                'role': _role,
                  'category': _role == 'artist' ? _category : '-',
                });
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _dropdownField(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BbmAdminTheme.textSecondary, letterSpacing: 0.3)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: BbmAdminTheme.textPrimary, fontWeight: FontWeight.w500),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared bottom sheet wrapper ──────────────────────────────────────────────
class _AdminBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _AdminBottomSheet({required this.title, required this.child});

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
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDDD6FE), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BbmAdminTheme.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: BbmAdminTheme.bgMuted, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.close, size: 18, color: BbmAdminTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: BbmAdminTheme.bgMuted),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
