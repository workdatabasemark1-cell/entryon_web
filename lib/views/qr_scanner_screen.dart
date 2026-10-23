import 'package:entryon/utils/app_theme.dart';
import 'package:entryon/utils/zatca_qr_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _error;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus so the gun can type immediately without clicking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _processInput(String value) {
    if (_isProcessing) return;
    final raw = value.trim();
    if (raw.isEmpty) return;

    _isProcessing = true;
    final data = ZatcaQrParser.parse(raw);
    if (data == null) {
      setState(() {
        _error = 'Not a valid ZATCA QR code. Please try again.';
        _controller.clear();
        _focusNode.requestFocus();
        _isProcessing = false;
      });
      return;
    }

    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final primaryAccent = isDark
        ? FuturisticColors.neonCyan
        : Colors.blue.shade700;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('Scan ZATCA Invoice QR'),
        backgroundColor: AppTheme.surfaceBg(context),
        foregroundColor: AppTheme.textPrimary(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 40,
                  color: primaryAccent,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Ready to Scan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Point the gun scanner at the QR code\non the Saudi e-invoice',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 32),

              // Hidden field that receives gun scanner input
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.tab) {
                    _processInput(_controller.text);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmitted: _processInput, // fires on Enter too
                  autofocus: true,
                  style: TextStyle(color: AppTheme.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Waiting for scanner...',
                    hintStyle: TextStyle(color: AppTheme.textMuted(context)),
                    prefixIcon: Icon(
                      Icons.sensors,
                      color: isDark
                          ? FuturisticColors.neonCyan
                          : Colors.blue.shade400,
                    ),
                    filled: true,
                    fillColor: AppTheme.inputBg(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorderColor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorderColor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primaryAccent, width: 2),
                    ),
                  ),
                ),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? FuturisticColors.neonCrimson : Colors.red)
                        .withValues(alpha: 0.12),
                    border: Border.all(
                      color:
                          (isDark ? FuturisticColors.neonCrimson : Colors.red)
                              .withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: isDark
                            ? FuturisticColors.neonCrimson
                            : Colors.red.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: isDark
                                ? FuturisticColors.neonCrimson
                                : Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary(context),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
