import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Activity Logs Screen  -  Premium Timeline Design (Light & Dark Futuristic)
// ─────────────────────────────────────────────────────────────────────────────

class LogsListScreen extends StatefulWidget {
  const LogsListScreen({super.key});

  @override
  State<LogsListScreen> createState() => _LogsListScreenState();
}

class _LogsListScreenState extends State<LogsListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  static const _bg = Color(0xFFF8FAFC);
  static const _slate = Color(0xFF0F172A);
  static const _teal = Color(0xFF0D9488);
  static const _textMuted = Color(0xFF64748B);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return 'Pending';
    final d = value.toDate().toLocal();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    return '$day/$mon/${d.year}  $h:$m';
  }

  String _timeAgo(dynamic value) {
    if (value is! Timestamp) return '';
    final diff = DateTime.now().difference(value.toDate().toLocal());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _formatTimestamp(value);
  }

  _ActionStyle _styleForAction(String action, bool isDark) {
    final lower = action.toLowerCase();
    if (isDark) {
      switch (lower) {
        case 'create':
        case 'add':
        case 'added':
          return _ActionStyle(
            bg: FuturisticColors.neonTeal.withValues(alpha: 0.16),
            fg: FuturisticColors.neonTeal,
            border: FuturisticColors.neonTeal.withValues(alpha: 0.5),
            icon: Icons.add_circle_outline_rounded,
            label: 'CREATE',
          );
        case 'update':
        case 'edit':
        case 'edited':
        case 'updated':
          return _ActionStyle(
            bg: FuturisticColors.neonAmber.withValues(alpha: 0.16),
            fg: FuturisticColors.neonAmber,
            border: FuturisticColors.neonAmber.withValues(alpha: 0.5),
            icon: Icons.edit_outlined,
            label: 'UPDATE',
          );
        case 'delete':
        case 'deleted':
        case 'remove':
          return _ActionStyle(
            bg: FuturisticColors.neonCrimson.withValues(alpha: 0.16),
            fg: FuturisticColors.neonCrimson,
            border: FuturisticColors.neonCrimson.withValues(alpha: 0.5),
            icon: Icons.delete_outline_rounded,
            label: 'DELETE',
          );
        case 'login':
        case 'logout':
          return _ActionStyle(
            bg: FuturisticColors.neonViolet.withValues(alpha: 0.16),
            fg: FuturisticColors.neonViolet,
            border: FuturisticColors.neonViolet.withValues(alpha: 0.5),
            icon: Icons.login_rounded,
            label: action.toUpperCase(),
          );
        case 'payment':
        case 'transaction':
          return _ActionStyle(
            bg: FuturisticColors.neonCyan.withValues(alpha: 0.16),
            fg: FuturisticColors.neonCyan,
            border: FuturisticColors.neonCyan.withValues(alpha: 0.5),
            icon: Icons.payments_outlined,
            label: 'PAYMENT',
          );
        default:
          return _ActionStyle(
            bg: const Color(0xFF16233B),
            fg: FuturisticColors.textSecondary,
            border: const Color(0xFF2E4064),
            icon: Icons.history_rounded,
            label: action.toUpperCase(),
          );
      }
    } else {
      switch (lower) {
        case 'create':
        case 'add':
        case 'added':
          return _ActionStyle(
            bg: const Color(0xFFECFDF5),
            fg: const Color(0xFF059669),
            border: const Color(0xFFA7F3D0),
            icon: Icons.add_circle_outline_rounded,
            label: 'CREATE',
          );
        case 'update':
        case 'edit':
        case 'edited':
        case 'updated':
          return _ActionStyle(
            bg: const Color(0xFFFFFBEB),
            fg: const Color(0xFFD97706),
            border: const Color(0xFFFDE68A),
            icon: Icons.edit_outlined,
            label: 'UPDATE',
          );
        case 'delete':
        case 'deleted':
        case 'remove':
          return _ActionStyle(
            bg: const Color(0xFFFEF2F2),
            fg: const Color(0xFFEF4444),
            border: const Color(0xFFFECACA),
            icon: Icons.delete_outline_rounded,
            label: 'DELETE',
          );
        case 'login':
        case 'logout':
          return _ActionStyle(
            bg: const Color(0xFFEEF2FF),
            fg: const Color(0xFF6366F1),
            border: const Color(0xFFC7D2FE),
            icon: Icons.login_rounded,
            label: action.toUpperCase(),
          );
        case 'payment':
        case 'transaction':
          return _ActionStyle(
            bg: const Color(0xFFF0FDFA),
            fg: const Color(0xFF0D9488),
            border: const Color(0xFFCCFBF1),
            icon: Icons.payments_outlined,
            label: 'PAYMENT',
          );
        default:
          return _ActionStyle(
            bg: const Color(0xFFF1F5F9),
            fg: const Color(0xFF475569),
            border: const Color(0xFFCBD5E1),
            icon: Icons.history_rounded,
            label: action.toUpperCase(),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FuturisticColors.bgVoid : _bg,
      appBar: AppBar(
        backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Logs',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? FuturisticColors.textPrimary : _slate,
                letterSpacing: isDark ? 0.3 : 0,
              ),
            ),
            Text(
              'Live system activity timeline',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? FuturisticColors.neonCyan : _textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.neonCyan.withValues(alpha: 0.12)
                  : _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: isDark
                  ? Border.all(color: FuturisticColors.neonCyan.withValues(alpha: 0.3))
                  : null,
            ),
            child: IconButton(
              tooltip: 'Refresh',
              icon: Icon(
                Icons.refresh_rounded,
                color: isDark ? FuturisticColors.neonCyan : _teal,
                size: 20,
              ),
              onPressed: () => setState(() {}),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? FuturisticColors.textPrimary : _slate,
              ),
              decoration: InputDecoration(
                hintText: 'Search by user, action, entity...',
                hintStyle: TextStyle(
                  color: isDark ? FuturisticColors.textMuted : _textMuted,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? FuturisticColors.neonCyan : _textMuted,
                  size: 20,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? FuturisticColors.textSecondary : _textMuted,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? FuturisticColors.bgInput : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: isDark
                      ? const BorderSide(color: FuturisticColors.cyberBorder)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: isDark
                      ? const BorderSide(color: FuturisticColors.borderSubtle)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: isDark
                      ? const BorderSide(color: FuturisticColors.neonCyan, width: 1.2)
                      : BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('activity_logs')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString(), isDark: isDark);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: isDark ? FuturisticColors.neonCyan : _teal,
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Loading activity logs...',
                    style: TextStyle(
                      color: isDark ? FuturisticColors.textSecondary : _textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          final allLogs = snapshot.data?.docs ?? [];
          final logs = _search.isEmpty
              ? allLogs
              : allLogs.where((doc) {
                  final d = doc.data();
                  final action = (d['action'] ?? '').toString().toLowerCase();
                  final entity = (d['entity'] ?? '').toString().toLowerCase();
                  final user = (d['userName'] ?? '').toString().toLowerCase();
                  final details = d['details'] is Map
                      ? (d['details'] as Map).values.join(' ').toLowerCase()
                      : '';
                  return action.contains(_search) ||
                      entity.contains(_search) ||
                      user.contains(_search) ||
                      details.contains(_search);
                }).toList();

          if (allLogs.isEmpty) return _EmptyState(isDark: isDark);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _StatsBanner(
                  total: allLogs.length,
                  filtered: logs.length,
                  isFiltered: _search.isNotEmpty,
                  isDark: isDark,
                ),
              ),
              if (logs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: isDark ? FuturisticColors.textMuted : _textMuted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No matching logs',
                          style: TextStyle(
                            color: isDark ? FuturisticColors.textSecondary : _textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  sliver: SliverList.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 0),
                    itemBuilder: (context, index) {
                      final log = logs[index].data();
                      final action = (log['action'] ?? 'activity').toString();
                      final entity = (log['entity'] ?? '').toString();
                      final userName = (log['userName'] ?? 'Unknown').toString();
                      final details = log['details'] is Map ? log['details'] as Map : const {};
                      final style = _styleForAction(action, isDark);
                      final isLast = index == logs.length - 1;
                      return _LogTile(
                        action: action,
                        entity: entity,
                        userName: userName,
                        details: details,
                        timeAgo: _timeAgo(log['createdAt']),
                        fullTime: _formatTimestamp(log['createdAt']),
                        style: style,
                        isLast: isLast,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Stats Banner ─────────────────────────────────────────────────────────────
class _StatsBanner extends StatelessWidget {
  final int total;
  final int filtered;
  final bool isFiltered;
  final bool isDark;

  const _StatsBanner({
    required this.total,
    required this.filtered,
    required this.isFiltered,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? FuturisticColors.cyberBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? FuturisticColors.glowShadow
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isDark ? 10 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.neonCyan.withValues(alpha: 0.16)
                  : const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.timeline_rounded,
              color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFiltered
                      ? 'Showing $filtered of $total logs'
                      : '$total activity logs loaded',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Last 300 entries, newest first',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.neonTeal.withValues(alpha: 0.15)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: isDark
                  ? Border.all(color: FuturisticColors.neonTeal.withValues(alpha: 0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: isDark
                        ? [
                            const BoxShadow(
                              color: FuturisticColors.neonTeal,
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Log Tile ─────────────────────────────────────────────────────────────────
class _LogTile extends StatefulWidget {
  final String action;
  final String entity;
  final String userName;
  final Map details;
  final String timeAgo;
  final String fullTime;
  final _ActionStyle style;
  final bool isLast;
  final bool isDark;

  const _LogTile({
    required this.action,
    required this.entity,
    required this.userName,
    required this.details,
    required this.timeAgo,
    required this.fullTime,
    required this.style,
    required this.isLast,
    required this.isDark,
  });

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  bool _expanded = false;

  String get _initials {
    final parts = widget.userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.style.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.style.border, width: 1.5),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: widget.style.fg.withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Icon(widget.style.icon, color: widget.style.fg, size: 17),
              ),
              if (!widget.isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),

          // Card
          Expanded(
            child: GestureDetector(
              onTap: widget.details.isNotEmpty
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? FuturisticColors.bgCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.style.bg,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: widget.style.border, width: 0.8),
                          ),
                          child: Text(
                            widget.style.label,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: widget.style.fg,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (widget.entity.isNotEmpty)
                          Expanded(
                            child: Text(
                              widget.entity.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          widget.timeAgo,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? FuturisticColors.textSecondary : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // User row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: isDark
                              ? FuturisticColors.neonCyan.withValues(alpha: 0.18)
                              : const Color(0xFF0D9488).withValues(alpha: 0.12),
                          child: Text(
                            _initials,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.userName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? FuturisticColors.textPrimary : const Color(0xFF334155),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.fullTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? FuturisticColors.textMuted : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),

                    // Details expandable
                    if (widget.details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AnimatedCrossFade(
                        firstChild: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ...widget.details.entries.take(2).map(
                                  (e) => _DetailChip(
                                    label: '${e.key}',
                                    value: '${e.value}',
                                    isDark: isDark,
                                  ),
                                ),
                            if (widget.details.length > 2 && !_expanded)
                              _MoreChip(count: widget.details.length - 2, isDark: isDark),
                          ],
                        ),
                        secondChild: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: widget.details.entries
                              .map(
                                (e) => _DetailChip(
                                  label: '${e.key}',
                                  value: '${e.value}',
                                  isDark: isDark,
                                ),
                              )
                              .toList(),
                        ),
                        crossFadeState: _expanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Chip ──────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailChip({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgInput : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  final int count;
  final bool isDark;

  const _MoreChip({required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? FuturisticColors.neonViolet.withValues(alpha: 0.18)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? FuturisticColors.neonViolet.withValues(alpha: 0.4)
              : const Color(0xFFC7D2FE),
        ),
      ),
      child: Text(
        '+$count more',
        style: TextStyle(
          fontSize: 10.5,
          color: isDark ? FuturisticColors.neonViolet : const Color(0xFF6366F1),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Empty / Error States ─────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? FuturisticColors.bgCard : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: isDark ? Border.all(color: FuturisticColors.cyberBorder) : null,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 34,
              color: isDark ? FuturisticColors.neonCyan : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Activity Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'System activity will appear here\nas users interact with the app.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ErrorState({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDark
                    ? FuturisticColors.neonCrimson.withValues(alpha: 0.15)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: isDark
                    ? Border.all(color: FuturisticColors.neonCrimson.withValues(alpha: 0.4))
                    : null,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 30,
                color: isDark ? FuturisticColors.neonCrimson : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load logs',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Style Model ───────────────────────────────────────────────────────
class _ActionStyle {
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;
  final String label;

  const _ActionStyle({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
    required this.label,
  });
}
