import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class PeriodSection {
  final String? id;
  final String name;
  final DateTime startDate; // always the 1st of the start month
  final DateTime endDate;   // always the last day of the end month
  final int sectionNumber;
  final DateTime createdAt;

  PeriodSection({
    this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.sectionNumber,
    required this.createdAt,
  });

  /// e.g.  "Jan 2026 – Mar 2026"
  String get displayRange =>
      '${DateFormat('MMM yyyy').format(startDate)} – ${DateFormat('MMM yyyy').format(endDate)}';

  /// Number of months covered
  int get monthCount =>
      (endDate.year - startDate.year) * 12 +
      endDate.month -
      startDate.month +
      1;

  Map<String, dynamic> toMap() => {
        'name': name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'sectionNumber': sectionNumber,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory PeriodSection.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      return DateTime.parse(d.toString());
    }

    return PeriodSection(
      id: id,
      name: map['name'] ?? '',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      sectionNumber: map['sectionNumber'] ?? 1,
      createdAt: parseDate(map['createdAt']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PeriodSectionsScreen extends StatefulWidget {
  const PeriodSectionsScreen({super.key});

  @override
  State<PeriodSectionsScreen> createState() => _PeriodSectionsScreenState();
}

class _PeriodSectionsScreenState extends State<PeriodSectionsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'period_sections';

  List<PeriodSection> _sections = [];
  bool _isLoading = true;

  // For the create bottom sheet
  DateTime? _nextStartMonth; // auto-filled
  DateTime? _selectedEndMonth;
  final _nameController = TextEditingController();
  bool _isSaving = false;

  static const List<Color> _sectionColors = [
    Color(0xFF4F8EF7),
    Color(0xFF34C759),
    Color(0xFF9B59B6),
    Color(0xFFFF9500),
    Color(0xFFFF3B30),
    Color(0xFF00BCD4),
    Color(0xFFFF6B6B),
    Color(0xFF795548),
  ];

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadSections() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _db
          .collection(_collection)
          .orderBy('sectionNumber')
          .get();
      setState(() {
        _sections = snap.docs
            .map((d) => PeriodSection.fromMap(d.id, d.data()))
            .toList();
      });
    } catch (e) {
      _showMsg('Error loading sections: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Next start month ──────────────────────────────────────────────────────
  DateTime get _autoNextStart {
    if (_sections.isEmpty) {
      // Default: January of current year
      final now = DateTime.now();
      return DateTime(now.year, 1, 1);
    }
    final last = _sections.last.endDate;
    // Start = month after last end month
    if (last.month == 12) return DateTime(last.year + 1, 1, 1);
    return DateTime(last.year, last.month + 1, 1);
  }

  // ── Save section ──────────────────────────────────────────────────────────
  Future<void> _saveSection() async {
    if (_selectedEndMonth == null) {
      _showMsg('Please select the end month', Colors.orange);
      return;
    }

    final start = _nextStartMonth!;
    final end = _selectedEndMonth!;

    // Validate: end must be >= start
    if (end.isBefore(start)) {
      _showMsg('End month must be after start month', Colors.orange);
      return;
    }

    // End date = last day of end month
    final endDate = DateTime(end.year, end.month + 1, 0);
    final startDate = DateTime(start.year, start.month, 1);

    final sectionNumber = _sections.length + 1;
    final name = _nameController.text.trim().isEmpty
        ? 'Section $sectionNumber'
        : _nameController.text.trim();

    setState(() => _isSaving = true);
    try {
      final doc = await _db.collection(_collection).add(
            PeriodSection(
              name: name,
              startDate: startDate,
              endDate: endDate,
              sectionNumber: sectionNumber,
              createdAt: DateTime.now(),
            ).toMap(),
          );

      final newSection = PeriodSection(
        id: doc.id,
        name: name,
        startDate: startDate,
        endDate: endDate,
        sectionNumber: sectionNumber,
        createdAt: DateTime.now(),
      );

      setState(() {
        _sections.add(newSection);
        _selectedEndMonth = null;
        _nameController.clear();
      });

      if (mounted) Navigator.pop(context); // close bottom sheet
      _showMsg('Section created successfully!', Colors.green);
    } catch (e) {
      _showMsg('Error saving section: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Delete latest section only ────────────────────────────────────────────
  Future<void> _deleteLatest() async {
    if (_sections.isEmpty) return;
    final latest = _sections.last;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text(
            'Delete "${latest.name}" (${latest.displayRange})?\n\nOnly the latest section can be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.collection(_collection).doc(latest.id).delete();
        setState(() => _sections.removeLast());
        _showMsg('Section deleted', Colors.green);
      } catch (e) {
        _showMsg('Error deleting: $e', Colors.red);
      }
    }
  }

  // ── Month picker helper ───────────────────────────────────────────────────
  Future<DateTime?> _pickMonth(BuildContext context,
      {DateTime? initial, DateTime? firstAllowed}) async {
    DateTime current = initial ?? firstAllowed ?? DateTime.now();

    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(
        initial: current,
        firstAllowed: firstAllowed,
      ),
    );
  }

  // ── Create bottom sheet ───────────────────────────────────────────────────
  void _showCreateSheet() {
    _nextStartMonth = _autoNextStart;
    _selectedEndMonth = null;
    _nameController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F8EF7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_chart_outlined,
                          color: Color(0xFF4F8EF7), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Create New Section',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(
                          'Section ${_sections.length + 1}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section name (optional)
                const Text('Section Name (optional)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Q1 2026  (default: Section ${_sections.length + 1})',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // Start month (read-only / auto)
                const Text('Start Month',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM yyyy').format(_nextStartMonth!),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        _sections.isEmpty
                            ? 'Default start'
                            : 'Auto from last section',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // End month (user picks)
                const Text('End Month',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickMonth(ctx,
                        initial: _selectedEndMonth ?? _nextStartMonth,
                        firstAllowed: _nextStartMonth);
                    if (picked != null) {
                      setSheetState(() => _selectedEndMonth = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: _selectedEndMonth != null
                          ? const Color(0xFF4F8EF7).withOpacity(0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedEndMonth != null
                            ? const Color(0xFF4F8EF7)
                            : Colors.grey.shade300,
                        width: _selectedEndMonth != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 18,
                            color: _selectedEndMonth != null
                                ? const Color(0xFF4F8EF7)
                                : Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text(
                          _selectedEndMonth != null
                              ? DateFormat('MMMM yyyy')
                                  .format(_selectedEndMonth!)
                              : 'Tap to select end month',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: _selectedEndMonth != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _selectedEndMonth != null
                                ? Colors.black87
                                : Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),

                // Range preview
                if (_selectedEndMonth != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM yyyy').format(_nextStartMonth!)} – ${DateFormat('MMM yyyy').format(_selectedEndMonth!)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800),
                        ),
                        const Spacer(),
                        Text(
                          '${_monthsBetween(_nextStartMonth!, _selectedEndMonth!)} month${_monthsBetween(_nextStartMonth!, _selectedEndMonth!) == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _saveSection();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F8EF7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white)))
                        : const Text('Create Section',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + to.month - from.month + 1;

  void _showMsg(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Period Sections',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          if (_sections.isNotEmpty)
            IconButton(
              onPressed: _deleteLatest,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete latest section',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? _buildEmptyState()
              : _buildSectionList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: const Color(0xFF4F8EF7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Section',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4F8EF7).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.date_range_outlined,
                size: 52, color: Color(0xFF4F8EF7)),
          ),
          const SizedBox(height: 20),
          const Text('No sections yet',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Create your first period section\nto get started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateSheet,
            icon: const Icon(Icons.add),
            label: const Text('Create First Section'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F8EF7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F8EF7), Color(0xFF6A5AE0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8EF7).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overview',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryItem(
                      '${_sections.length}',
                      'Sections',
                      Icons.layers_outlined),
                  _summaryItem(
                      DateFormat('MMM yyyy')
                          .format(_sections.first.startDate),
                      'From',
                      Icons.play_arrow_outlined),
                  _summaryItem(
                      DateFormat('MMM yyyy')
                          .format(_sections.last.endDate),
                      'To',
                      Icons.stop_outlined),
                  _summaryItem(
                      '${_sections.fold<int>(0, (s, sec) => s + sec.monthCount)}',
                      'Months',
                      Icons.calendar_today_outlined),
                ],
              ),
            ],
          ),
        ),

        // Next section hint
        if (_sections.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Next section will start from ${DateFormat('MMMM yyyy').format(_autoNextStart)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],

        // Section cards
        ...List.generate(_sections.length, (i) {
          final section = _sections[i];
          final color =
              _sectionColors[i % _sectionColors.length];
          final isLatest = i == _sections.length - 1;

          return _buildSectionCard(
              section, color, isLatest, i);
        }),
      ],
    );
  }

  Widget _summaryItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildSectionCard(
      PeriodSection section, Color color, bool isLatest, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Color accent bar
          Container(
            width: 6,
            height: 90,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // Section number badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        '${section.sectionNumber}',
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                section.name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (isLatest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.green.shade200),
                                ),
                                child: Text(
                                  'Latest',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.date_range_outlined,
                                size: 13,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              section.displayRange,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.timelapse_outlined,
                                size: 13,
                                color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              '${section.monthCount} month${section.monthCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.lock_outline,
                                size: 12,
                                color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(
                              'Locked',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Delete icon — only latest
                  if (isLatest)
                    IconButton(
                      onPressed: _deleteLatest,
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red.shade400, size: 20),
                      tooltip: 'Delete this section',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;
  final DateTime? firstAllowed;

  const _MonthPickerDialog({required this.initial, this.firstAllowed});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _selectedMonth;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _selectedMonth = widget.initial.month;
  }

  bool _isAllowed(int month) {
    if (widget.firstAllowed == null) return true;
    final d = DateTime(_year, month, 1);
    return !d.isBefore(DateTime(
        widget.firstAllowed!.year, widget.firstAllowed!.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Month grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
              children: List.generate(12, (i) {
                final month = i + 1;
                final isSelected =
                    _selectedMonth == month;
                final allowed = _isAllowed(month);

                return GestureDetector(
                  onTap: allowed
                      ? () => setState(() => _selectedMonth = month)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4F8EF7)
                          : allowed
                              ? Colors.grey.shade100
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey.shade200),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _months[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : allowed
                                ? Colors.black87
                                : Colors.grey.shade400,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Confirm
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isAllowed(_selectedMonth)
                      ? () => Navigator.pop(
                          context, DateTime(_year, _selectedMonth, 1))
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F8EF7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Select'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}