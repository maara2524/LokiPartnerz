import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'bbm_admin_theme.dart';
import 'admin_widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  final _api = const AdminApiService();

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _categoryBreakdown = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(data['stats'] as Map);
        _recentActivity = List<Map<String, dynamic>>.from(
          data['recent_activity'] as List,
        );
        _categoryBreakdown = List<Map<String, dynamic>>.from(
          data['category_breakdown'] as List,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      debugPrint("Debug : Dashboard load error: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'subscription':
        return Icons.payment_outlined;
      case 'lead':
        return Icons.add_circle_outline;
      case 'new_user':
      default:
        return Icons.person_add_outlined;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'subscription':
        return const Color(0xFF6366F1);
      case 'lead':
        return const Color(0xFFEC4899);
      case 'new_user':
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildSkeleton();
    if (_error != null) return _buildError();
    return RefreshIndicator(
      color: BbmAdminTheme.purple600,
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTopBanner(),
          const SizedBox(height: 20),
          const AdminSectionHeader(title: 'Overview'),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Lead Status Breakdown'),
          _buildLeadBreakdown(),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Artist Categories'),
          _buildCategoryBreakdown(),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Recent Activity'),
          _buildActivityFeed(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: BbmAdminTheme.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BbmAdminTheme.purple700.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'BBM ADMIN CONTROL',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Bridal Booker Machine',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All systems operational · Last synced from live backend',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          // Row(
          //   children: [
          //     _bannerStat('Total Revenue', _stats['revenue'].toString()),
          //     const SizedBox(width: 24),
          //     _bannerStat(
          //       'Active Plans',
          //       _stats['activeSubscriptions'].toString(),
          //     ),
          //     const SizedBox(width: 24),
          //     _bannerStat('Telecallers', _stats['telecallers'].toString()),
          //   ],
          // ),
        ],
      ),
    );
  }

  // Widget _bannerStat(String label, String value) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         value,
  //         style: const TextStyle(
  //           color: Colors.white,
  //           fontSize: 18,
  //           fontWeight: FontWeight.w800,
  //         ),
  //       ),
  //       Text(
  //         label,
  //         style: TextStyle(
  //           color: Colors.white.withValues(alpha: 0.7),
  //           fontSize: 10,
  //           fontWeight: FontWeight.w500,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildStatsGrid() {
    final stats = [
      {
        'label': 'Total Users',
        'value': '${_stats['totalUsers'] ?? 0}',
        'icon': Icons.people_rounded,
        'color': BbmAdminTheme.purple600,
        'sub': 'All roles',
      },
      {
        'label': 'Active Artists',
        'value': '${_stats['activeArtists'] ?? 0}',
        'icon': Icons.brush_rounded,
        'color': BbmAdminTheme.statusActive,
        'sub': '+12 this week',
      },
      {
        'label': 'Total Leads',
        'value': '${_stats['totalLeads'] ?? 0}',
        'icon': Icons.leaderboard_rounded,
        'color': BbmAdminTheme.accentIndigo,
        'sub': 'All time',
      },
      {
        'label': 'Open Leads',
        'value': '${_stats['openLeads'] ?? 0}',
        'icon': Icons.inbox_rounded,
        'color': BbmAdminTheme.accentAmber,
        'sub': 'Unclaimed',
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: stats
          .map(
            (s) => AdminStatCard(
              label: s['label'] as String,
              value: s['value'] as String,
              icon: s['icon'] as IconData,
              color: s['color'] as Color,
              subtitle: s['sub'] as String,
            ),
          )
          .toList(),
    );
  }

  Widget _buildLeadBreakdown() {
    final data = [
      {
        'label': 'Open',
        'count': (_stats['openLeads'] ?? 0) as int,
        'color': BbmAdminTheme.accentAmber,
      },
      {
        'label': 'Claimed',
        'count': (_stats['claimedLeads'] ?? 0) as int,
        'color': BbmAdminTheme.accentIndigo,
      },
      {
        'label': 'Booked',
        'count': (_stats['bookedLeads'] ?? 0) as int,
        'color': BbmAdminTheme.statusActive,
      },
    ];
    final total =
        ((_stats['openLeads'] ?? 0) as int) +
        ((_stats['claimedLeads'] ?? 0) as int) +
        ((_stats['bookedLeads'] ?? 0) as int);
    final safeTotal = total == 0 ? 1 : total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        children: data.map((item) {
          final pct = (item['count'] as int) / safeTotal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['label'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BbmAdminTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${item['count']}  (${(pct * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BbmAdminTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: BbmAdminTheme.bgMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item['color'] as Color,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        children: _categoryBreakdown.asMap().entries.map((entry) {
          final item = entry.value;
          final isLast = entry.key == _categoryBreakdown.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: BbmAdminTheme.purple100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.category_outlined,
                        color: BbmAdminTheme.purple600,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['category'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BbmAdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: item['pct'] as double,
                              backgroundColor: BbmAdminTheme.bgMuted,
                              valueColor: const AlwaysStoppedAnimation(
                                BbmAdminTheme.purple500,
                              ),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${item['count']} artists',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BbmAdminTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: BbmAdminTheme.bgMuted),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      decoration: BbmAdminTheme.cardDecoration,
      child: Column(
        children: _recentActivity.asMap().entries.map((entry) {
          final item = entry.value;
          final isLast = entry.key == _recentActivity.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _activityColor(item['type'] as String).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _activityIcon(item['type'] as String),
                        color: _activityColor(item['type'] as String),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: BbmAdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['detail'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: BbmAdminTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['time'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: BbmAdminTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, color: BbmAdminTheme.bgMuted, indent: 66),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _shimmer(height: 160, radius: 20),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: List.generate(4, (_) => _shimmer(height: 100, radius: 16)),
        ),
        const SizedBox(height: 24),
        _shimmer(height: 120, radius: 16),
      ],
    );
  }

  Widget _shimmer({required double height, double radius = 12}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: BbmAdminTheme.purple100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: BbmAdminTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load dashboard',
              textAlign: TextAlign.center,
              style: const TextStyle(color: BbmAdminTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            AdminGradientButton(label: 'Retry', onTap: _loadDashboard),
          ],
        ),
      ),
    );
  }
}
