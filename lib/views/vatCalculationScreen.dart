import 'package:flutter/material.dart';
import 'package:entryon/utils/app_theme.dart';

class VatCalculationScreen extends StatefulWidget {
  const VatCalculationScreen({super.key});

  @override
  State<VatCalculationScreen> createState() => _VatCalculationScreenState();
}

class _VatCalculationScreenState extends State<VatCalculationScreen> {
  // Which field is currently active
  int _activeField = 0; // 0=priceEx, 1=vatAmount, 2=priceInc, 3=vatRate

  // Raw string values for each field
  final List<String> _values = ['', '', '', ''];

  // Labels and icons for each field
  final List<String> _labels = [
    'Price (Excl. VAT)',
    'VAT Amount',
    'Price (Incl. VAT)',
    'VAT Rate (%)',
  ];

  final List<IconData> _icons = [
    Icons.price_change_outlined,
    Icons.percent_rounded,
    Icons.attach_money_rounded,
    Icons.calculate_outlined,
  ];

  final List<Color> _fieldColors = [
    const Color(0xFF4F8EF7),
    const Color(0xFF34C759),
    const Color(0xFF9B59B6),
    const Color(0xFFFF9500),
  ];

  double get _priceEx => double.tryParse(_values[0]) ?? 0.0;
  double get _vatAmount => double.tryParse(_values[1]) ?? 0.0;
  double get _priceInc => double.tryParse(_values[2]) ?? 0.0;
  double get _vatRate => double.tryParse(_values[3]) ?? 0.0;

  void _onKeyTap(String key) {
    setState(() {
      if (key == 'C') {
        // Clear active field
        _values[_activeField] = '';
        _recalculate();
        return;
      }

      if (key == '⌫') {
        if (_values[_activeField].isNotEmpty) {
          _values[_activeField] =
              _values[_activeField].substring(0, _values[_activeField].length - 1);
          _recalculate();
        }
        return;
      }

      if (key == '.') {
        if (_values[_activeField].contains('.')) return;
        if (_values[_activeField].isEmpty) {
          _values[_activeField] = '0.';
        } else {
          _values[_activeField] += '.';
        }
        return;
      }

      // Digit
      _values[_activeField] += key;
      _recalculate();
    });
  }

  void _recalculate() {
    final vatRate = _vatRate;
    if (vatRate <= 0) return;

    switch (_activeField) {
      case 0: // Price Ex → compute VAT Amount & Price Inc
        final vatAmt = _priceEx * (vatRate / 100);
        _values[1] = _fmt(vatAmt);
        _values[2] = _fmt(_priceEx + vatAmt);
        break;
      case 1: // VAT Amount → compute Price Ex & Price Inc
        final priceEx = _vatAmount / (vatRate / 100);
        _values[0] = _fmt(priceEx);
        _values[2] = _fmt(priceEx + _vatAmount);
        break;
      case 2: // Price Inc → compute Price Ex & VAT Amount
        final priceEx = _priceInc / (1 + vatRate / 100);
        _values[0] = _fmt(priceEx);
        _values[1] = _fmt(_priceInc - priceEx);
        break;
      case 3: // VAT Rate changed → recalculate from Price Ex
        if (_priceEx > 0) {
          final vatAmt = _priceEx * (vatRate / 100);
          _values[1] = _fmt(vatAmt);
          _values[2] = _fmt(_priceEx + vatAmt);
        }
        break;
    }
  }

  String _fmt(double v) {
    if (v == 0) return '';
    final s = v.toStringAsFixed(2);
    // Remove trailing zeros after decimal
    return s;
  }

  void _clearAll() {
    setState(() {
      for (int i = 0; i < _values.length; i++) {
        _values[i] = '';
      }
    });
  }

  String _displayValue(int index) {
    if (_values[index].isEmpty) return '0.00';
    final d = double.tryParse(_values[index]);
    if (d != null && !_values[index].endsWith('.')) {
      return d.toStringAsFixed(2);
    }
    return _values[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'VAT Calculator',
          style: TextStyle(
            color: AppTheme.textPrimary(context),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          InkWell(
            onTap: _clearAll,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: AppTheme.cardBg(context),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
              ),
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: isDark ? FuturisticColors.neonCyan : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Field Cards ──────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    // Field tiles
                    ...List.generate(4, (i) => _buildFieldTile(i)),
                    const SizedBox(height: 0),
          
                    // Summary card
                    _buildSummaryCard(),
                  ],
                ),
              ),
          
