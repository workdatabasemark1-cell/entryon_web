import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'pdf_download.dart';

/// Shows a premium bottom-sheet action menu for any generated PDF [bytes].
/// Offers Preview/Print, Download, and Share options.
Future<void> showPdfActionsSheet({
  required BuildContext context,
  required Uint8List bytes,
  required String filename,
}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _PdfActionsSheet(bytes: bytes, filename: filename),
  );
}

class _PdfActionsSheet extends StatefulWidget {
  final Uint8List bytes;
  final String filename;
  const _PdfActionsSheet({required this.bytes, required this.filename});

  @override
  State<_PdfActionsSheet> createState() => _PdfActionsSheetState();
}

class _PdfActionsSheetState extends State<_PdfActionsSheet> {
  bool _loadingPrint = false;
  bool _loadingDownload = false;
  bool _loadingShare = false;

  Future<void> _onPrint() async {
    setState(() => _loadingPrint = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => widget.bytes,
        name: widget.filename,
      );
    } catch (e) {
      if (mounted) _showErr('Print failed: $e');
    } finally {
      if (mounted) setState(() => _loadingPrint = false);
    }
  }

  Future<void> _onDownload() async {
    setState(() => _loadingDownload = true);
    try {
      await downloadPdf(widget.bytes, widget.filename);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('PDF saved successfully'),
            ]),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErr('Download failed: $e');
    } finally {
      if (mounted) setState(() => _loadingDownload = false);
    }
  }

  Future<void> _onShare() async {
    setState(() => _loadingShare = true);
    try {
      if (kIsWeb) {
        await downloadPdf(widget.bytes, widget.filename);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF downloaded. Attach it manually in WhatsApp.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      await Printing.sharePdf(
        bytes: widget.bytes,
        filename: widget.filename,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showErr('Share failed: $e');
    } finally {
      if (mounted) setState(() => _loadingShare = false);
    }
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: Color(0xFF0D9488), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PDF Ready',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(widget.filename,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Actions
          _ActionTile(
            icon: Icons.print_rounded,
            iconColor: const Color(0xFF6366F1),
            iconBg: const Color(0xFFEEF2FF),
            label: 'Preview & Print',
            sublabel: 'Open print preview dialog',
            loading: _loadingPrint,
            onTap: _onPrint,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.download_rounded,
            iconColor: const Color(0xFF0D9488),
            iconBg: const Color(0xFFF0FDFA),
            label: 'Download PDF',
            sublabel: 'Save PDF file to your device',
            loading: _loadingDownload,
            onTap: _onDownload,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.share_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFECFDF5),
            label: 'Share PDF',
            sublabel: 'Send via WhatsApp, email, drive & more',
            loading: _loadingShare,
            onTap: _onShare,
          ),
          const SizedBox(height: 12),
          // Cancel
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: const Color(0xFF64748B),
                backgroundColor: const Color(0xFFF8FAFC),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String sublabel;
  final bool loading;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.sublabel,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 1),
                    Text(sublabel,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0D9488)),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
