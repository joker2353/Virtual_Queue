import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/master_sku.dart';
import '../providers/inventory_provider.dart';
import '../providers/master_sku_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_indicator.dart';

class InventoryManagementPage extends StatefulWidget {
  final String roomId;

  const InventoryManagementPage({super.key, required this.roomId});

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showLowStockOnly = false;
  bool _showOutOfStockOnly = false;
  bool _showPriceOverridesOnly = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    inventoryProvider.setUserId(authProvider.user?.uid ?? '');

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Check for expired price overrides
    Future.microtask(
      () => inventoryProvider.checkAndResetExpiredPriceOverrides(),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _showAddFromMasterSKUDialog(BuildContext context) async {
    final masterSkuProvider = context.read<MasterSKUProvider>();
    final inventoryProvider = context.read<InventoryProvider>();

    final MasterSKU? selectedSku = await showDialog<MasterSKU>(
      context: context,
      builder:
          (context) =>
              AddFromMasterSKUDialog(masterSkuProvider: masterSkuProvider),
    );

    if (selectedSku == null) return;

    // Show stock and price dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StockAndPriceDialog(sku: selectedSku),
    );

    if (result == null) return;

    try {
      await inventoryProvider.createMenuItemFromSKU(
        selectedSku,
        roomId: widget.roomId,
        initialStock: result['initialStock'] as int?,
        minimumStock: result['minimumStock'] as int?,
        overridePrice: result['overridePrice'] as double?,
        priceOverrideReason: result['priceOverrideReason'] as String?,
        priceOverrideExpiry: result['priceOverrideExpiry'] as DateTime?,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showStockHistoryDialog(MenuItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => StockHistoryDialog(item: item),
    );
  }

  Future<void> _showPriceHistoryDialog(MenuItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => PriceHistoryDialog(item: item),
    );
  }

  Future<void> _showUpdateStockDialog(MenuItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => UpdateStockDialog(currentStock: item.currentStock ?? 0),
    );

    if (result == null) return;

    try {
      await context.read<InventoryProvider>().updateStock(
        item.id,
        newStock: result['newStock'] as int,
        reason: result['reason'] as String,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showUpdatePriceDialog(MenuItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => UpdatePriceDialog(
            currentPrice: item.price,
            originalPrice: item.originalPrice,
          ),
    );

    if (result == null) return;

    try {
      await context.read<InventoryProvider>().updatePrice(
        item.id,
        newPrice: result['newPrice'] as double,
        reason: result['reason'] as String,
        expiryDate: result['expiryDate'] as DateTime?,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating price: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Inventory Management',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade600,
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddFromMasterSKUDialog(context),
              icon: Icon(Icons.add, color: Colors.white),
              label: Text('Add Item', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Enhanced Search and Filter Section
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Items',
                        hintText: 'Enter item name or description...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.deepPurple.shade600,
                        ),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged:
                          (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Filter Chips with improved design
                  Text(
                    'Quick Filters:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Low Stock',
                        icon: Icons.warning_amber,
                        selected: _showLowStockOnly,
                        color: Colors.orange,
                        onSelected:
                            (selected) => setState(() {
                              _showLowStockOnly = selected;
                              if (selected) {
                                _showOutOfStockOnly = false;
                                _showPriceOverridesOnly = false;
                              }
                            }),
                      ),
                      _buildFilterChip(
                        label: 'Out of Stock',
                        icon: Icons.cancel_outlined,
                        selected: _showOutOfStockOnly,
                        color: Colors.red,
                        onSelected:
                            (selected) => setState(() {
                              _showOutOfStockOnly = selected;
                              if (selected) {
                                _showLowStockOnly = false;
                                _showPriceOverridesOnly = false;
                              }
                            }),
                      ),
                      _buildFilterChip(
                        label: 'Price Overrides',
                        icon: Icons.attach_money,
                        selected: _showPriceOverridesOnly,
                        color: Colors.purple,
                        onSelected:
                            (selected) => setState(() {
                              _showPriceOverridesOnly = selected;
                              if (selected) {
                                _showLowStockOnly = false;
                                _showOutOfStockOnly = false;
                              }
                            }),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Inventory Cards
            Expanded(
              child: StreamBuilder<List<MenuItem>>(
                stream:
                    _showOutOfStockOnly
                        ? inventoryProvider.streamOutOfStockItems()
                        : _showLowStockOnly
                        ? inventoryProvider.streamLowStockItems()
                        : inventoryProvider.streamAvailableItems(widget.roomId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: LoadingIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.shade400,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Error loading inventory',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: Icon(Icons.refresh),
                            label: Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  final filteredItems =
                      items
                          .where(
                            (item) =>
                                (_searchQuery.isEmpty ||
                                    item.name.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ||
                                    item.description.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    )) &&
                                (!_showPriceOverridesOnly ||
                                    item.hasPriceOverride),
                          )
                          .toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No items found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (_searchQuery.isNotEmpty ||
                              _showLowStockOnly ||
                              _showOutOfStockOnly ||
                              _showPriceOverridesOnly)
                            Text(
                              'Try adjusting your filters or search terms',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildInventoryCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : color),
          SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? color : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildInventoryCard(MenuItem item) {
    final hasOverride = item.hasPriceOverride;
    final isOverrideExpired = item.isPriceOverrideExpired;
    final isOutOfStock = item.isOutOfStock;
    final isLowStock = item.isLowStock;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (item.description.isNotEmpty)
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isOutOfStock
                            ? Colors.red.shade100
                            : isLowStock
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOutOfStock
                        ? 'Out of Stock'
                        : isLowStock
                        ? 'Low Stock'
                        : 'In Stock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isOutOfStock
                              ? Colors.red.shade700
                              : isLowStock
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Stock and Price Information
            Row(
              children: [
                // Stock Information
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${item.currentStock ?? 0}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color:
                                    isOutOfStock
                                        ? Colors.red.shade600
                                        : isLowStock
                                        ? Colors.orange.shade600
                                        : Colors.blue.shade700,
                              ),
                            ),
                            if (item.minimumStock != null) ...[
                              SizedBox(width: 8),
                              Text(
                                '/ ${item.minimumStock} min',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 12),

                // Price Information
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          hasOverride
                              ? Colors.purple.shade50
                              : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            hasOverride
                                ? Colors.purple.shade200
                                : Colors.green.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color:
                                  hasOverride
                                      ? Colors.purple.shade700
                                      : Colors.green.shade700,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Price',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    hasOverride
                                        ? Colors.purple.shade700
                                        : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '৳${item.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color:
                                    hasOverride
                                        ? isOverrideExpired
                                            ? Colors.red.shade600
                                            : Colors.purple.shade700
                                        : Colors.green.shade700,
                                decoration:
                                    isOverrideExpired
                                        ? TextDecoration.lineThrough
                                        : null,
                              ),
                            ),
                            if (hasOverride && item.originalPrice != null)
                              Text(
                                'Original: ৳${item.originalPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  decoration:
                                      isOverrideExpired
                                          ? null
                                          : TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // Stock History Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStockHistoryDialog(item),
                    icon: Icon(Icons.history, size: 16),
                    label: Text('Stock History'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8),

                // Price History Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPriceHistoryDialog(item),
                    icon: Icon(Icons.trending_up, size: 16),
                    label: Text('Price History'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8),

                // Update Stock Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showUpdateStockDialog(item),
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Update Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8),

                // Update Price Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showUpdatePriceDialog(item),
                    icon: Icon(Icons.attach_money, size: 16),
                    label: Text('Update Price'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddFromMasterSKUDialog extends StatefulWidget {
  final MasterSKUProvider masterSkuProvider;

  const AddFromMasterSKUDialog({super.key, required this.masterSkuProvider});

  @override
  State<AddFromMasterSKUDialog> createState() => _AddFromMasterSKUDialogState();
}

class _AddFromMasterSKUDialogState extends State<AddFromMasterSKUDialog> {
  String _searchQuery = '';
  String _selectedCategory = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.masterSkuProvider.loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Add from Master SKU',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search and Category Filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search SKUs',
                      hintText: 'Enter SKU name or description',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedCategory.isEmpty ? null : _selectedCategory,
                  hint: const Text('All Categories'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All Categories'),
                    ),
                    ...widget.masterSkuProvider.categories.map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    ),
                  ],
                  onChanged:
                      (value) =>
                          setState(() => _selectedCategory = value ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // SKU List
            Expanded(
              child: StreamBuilder<List<MasterSKU>>(
                stream: widget.masterSkuProvider.streamSKUs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final skus = snapshot.data ?? [];
                  final filteredSkus =
                      skus.where((sku) {
                        final matchesSearch =
                            _searchQuery.isEmpty ||
                            sku.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            sku.description.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            );
                        final matchesCategory =
                            _selectedCategory.isEmpty ||
                            sku.category == _selectedCategory;
                        return matchesSearch && matchesCategory;
                      }).toList();

                  if (filteredSkus.isEmpty) {
                    return const Center(child: Text('No SKUs found'));
                  }

                  return ListView.builder(
                    itemCount: filteredSkus.length,
                    itemBuilder: (context, index) {
                      final sku = filteredSkus[index];
                      return ListTile(
                        leading:
                            sku.imageUrl != null
                                ? Image.network(
                                  sku.imageUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(Icons.image_not_supported),
                                )
                                : const Icon(Icons.inventory_2_outlined),
                        title: Text(sku.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sku.description),
                            Text(
                              'Category: ${sku.category}',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            sku.price != null
                                ? Text(
                                  '৳${sku.price!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                : const Text('No price'),
                        onTap: () => Navigator.of(context).pop(sku),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StockAndPriceDialog extends StatefulWidget {
  final MasterSKU sku;

  const StockAndPriceDialog({super.key, required this.sku});

  @override
  State<StockAndPriceDialog> createState() => _StockAndPriceDialogState();
}

class _StockAndPriceDialogState extends State<StockAndPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _initialStockController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _priceController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime? _expiryDate;
  bool _overridePrice = false;

  @override
  void initState() {
    super.initState();
    if (widget.sku.price != null) {
      _priceController.text = widget.sku.price!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _initialStockController.dispose();
    _minimumStockController.dispose();
    _priceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Set Initial Stock and Price',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _initialStockController,
                decoration: const InputDecoration(
                  labelText: 'Initial Stock',
                  hintText: 'Enter initial stock quantity',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final number = int.tryParse(value);
                  if (number == null) return 'Please enter a valid number';
                  if (number < 0) return 'Stock cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _minimumStockController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Stock',
                  hintText: 'Enter minimum stock level for alerts',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final number = int.tryParse(value);
                  if (number == null) return 'Please enter a valid number';
                  if (number < 0) return 'Minimum stock cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _overridePrice,
                onChanged:
                    widget.sku.price == null
                        ? null
                        : (value) => setState(() => _overridePrice = value!),
                title: const Text('Override Price'),
                subtitle: Text(
                  widget.sku.price == null
                      ? 'No base price set'
                      : 'Base price: ৳${widget.sku.price!.toStringAsFixed(2)}',
                ),
              ),
              if (_overridePrice) ...[
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Override Price',
                    hintText: 'Enter new price',
                    prefixText: '৳',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    final number = double.tryParse(value);
                    if (number == null) {
                      return 'Please enter a valid number';
                    }
                    if (number < 0) return 'Price cannot be negative';
                    if (number == widget.sku.price) {
                      return 'Override price must be different from base price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Override Reason',
                    hintText: 'Enter reason for price override',
                  ),
                  validator: (value) {
                    if (!_overridePrice) return null;
                    if (value == null || value.isEmpty) {
                      return 'Please enter a reason for the override';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Override Expiry'),
                  subtitle: Text(
                    _expiryDate == null
                        ? 'No expiry date set'
                        : 'Expires on: ${_expiryDate!.toLocal()}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _expiryDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;

                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          _expiryDate ?? DateTime.now(),
                        ),
                      );
                      if (time == null) return;

                      setState(() {
                        _expiryDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      final result = <String, dynamic>{};

                      final initialStock = int.tryParse(
                        _initialStockController.text,
                      );
                      if (initialStock != null) {
                        result['initialStock'] = initialStock;
                      }

                      final minimumStock = int.tryParse(
                        _minimumStockController.text,
                      );
                      if (minimumStock != null) {
                        result['minimumStock'] = minimumStock;
                      }

                      if (_overridePrice) {
                        final overridePrice = double.tryParse(
                          _priceController.text,
                        );
                        if (overridePrice != null) {
                          result['overridePrice'] = overridePrice;
                          result['priceOverrideReason'] =
                              _reasonController.text;
                          result['priceOverrideExpiry'] = _expiryDate;
                        }
                      }

                      Navigator.of(context).pop(result);
                    },
                    child: const Text('Add Item'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StockHistoryDialog extends StatelessWidget {
  final MenuItem item;

  const StockHistoryDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Stock History - ${item.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  item.stockHistory.isEmpty
                      ? const Center(child: Text('No stock history available'))
                      : ListView.builder(
                        itemCount: item.stockHistory.length,
                        itemBuilder: (context, index) {
                          final adjustment = item.stockHistory[index];
                          final isPositive = adjustment.quantity > 0;
                          return ListTile(
                            leading: Icon(
                              isPositive
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              '${isPositive ? '+' : ''}${adjustment.quantity}',
                              style: TextStyle(
                                color: isPositive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(adjustment.reason),
                            trailing: Text(
                              adjustment.timestamp.toLocal().toString(),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class PriceHistoryDialog extends StatelessWidget {
  final MenuItem item;

  const PriceHistoryDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Price History - ${item.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  item.priceHistory.isEmpty
                      ? const Center(child: Text('No price history available'))
                      : ListView.builder(
                        itemCount: item.priceHistory.length,
                        itemBuilder: (context, index) {
                          final adjustment = item.priceHistory[index];
                          final isIncrease =
                              adjustment.newPrice > adjustment.oldPrice;
                          return ListTile(
                            leading: Icon(
                              isIncrease
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isIncrease ? Colors.orange : Colors.green,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  '৳${adjustment.oldPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const Icon(Icons.arrow_forward, size: 16),
                                Text(
                                  '৳${adjustment.newPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color:
                                        isIncrease
                                            ? Colors.orange
                                            : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(adjustment.reason),
                                if (adjustment.expiryDate != null)
                                  Text(
                                    'Expires: ${adjustment.expiryDate!.toLocal()}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              adjustment.timestamp.toLocal().toString(),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateStockDialog extends StatefulWidget {
  final int currentStock;

  const UpdateStockDialog({super.key, required this.currentStock});

  @override
  State<UpdateStockDialog> createState() => _UpdateStockDialogState();
}

class _UpdateStockDialogState extends State<UpdateStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stockController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isAdjustment = false;

  @override
  void initState() {
    super.initState();
    _stockController.text = widget.currentStock.toString();
  }

  @override
  void dispose() {
    _stockController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Update Stock',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _isAdjustment,
                onChanged: (value) => setState(() => _isAdjustment = value),
                title: const Text('Adjust Stock'),
                subtitle: Text(
                  _isAdjustment
                      ? 'Enter amount to add/subtract'
                      : 'Enter new total stock',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: _isAdjustment ? 'Stock Adjustment' : 'New Stock',
                  hintText:
                      _isAdjustment
                          ? 'Enter amount to add/subtract'
                          : 'Enter new total stock',
                  prefixText: _isAdjustment ? '+ / - ' : null,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  final number = int.tryParse(value);
                  if (number == null) {
                    return 'Please enter a valid number';
                  }
                  if (!_isAdjustment && number < 0) {
                    return 'Stock cannot be negative';
                  }
                  if (!_isAdjustment && number == widget.currentStock) {
                    return 'New stock must be different';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Enter reason for stock update',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      final adjustment = int.parse(_stockController.text);
                      final newStock =
                          _isAdjustment
                              ? widget.currentStock + adjustment
                              : adjustment;

                      if (newStock < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Stock cannot be negative'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).pop({
                        'newStock': newStock,
                        'reason': _reasonController.text,
                      });
                    },
                    child: const Text('Update Stock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdatePriceDialog extends StatefulWidget {
  final double currentPrice;
  final double? originalPrice;

  const UpdatePriceDialog({
    super.key,
    required this.currentPrice,
    this.originalPrice,
  });

  @override
  State<UpdatePriceDialog> createState() => _UpdatePriceDialogState();
}

class _UpdatePriceDialogState extends State<UpdatePriceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.currentPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Update Price',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (widget.originalPrice != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Original Price: ৳${widget.originalPrice!.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'New Price',
                  hintText: 'Enter new price',
                  prefixText: '৳',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  final number = double.tryParse(value);
                  if (number == null) {
                    return 'Please enter a valid number';
                  }
                  if (number < 0) {
                    return 'Price cannot be negative';
                  }
                  if (number == widget.currentPrice) {
                    return 'New price must be different';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Enter reason for price update',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Price Override Expiry'),
                subtitle: Text(
                  _expiryDate == null
                      ? 'No expiry date set'
                      : 'Expires on: ${_expiryDate!.toLocal()}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_expiryDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _expiryDate = null),
                        tooltip: 'Clear expiry date',
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date == null) return;

                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            _expiryDate ?? DateTime.now(),
                          ),
                        );
                        if (time == null) return;

                        setState(() {
                          _expiryDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      tooltip: 'Set expiry date',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      final newPrice = double.parse(_priceController.text);
                      Navigator.of(context).pop({
                        'newPrice': newPrice,
                        'reason': _reasonController.text,
                        'expiryDate': _expiryDate,
                      });
                    },
                    child: const Text('Update Price'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