              // ── Custom Keypad ─────────────────────────────────────────────
              _buildKeypad(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldTile(int index) {
    final isDark = AppTheme.isDark(context);
    final isActive = _activeField == index;
    final color = _fieldColors[index];

    return GestureDetector(
      onTap: () => setState(() => _activeField = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : AppTheme.cardBorderColor(context),
            width: isActive ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? color.withValues(alpha: isDark ? 0.25 : 0.18)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: isActive ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icons[index], color: color, size: 20),
            ),
            const SizedBox(width: 14),

            // Label & value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labels[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _displayValue(index),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isActive ? color : AppTheme.textPrimary(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      // Blinking cursor when active
                      if (isActive) ...[
                        const SizedBox(width: 2),
                        _BlinkingCursor(color: color),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Active indicator
            AnimatedOpacity(
              opacity: isActive ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final isDark = AppTheme.isDark(context);
    final hasData = _priceEx > 0 || _vatAmount > 0 || _priceInc > 0;

    return AnimatedOpacity(
      opacity: hasData ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Excl. VAT',
                _values[0].isEmpty ? '0.00' : _displayValue(0),
                AppTheme.textPrimary(context),
              ),
            ),
            Container(width: 1, height: 36, color: AppTheme.divider(context)),
            Expanded(
              child: _buildSummaryItem(
                'VAT ${_vatRate > 0 ? "(${_vatRate.toStringAsFixed(0)}%)" : ""}',
                _values[1].isEmpty ? '0.00' : _displayValue(1),
                isDark ? FuturisticColors.neonTeal : const Color(0xFF34C759),
              ),
            ),
            Container(width: 1, height: 36, color: AppTheme.divider(context)),
            Expanded(
              child: _buildSummaryItem(
                'Total',
                _values[2].isEmpty ? '0.00' : _displayValue(2),
                isDark ? FuturisticColors.neonCyan : const Color(0xFF4F8EF7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Custom Keypad ──────────────────────────────────────────────────────
  Widget _buildKeypad() {
    final isDark = AppTheme.isDark(context);
    final keys = [
      ['7', '8', '9', 'C'],
      ['4', '5', '6', '⌫'],
      ['1', '2', '3', ''],
      ['', '0', '.', ''],
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.cardBorderColor(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active field indicator strip
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _fieldColors[_activeField].withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icons[_activeField],
                  size: 16,
                  color: _fieldColors[_activeField],
                ),
                const SizedBox(width: 6),
                Text(
                  'Editing: ${_labels[_activeField]}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _fieldColors[_activeField],
                  ),
                ),
              ],
            ),
          ),

          // Key rows
          ...keys.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: row.map((key) {
                  if (key.isEmpty) {
                    return const Expanded(child: SizedBox());
                  }
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildKey(key),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKey(String key) {
    final isDark = AppTheme.isDark(context);
    final isDot = key == '.';

    Color bgColor;
    Color textColor;
    FontWeight weight;

    if (key == 'C') {
      bgColor = isDark ? FuturisticColors.neonCrimson.withValues(alpha: 0.15) : Colors.red.shade50;
      textColor = isDark ? FuturisticColors.neonCrimson : Colors.red.shade600;
      weight = FontWeight.w700;
    } else if (key == '⌫') {
      bgColor = isDark ? FuturisticColors.neonAmber.withValues(alpha: 0.15) : Colors.orange.shade50;
      textColor = isDark ? FuturisticColors.neonAmber : Colors.orange.shade700;
      weight = FontWeight.w700;
    } else if (isDot) {
      bgColor = isDark ? FuturisticColors.bgElevated : Colors.grey.shade100;
      textColor = AppTheme.textPrimary(context);
      weight = FontWeight.w800;
    } else {
      bgColor = isDark ? FuturisticColors.bgCardHover : const Color(0xFFF5F7FA);
      textColor = AppTheme.textPrimary(context);
      weight = FontWeight.w600;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onKeyTap(key),
        splashColor: _fieldColors[_activeField].withValues(alpha: 0.15),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: key == '⌫'
              ? Icon(Icons.backspace_outlined,
                  color: isDark ? FuturisticColors.neonAmber : Colors.orange.shade700, size: 20)
              : Text(
                  key,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: weight,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Blinking cursor widget ─────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}