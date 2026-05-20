import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/customer_provider.dart';
import 'providers/supplier_provider.dart';
import 'models/customer_model.dart';
import 'models/supplier_model.dart';
import 'createCustomerScreen.dart';
import 'createSupplierScreen.dart';

import 'editSupplierScreen.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController customerSearch = TextEditingController();
  final TextEditingController supplierSearch = TextEditingController();

  List<Customer> filteredCustomers = [];
  List<Supplier> filteredSuppliers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
      context.read<SupplierProvider>().fetchSuppliers();
    });
  }

  @override
  void dispose() {
    customerSearch.dispose();
    supplierSearch.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  void filterCustomers(String query) {
    final list = context.read<CustomerProvider>().customers;
    setState(() {
      filteredCustomers = query.isEmpty
          ? list
          : list
              .where((c) =>
                  c.name.toLowerCase().contains(query.toLowerCase()) ||
                  c.phone.contains(query) ||
                  c.taxNumber.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  void filterSuppliers(String query) {
    final list = context.read<SupplierProvider>().suppliers;
    setState(() {
      filteredSuppliers = query.isEmpty
          ? list
          : list
              .where((s) =>
                  s.name.toLowerCase().contains(query.toLowerCase()) ||
                  s.phone.contains(query) ||
                  s.vatNumber.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  // ── Delete Customer ───────────────────────────────────────────────────────

  void deleteCustomer(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(backgroundColor: Colors.white,
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<CustomerProvider>().deleteCustomer(id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Customer deleted successfully')),
              );
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Delete Supplier ───────────────────────────────────────────────────────

  void deleteSupplier(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text('Are you sure you want to delete this supplier?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<SupplierProvider>().deleteSupplier(id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Supplier deleted successfully')),
              );
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Customers & Suppliers',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black),
        ),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Pill TabBar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(50),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black38,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Customers'),
                  Tab(text: 'Suppliers'),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _customersTab(),
                _suppliersTab(),
              ],
            ),
          ),
        ],
      ),

      // FAB — Add Supplier on tab 1, Add Customer on tab 0
      // floatingActionButton: _tabController.index == 1
      //     ? FloatingActionButton.extended(
      //         backgroundColor: Colors.green.shade700,
      //         icon: const Icon(Icons.add),
      //         label: const Text('Add Supplier'),
      //         onPressed: () {
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(
      //                 builder: (_) => const CreateSupplierScreen()),
      //           ).then(
      //               (_) => context.read<SupplierProvider>().fetchSuppliers());
      //         },
      //       )
      //     : null,
    );
  }

  // ── Customers Tab ─────────────────────────────────────────────────────────

  Widget _customersTab() {
    return Column(
      children: [
        _searchBar(
          controller: customerSearch,
          hint: 'Search by name, phone, or tax number...',
          onChanged: filterCustomers,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<CustomerProvider>().fetchCustomers(),
            child: Selector<CustomerProvider, List<Customer>>(
              selector: (_, p) => p.customers,
              builder: (_, customers, __) {
                final list = customerSearch.text.isEmpty
                    ? customers
                    : filteredCustomers;

                if (customers.isEmpty) {
                  return _emptyState(
                    icon: Icons.people_outline,
                    text: 'No customers found',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _CustomerCard(
                    customer: list[i],
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateCustomerScreen(customer: list[i]),
                      ),
                    ).then((_) =>
                        context.read<CustomerProvider>().fetchCustomers()),
                    onDelete: () => deleteCustomer(list[i].id),
                  ),
                );
              },
            ),
          ),
        ),

        // ── Add Customer button ──────────────────────────────────────────
        _addButton(
          label: 'Create Customer',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCustomerScreen()),
          ).then((_) => context.read<CustomerProvider>().fetchCustomers()),
        ),
      ],
    );
  }

  // ── Suppliers Tab ─────────────────────────────────────────────────────────

  Widget _suppliersTab() {
    return Column(
      children: [
        _searchBar(
          controller: supplierSearch,
          hint: 'Search by name, phone, or VAT number...',
          onChanged: filterSuppliers,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<SupplierProvider>().fetchSuppliers(),
            child: Selector<SupplierProvider, List<Supplier>>(
              selector: (_, p) => p.suppliers,
              builder: (_, suppliers, __) {
                final list = supplierSearch.text.isEmpty
                    ? suppliers
                    : filteredSuppliers;

                if (suppliers.isEmpty) {
                  return _emptyState(
                    icon: Icons.store_outlined,
                    text: 'No suppliers found',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _SupplierCard(
                    supplier: list[i],
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditSupplierScreen(supplier: list[i]),
                      ),
                    ).then((_) =>
                        context.read<SupplierProvider>().fetchSuppliers()),
                    onDelete: () => deleteSupplier(list[i].id!),
                  ),
                );
              },
            ),
          ),
        ),

        // ── Add Supplier button ──────────────────────────────────────────
        _addButton(
          label: 'Create Supplier',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateSupplierScreen()),
          ).then((_) => context.read<SupplierProvider>().fetchSuppliers()),
        ),
      ],
    );
  }

  // ── Shared Reusable Widgets ───────────────────────────────────────────────

  Widget _searchBar({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            contentPadding: EdgeInsets.zero,
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _addButton({required String label, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String text}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(text,
              style:
                  TextStyle(fontSize: 18, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Card
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerCard extends StatefulWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotateAnim =
        Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    
    List<_CardInfoRow> infoRows = [
      _CardInfoRow(icon: Icons.phone_outlined, label: 'Phone 1', value: c.phone),
      if (c.phone2?.isNotEmpty ?? false)
        _CardInfoRow(icon: Icons.phone_outlined, label: 'Phone 2', value: c.phone2!),
      if (c.email?.isNotEmpty ?? false)
        _CardInfoRow(icon: Icons.email_outlined, label: 'Email', value: c.email!),
      _CardInfoRow(icon: Icons.location_on_outlined, label: 'Address', value: c.address),
      if (c.cityName?.isNotEmpty ?? false)
        _CardInfoRow(icon: Icons.location_city_outlined, label: 'City', value: c.cityName!),
      if (c.organizationName?.isNotEmpty ?? false)
        _CardInfoRow(icon: Icons.business_outlined, label: 'Organization', value: c.organizationName!),
      if (c.periodSectionName?.isNotEmpty ?? false)
        _CardInfoRow(icon: Icons.calendar_today_outlined, label: 'Period', value: c.periodSectionName!),
      _CardInfoRow(icon: Icons.receipt_long_outlined, label: 'VAT Number', value: c.taxNumber),
      if (c.crNumber?.isNotEmpty ?? false)
        _CardInfoRow(icon: Icons.assignment_outlined, label: 'CR Number', value: c.crNumber!),
    ];
    
    return _AnimatedCard(
      avatarLetter: c.name[0].toUpperCase(),
      avatarColor: Colors.blue.shade700,
      title: c.name,
      subtitle: c.phone,
      expandAnim: _expandAnim,
      rotateAnim: _rotateAnim,
      onToggle: _toggle,
      infoRows: infoRows,
      editColor: Colors.blue.shade700,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supplier Card  (same style as Customer Card)
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierCard extends StatefulWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SupplierCard> createState() => _SupplierCardState();
}

class _SupplierCardState extends State<_SupplierCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotateAnim =
        Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.supplier;
    
    List<_CardInfoRow> infoRows = [
      _CardInfoRow(icon: Icons.phone_outlined, label: 'Phone 1', value: s.phone),
      _CardInfoRow(icon: Icons.location_on_outlined, label: 'Address', value: s.address ?? 'Not specified'),
      _CardInfoRow(icon: Icons.numbers_outlined, label: 'VAT Number', value: s.vatNumber),
    ];
    
    return _AnimatedCard(
      avatarLetter: s.name[0].toUpperCase(),
      avatarColor: Colors.green.shade700,
      title: s.name,
      subtitle: s.phone,
      expandAnim: _expandAnim,
      rotateAnim: _rotateAnim,
      onToggle: _toggle,
      infoRows: infoRows,
      editColor: Colors.green.shade700,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared animated card shell — used by both Customer & Supplier cards
// ─────────────────────────────────────────────────────────────────────────────

class _CardInfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _CardInfoRow(
      {required this.icon, required this.label, required this.value});
}

class _AnimatedCard extends StatelessWidget {
  final String avatarLetter;
  final Color avatarColor;
  final String title;
  final String subtitle;
  final Animation<double> expandAnim;
  final Animation<double> rotateAnim;
  final VoidCallback onToggle;
  final List<_CardInfoRow> infoRows;
  final Color editColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedCard({
    required this.avatarLetter,
    required this.avatarColor,
    required this.title,
    required this.subtitle,
    required this.expandAnim,
    required this.rotateAnim,
    required this.onToggle,
    required this.infoRows,
    required this.editColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: avatarColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Text(
                          avatarLetter,
                          style: TextStyle(
                            color: avatarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),

                    // Chevron
                    RotationTransition(
                      turns: rotateAnim,
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade400, size: 22),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expandable body ────────────────────────────────────────
            SizeTransition(
              sizeFactor: expandAnim,
              axisAlignment: -1,
              child: Column(
                children: [
                  Divider(height: 1, color: Colors.grey.shade100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info rows
                        ...infoRows.map((row) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(row.icon,
                                      size: 16,
                                      color: Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${row.label}: ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      row.value.isEmpty
                                          ? '—'
                                          : row.value,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            )),

                        const SizedBox(height: 8),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                                child: _actionButton(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              color: editColor,
                              onTap: onEdit,
                            )),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _actionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: Colors.red.shade600,
                              onTap: onDelete,
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}