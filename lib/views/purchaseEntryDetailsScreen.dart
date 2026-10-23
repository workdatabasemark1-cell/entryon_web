import 'package:entryon/models/purchase_entry_model.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class PurchaseEntryDetailsScreen extends StatefulWidget {
  final PurchaseInvoice invoice;
  final VoidCallback? onDelete;
  final void Function(List<PurchaseItem>)? onExportPdf;
  final void Function(List<PurchaseItem>)? onExportExcel;
  final VoidCallback? onEdit;

  const PurchaseEntryDetailsScreen({
    super.key,
    required this.invoice,
    this.onDelete,
    this.onExportPdf,
    this.onExportExcel,
    this.onEdit,
  });

  @override
  State<PurchaseEntryDetailsScreen> createState() =>
      _PurchaseEntryDetailsScreenState();
}

class _PurchaseEntryDetailsScreenState
    extends State<PurchaseEntryDetailsScreen> {
  DateTime? _itemFilterFrom;
  DateTime? _itemFilterTo;
  String _supplierFilter = '';
  String _sortBy = 'created_asc';
  late final TextEditingController _supplierController;
  final _itemsVerticalController = ScrollController();
  final _itemsHorizontalController = ScrollController();
  late List<PurchaseItem> _filteredInvoiceItems;

  @override
  void initState() {
    super.initState();
    _supplierController = TextEditingController();
    _filteredInvoiceItems = List.from(widget.invoice.items);
    _sortFilteredItems();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _itemsVerticalController.dispose();
    _itemsHorizontalController.dispose();
    super.dispose();
  }

  void _applyInvoiceItemFilters() {
    final supplierQuery = _supplierFilter.trim().toLowerCase();
    final baseItems = widget.invoice.items.where((item) {
      final matchesSupplier =
          supplierQuery.isEmpty ||
          item.supplierName.toLowerCase().contains(supplierQuery);
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      final fromDate = _itemFilterFrom != null
          ? DateTime(
              _itemFilterFrom!.year,
              _itemFilterFrom!.month,
              _itemFilterFrom!.day,
            )
          : null;
      final toDate = _itemFilterTo != null
          ? DateTime(
              _itemFilterTo!.year,
              _itemFilterTo!.month,
              _itemFilterTo!.day,
            )
          : null;

      final afterFrom = fromDate == null || !itemDate.isBefore(fromDate);
      final beforeTo = toDate == null || !itemDate.isAfter(toDate);

      return matchesSupplier && afterFrom && beforeTo;
    }).toList();

    setState(() {
      _filteredInvoiceItems = List.from(baseItems);
      _sortFilteredItems();
    });
  }

  void _sortFilteredItems() {
    _filteredInvoiceItems.sort((a, b) {
      switch (_sortBy) {
        case 'created_asc':
          return a.createdAt.compareTo(b.createdAt);
        case 'created_desc':
          return b.createdAt.compareTo(a.createdAt);
        case 'supplier_asc':
          return a.supplierName.toLowerCase().compareTo(
            b.supplierName.toLowerCase(),
          );
        case 'supplier_desc':
          return b.supplierName.toLowerCase().compareTo(
            a.supplierName.toLowerCase(),
          );
        case 'amount_asc':
          return a.totalIncVat.compareTo(b.totalIncVat);
        case 'amount_desc':
          return b.totalIncVat.compareTo(a.totalIncVat);
        default:
          return a.createdAt.compareTo(b.createdAt);
      }
    });
  }

  bool get _hasActiveFilters =>
      _itemFilterFrom != null ||
      _itemFilterTo != null ||
      _supplierFilter.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _itemFilterFrom = null;
      _itemFilterTo = null;
      _supplierFilter = '';
      _supplierController.clear();
      _filteredInvoiceItems = List.from(widget.invoice.items);
      _sortFilteredItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isDesktop = context.isDesktop;

    final totalExcl = _filteredInvoiceItems.fold<double>(
      0,
      (total, item) => total + item.amountExVat,
    );
    final totalVat = _filteredInvoiceItems.fold<double>(
      0,
      (total, item) => total + item.vatAmount,
    );
    final totalInc = _filteredInvoiceItems.fold<double>(
      0,
      (total, item) => total + item.totalIncVat,
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 52,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Invoice Details',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            if (widget.invoice.invoiceNo.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.invoice.invoiceNo,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent(context),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isMobile) ...[
            _buildExportPdfButton(),
            const SizedBox(width: 8),
            _buildExportExcelButton(),
            const SizedBox(width: 8),
            _buildEditButton(),
            const SizedBox(width: 8),
            _buildDeleteButton(),
            const SizedBox(width: 12),
          ] else ...[
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.textPrimary(context)),
              color: AppTheme.surfaceBg(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.cardBorderColor(context)),
              ),
              onSelected: (val) {
                if (val == 'pdf') {
                  widget.onExportPdf?.call(_filteredInvoiceItems);
                } else if (val == 'excel') {
                  widget.onExportExcel?.call(_filteredInvoiceItems);
                } else if (val == 'edit') {
                  widget.onEdit?.call();
                } else if (val == 'delete') {
                  widget.onDelete?.call();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: const [
                      FaIcon(
                        FontAwesomeIcons.solidFilePdf,
                        color: Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 10),
                      Text('Export PDF'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'excel',
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.solidFileExcel,
                        color: Colors.green.shade700,
                        size: 16,
                      ),
                      SizedBox(width: 10),
                      const Text('Export Excel'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: const [
                      Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Invoice'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: const [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Delete Invoice',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Cards: Info & Filters ───────────────────────────────────
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildInfoCard(context)),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: _buildFiltersCard(context)),
                ],
              )
            else ...[
              _buildInfoCard(context),
              const SizedBox(height: 12),
              _buildFiltersCard(context),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 14),

            // ── KPI Totals Summary ──────────────────────────────────────────
            _buildTotalsKpiRow(context, totalExcl, totalVat, totalInc),

            const SizedBox(height: 14),

            // ── Line Items Container ────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header + Sort
                  Row(
                    children: [
                      Icon(
                        LucideIcons.listOrdered,
                        size: 16,
                        color: AppTheme.accent(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Line Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent(
                            context,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filteredInvoiceItems.length} items',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent(context),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Sort dropdown
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.inputBg(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.cardBorderColor(context),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isDense: true,
                            dropdownColor: AppTheme.surfaceBg(context),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'created_desc',
                                child: Text('Sort: Created Date Newest'),
                              ),
                              DropdownMenuItem(
                                value: 'created_asc',
                                child: Text('Sort: Created Date Oldest First'),
                              ),
                              DropdownMenuItem(
                                value: 'supplier_asc',
                                child: Text('Sort: Supplier A-Z'),
                              ),
                              DropdownMenuItem(
                                value: 'supplier_desc',
                                child: Text('Sort: Supplier Z-A'),
                              ),
                              DropdownMenuItem(
                                value: 'amount_desc',
                                child: Text('Sort: Amount High-Low'),
                              ),
                              DropdownMenuItem(
                                value: 'amount_asc',
                                child: Text('Sort: Amount Low-High'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _sortBy = value;
                                _sortFilteredItems();
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Line Items Data Table or Empty
                  if (_filteredInvoiceItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.receipt,
                              size: 36,
                              color: AppTheme.textSecondary(context),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No line items found matching filters',
                              style: TextStyle(
                                color: AppTheme.textSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildResponsiveItemsTable(
                      context,
                      totalExcl,
                      totalVat,
                      totalInc,
                    ),
                ],
              ),
            ),
            _buildLastAddedItemPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildLastAddedItemPreview() {
    final items = widget.invoice.items;
    if (items.isEmpty) return const SizedBox.shrink();

    var item = items.first;
    for (final candidate in items.skip(1)) {
      if (!candidate.createdAt.isBefore(item.createdAt)) {
        item = candidate;
      }
    }

    final accent = AppTheme.accent(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 15, color: accent),
              const SizedBox(width: 6),
              Text(
                'Last created entry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.invoiceNo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${item.supplierName}  •  ${DateFormat('dd/MM/yyyy').format(item.date)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Created: ${DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt)}  •  '
            'Ex VAT: ${item.amountExVat.toStringAsFixed(2)}  •  '
            'VAT: ${item.vatAmount.toStringAsFixed(2)}  •  '
            'Total: ${item.totalIncVat.toStringAsFixed(2)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info Card ─────────────────────────────────────────────────────────────
  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.fileText,
                size: 16,
                color: AppTheme.accent(context),
              ),
              const SizedBox(width: 6),
              Text(
                'Customer & Invoice Info',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              if (isNarrow) {
                return Column(
                  children: [
                    _infoTile('Customer', widget.invoice.customerName),
                    if (widget.invoice.customerVatNumber.isNotEmpty)
                      _infoTile('VAT Number', widget.invoice.customerVatNumber),
                    _infoTile(
                      'Invoice Date',
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(widget.invoice.invoiceDate),
                    ),
                    _infoTile(
                      'Created Date',
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(widget.invoice.createdAt),
                    ),
                    if (widget.invoice.periodSectionName.isNotEmpty)
                      _infoTile(
                        'Period Section',
                        widget.invoice.periodSectionName,
                      ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _infoTile('Customer', widget.invoice.customerName),
                        if (widget.invoice.customerVatNumber.isNotEmpty)
                          _infoTile(
                            'VAT Number',
                            widget.invoice.customerVatNumber,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _infoTile(
                          'Invoice Date',
                          DateFormat(
                            'dd MMM yyyy',
                          ).format(widget.invoice.invoiceDate),
                        ),
                        _infoTile(
                          'Created Date',
                          DateFormat(
                            'dd MMM yyyy',
                          ).format(widget.invoice.createdAt),
                        ),
                        if (widget.invoice.periodSectionName.isNotEmpty)
                          _infoTile(
                            'Period Section',
                            widget.invoice.periodSectionName,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Filters Card ──────────────────────────────────────────────────────────
  Widget _buildFiltersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.filter,
                    size: 16,
                    color: AppTheme.accent(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter Line Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(LucideIcons.rotateCcw, size: 12),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'From date',
                            date: _itemFilterFrom,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _itemFilterFrom ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _itemFilterFrom = picked;
                                  _applyInvoiceItemFilters();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDateField(
                            label: 'To date',
                            date: _itemFilterTo,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _itemFilterTo ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _itemFilterTo = picked;
                                  _applyInvoiceItemFilters();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSupplierSearchField(),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: _buildDateField(
                      label: 'From date',
                      date: _itemFilterFrom,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _itemFilterFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _itemFilterFrom = picked;
                            _applyInvoiceItemFilters();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    child: _buildDateField(
                      label: 'To date',
                      date: _itemFilterTo,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _itemFilterTo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _itemFilterTo = picked;
                            _applyInvoiceItemFilters();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSupplierSearchField()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.inputBg(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: date != null
                ? AppTheme.accent(context)
                : AppTheme.cardBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                date != null ? DateFormat('dd/MM/yyyy').format(date) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: date != null
                      ? AppTheme.textPrimary(context)
                      : AppTheme.textSecondary(context),
                  fontWeight: date != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              LucideIcons.calendar,
              size: 14,
              color: AppTheme.accent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSearchField() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _supplierController,
        style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary(context)),
        decoration: InputDecoration(
          hintText: 'Search supplier...',
          hintStyle: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 14,
            color: AppTheme.textSecondary(context),
          ),
          suffixIcon: _supplierController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    LucideIcons.x,
                    size: 13,
                    color: AppTheme.textSecondary(context),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _supplierController.clear();
                    setState(() {
                      _supplierFilter = '';
                      _applyInvoiceItemFilters();
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.inputBg(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.accent(context), width: 1.5),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _supplierFilter = value;
            _applyInvoiceItemFilters();
          });
        },
      ),
    );
  }

  // ── KPI Summary Row ───────────────────────────────────────────────────────
  Widget _buildTotalsKpiRow(
    BuildContext context,
    double totalExcl,
    double totalVat,
    double totalInc,
  ) {
    final isMobile = context.isMobile;

    final cards = [
      _buildMiniKpiCard(
        label: 'Amount (Ex-VAT)',
        value: 'SAR ${totalExcl.toStringAsFixed(2)}',
        icon: LucideIcons.calculator,
        color: const Color(0xFF3B82F6),
      ),
      _buildMiniKpiCard(
        label: 'Total VAT',
        value: 'SAR ${totalVat.toStringAsFixed(2)}',
        icon: LucideIcons.percent,
        color: const Color(0xFFF59E0B),
      ),
      _buildMiniKpiCard(
        label: 'Total (Inc-VAT)',
        value: 'SAR ${totalInc.toStringAsFixed(2)}',
        icon: LucideIcons.badgePercent,
        color: const Color(0xFF10B981),
      ),
      _buildMiniKpiCard(
        label: 'Items Count',
        value: '${_filteredInvoiceItems.length}',
        icon: LucideIcons.layers,
        color: AppTheme.accent(context),
      ),
    ];

    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemW = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map((c) => SizedBox(width: itemW, child: c))
                .toList(),
          );
        },
      );
    }

    return Row(
      children: cards
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMiniKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.2 : 0.02,
            ),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Line Items Table ──────────────────────────────────────────────────────
  Widget _buildResponsiveItemsTable(
    BuildContext context,
    double totalExcl,
    double totalVat,
    double totalInc,
  ) {
    final borderColor = AppTheme.cardBorderColor(context);

    final columns = <PlutoColumn>[
      PlutoColumn(
        title: 'SL',
        field: 'sl',
        type: PlutoColumnType.number(format: '#,##0'),
        width: 56,
        minWidth: 56,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableDropToResize: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Date',
        field: 'date',
        type: PlutoColumnType.text(),
        width: 100,
        minWidth: 100,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableDropToResize: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Created Date',
        field: 'createdDate',
        type: PlutoColumnType.text(),
        width: 140,
        minWidth: 130,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Supplier',
        field: 'supplier',
        type: PlutoColumnType.text(),
        width: 160,
        minWidth: 120,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'VAT No',
        field: 'vatNumber',
        type: PlutoColumnType.text(),
        width: 120,
        minWidth: 100,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Invoice No',
        field: 'invoiceNo',
        type: PlutoColumnType.text(),
        width: 150,
        minWidth: 120,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Amount (Ex)',
        field: 'amountExVat',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 110,
        minWidth: 100,
        textAlign: PlutoColumnTextAlign.right,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'VAT',
        field: 'vatAmount',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 100,
        minWidth: 90,
        textAlign: PlutoColumnTextAlign.right,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Total (Inc)',
        field: 'totalIncVat',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 120,
        minWidth: 110,
        textAlign: PlutoColumnTextAlign.right,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
    ];

    final rows = _filteredInvoiceItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return PlutoRow(
        cells: {
          'sl': PlutoCell(value: index + 1),
          'date': PlutoCell(value: DateFormat('dd/MM/yyyy').format(item.date)),
          'createdDate': PlutoCell(
            value: DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt),
          ),
          'supplier': PlutoCell(value: item.supplierName),
          'vatNumber': PlutoCell(
            value: item.vatNumber.isNotEmpty ? item.vatNumber : '—',
          ),
          'invoiceNo': PlutoCell(value: item.invoiceNo),
          'amountExVat': PlutoCell(value: item.amountExVat),
          'vatAmount': PlutoCell(value: item.vatAmount),
          'totalIncVat': PlutoCell(value: item.totalIncVat),
        },
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: context.isMobile ? 360 : 480,
          child: PlutoGrid(
            key: ValueKey(
              _filteredInvoiceItems
                  .map(
                    (item) =>
                        '${item.id}:${item.createdAt.microsecondsSinceEpoch}',
                  )
                  .join('|'),
            ),
            columns: columns,
            rows: rows,
            configuration: PlutoGridConfiguration(
              style: PlutoGridStyleConfig(
                gridBackgroundColor: AppTheme.cardBg(context),
                rowColor: AppTheme.cardBg(context),
                evenRowColor: AppTheme.cardBg(context),
                oddRowColor: AppTheme.scaffoldBg(context),
                activatedColor: AppTheme.accent(
                  context,
                ).withValues(alpha: 0.12),
                borderColor: borderColor,
                gridBorderColor: borderColor,
                columnHeight: 40,
                rowHeight: 40,
                columnTextStyle: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                cellTextStyle: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 12,
                ),
                gridBorderRadius: BorderRadius.circular(8),
              ),
              scrollbar: const PlutoGridScrollbarConfig(
                isAlwaysShown: true,
                draggableScrollbar: true,
              ),
            ),
          ),
        ),

        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        //   decoration: BoxDecoration(
        //     color: AppTheme.surfaceBg(context),
        //     border: Border.all(color: AppTheme.cardBorderColor(context)),
        //     borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        //   ),
        //   child: Row(
        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //     children: [
        //       Row(
        //         children: [
        //           Icon(LucideIcons.sigma,
        //               size: 15, color: AppTheme.accent(context)),
        //           const SizedBox(width: 6),
        //           Text(
        //             'Grand Total (${_filteredInvoiceItems.length} items)',
        //             style: TextStyle(
        //               fontSize: 12.5,
        //               fontWeight: FontWeight.bold,
        //               color: AppTheme.textPrimary(context),
        //             ),
        //           ),
        //         ],
        //       ),
        //       const SizedBox(width: 40),
        //       Row(
        //         children: [
        //           Text('Excl: ',
        //               style: TextStyle(
        //                   fontSize: 12,
        //                   color: AppTheme.textSecondary(context))),
        //           Text(totalExcl.toStringAsFixed(2),
        //               style: TextStyle(
        //                   fontSize: 12.5,
        //                   fontWeight: FontWeight.bold,
        //                   color: AppTheme.textPrimary(context))),
        //           const SizedBox(width: 16),
        //           Text('VAT: ',
        //               style: TextStyle(
        //                   fontSize: 12,
        //                   color: AppTheme.textSecondary(context))),
        //           Text(totalVat.toStringAsFixed(2),
        //               style: const TextStyle(
        //                   fontSize: 12.5,
        //                   fontWeight: FontWeight.bold,
        //                   color: Color(0xFFEAB308))),
        //           const SizedBox(width: 16),
        //           Text('Total: ',
        //               style: TextStyle(
        //                   fontSize: 12,
        //                   color: AppTheme.textSecondary(context))),
        //           Text('SAR ${totalInc.toStringAsFixed(2)}',
        //               style: TextStyle(
        //                   fontSize: 13.5,
        //                   fontWeight: FontWeight.w800,
        //                   color: AppTheme.accent(context))),
        //         ],
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  // ── Info Tile Helper ──────────────────────────────────────────────────────
  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────
  Widget _buildExportPdfButton() {
    return OutlinedButton.icon(
      onPressed: () => widget.onExportPdf?.call(_filteredInvoiceItems),
      icon: const FaIcon(
        FontAwesomeIcons.solidFilePdf,
        size: 14,
        color: Colors.red,
      ),
      label: const Text(
        'Export PDF',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red, width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildExportExcelButton() {
    return OutlinedButton.icon(
      onPressed: () => widget.onExportExcel?.call(_filteredInvoiceItems),
      icon: FaIcon(
        FontAwesomeIcons.solidFileExcel,
        size: 14,
        color: Colors.green.shade700,
      ),
      label: Text(
        'Export Excel',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.green.shade700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        side: BorderSide(color: Colors.green.shade700, width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildEditButton() {
    return ElevatedButton.icon(
      onPressed: widget.onEdit,
      icon: const Icon(Icons.edit, size: 15),
      label: const Text(
        'Edit Invoice',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  Widget _buildDeleteButton() {
    return ElevatedButton.icon(
      onPressed: widget.onDelete,
      icon: const Icon(Icons.delete_outline, size: 15),
      label: const Text(
        'Delete',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }
}
