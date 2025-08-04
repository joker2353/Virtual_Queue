import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/master_sku.dart';
import '../providers/master_sku_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/inventory_search_dropdown.dart';
import '../services/inventory_search_service.dart';
import 'delivery_selection_page.dart';

class ShopOrderPage extends StatefulWidget {
  final String roomId;
  final String customerName;
  final String customerContact;

  const ShopOrderPage({
    super.key,
    required this.roomId,
    required this.customerName,
    required this.customerContact,
  });

  static void navigate(
    BuildContext context,
    String roomId,
    String customerName,
    String customerContact,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ShopOrderPage(
              roomId: roomId,
              customerName: customerName,
              customerContact: customerContact,
            ),
      ),
    );
  }

  @override
  _ShopOrderPageState createState() => _ShopOrderPageState();
}

class _ShopOrderPageState extends State<ShopOrderPage> {
  Room? _room;
  List<OrderItem> _items = [];
  bool _isLoading = true;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _itemQuantityController = TextEditingController();
  final _itemNotesController = TextEditingController();

  // NEW FIELDS for inventory search
  final InventorySearchService _searchService = InventorySearchService();
  List<MenuItem> _searchResults = [];
  bool _isSearching = false;
  MenuItem? _selectedMenuItem;
  bool _showSearchDropdown = false;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemQuantityController.dispose();
    _itemNotesController.dispose();
    super.dispose();
  }

  // Search items in inventory
  Future<void> _searchItems(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showSearchDropdown = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchDropdown = true;
    });

    try {
      final results = await _searchService.searchMenuItems(
        roomId: widget.roomId,
        searchQuery: query,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _showError('Error searching items: $e');
      }
    }
  }

  // Handle item selection from search results
  void _selectMenuItem(MenuItem menuItem) {
    setState(() {
      _selectedMenuItem = menuItem;
      _itemNameController.text = menuItem.name;
      _searchResults = [];
      _showSearchDropdown = false;
    });

    // Auto-fill price information
    _updateItemPrice();
  }

  // Update price when item or quantity changes
  void _updateItemPrice() {
    if (_selectedMenuItem != null) {
      final quantity = int.tryParse(_itemQuantityController.text) ?? 0;
      final totalPrice = _searchService.calculateItemPrice(
        unitPrice: _selectedMenuItem!.price,
        quantity: quantity,
      );

      // Update UI to show calculated price (will be shown in the form)
      setState(() {
        // Price will be displayed in the form
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadRoom() async {
    try {
      final roomDoc =
          await firestore.FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      setState(() {
        _room = Room.fromMap(widget.roomId, roomDoc.data()!);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addItem() async {
    if (_formKey.currentState!.validate()) {
      final quantity = int.tryParse(_itemQuantityController.text.trim());
      if (quantity == null || quantity <= 0) {
        _showError('Please enter a valid quantity');
        return;
      }

      // Validate inventory if item is selected from search
      if (_selectedMenuItem != null) {
        try {
          final validation = await _searchService.validateItem(
            menuItemId: _selectedMenuItem!.id,
            requestedQuantity: quantity,
          );

          if (!validation.isValid) {
            _showError(validation.errorMessage ?? 'Item not available');
            return;
          }

          // Create order item with inventory data
          final orderItem = OrderItem(
            name: _selectedMenuItem!.name,
            quantity: quantity,
            notes: _itemNotesController.text.trim(),
            isAvailable: true,
            masterSkuId: _selectedMenuItem!.masterSkuId,
            unitPrice: validation.unitPrice,
            menuItemId: _selectedMenuItem!.id,
            totalPrice: validation.totalPrice!,
            inventoryValidated: true,
            availableStock: validation.availableStock,
          );

          setState(() {
            _items.add(orderItem);
          });

          _showSuccess('Item added successfully (Inventory validated)');
        } catch (e) {
          _showError('Error validating item: $e');
          return;
        }
      } else {
        // Fallback for manual entry (existing behavior)
        final orderItem = OrderItem(
          name: _itemNameController.text,
          quantity: quantity,
          notes: _itemNotesController.text.trim(),
          isAvailable: true,
          totalPrice: 0.0, // Will be calculated later
          inventoryValidated: false,
        );

        setState(() {
          _items.add(orderItem);
        });

        _showSuccess('Item added successfully (Manual entry)');
      }

      // Clear form and reset selection
      _clearForm();
    }
  }

  void _clearForm() {
    _itemNameController.clear();
    _itemQuantityController.clear();
    _itemNotesController.clear();
    setState(() {
      _selectedMenuItem = null;
      _searchResults = [];
      _showSearchDropdown = false;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final notesController = TextEditingController(text: item.notes ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Item'),
            content: Form(
              key: GlobalKey<FormState>(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter quantity';
                      }
                      final quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'Please enter a valid quantity';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final quantity = int.tryParse(quantityController.text);
                  if (quantity == null || quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid quantity'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _items[index] = item.copyWith(
                      name: nameController.text,
                      quantity: quantity,
                      notes: notesController.text,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _placeOrder() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one item to your order'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Navigate to delivery selection page
    DeliverySelectionPage.navigate(
      context,
      widget.roomId,
      widget.customerName,
      widget.customerContact,
      _items,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading...'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(child: LoadingIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Error'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading room details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Place Order',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade500, Colors.deepPurple.shade50],
            stops: const [0.0, 0.2],
          ),
        ),
        child: Column(
          children: [
            // Add Item Form
            Container(
              margin: EdgeInsets.fromLTRB(16, 24, 16, 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Item',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _itemNameController,
                          decoration: InputDecoration(
                            labelText: 'Item Name (Search inventory)',
                            labelStyle: TextStyle(
                              color: Colors.deepPurple.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.deepPurple.shade400,
                            ),
                            suffixIcon:
                                _selectedMenuItem != null
                                    ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedMenuItem = null;
                                          _itemNameController.clear();
                                        });
                                      },
                                    )
                                    : null,
                            filled: true,
                            fillColor: Colors.deepPurple.shade50.withOpacity(
                              0.3,
                            ),
                            hintText: 'Start typing to search inventory...',
                          ),
                          onChanged: _searchItems,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter item name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 8),
                        // Show selected item info
                        if (_selectedMenuItem != null)
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selected: ${_selectedMenuItem!.name}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      Text(
                                        'Price: ৳${_selectedMenuItem!.price.toStringAsFixed(2)} | Stock: ${_selectedMenuItem!.currentStock ?? 0}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Search dropdown
                        InventorySearchDropdown(
                          searchResults: _searchResults,
                          isLoading: _isSearching,
                          onItemSelected: _selectMenuItem,
                          showDropdown: _showSearchDropdown,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _itemQuantityController,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            labelStyle: TextStyle(
                              color: Colors.deepPurple.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.scale,
                              color: Colors.deepPurple.shade400,
                            ),
                            filled: true,
                            fillColor: Colors.deepPurple.shade50.withOpacity(
                              0.3,
                            ),
                            hintText: 'Enter quantity (e.g., 2)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (_selectedMenuItem != null) {
                              _updateItemPrice();
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter quantity';
                            }
                            final quantity = int.tryParse(value);
                            if (quantity == null || quantity <= 0) {
                              return 'Please enter a valid quantity';
                            }
                            return null;
                          },
                        ),
                        // Show price calculation
                        if (_selectedMenuItem != null)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calculate,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Price Calculation',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      Text(
                                        '${_itemQuantityController.text.isEmpty ? "0" : _itemQuantityController.text} × ৳${_selectedMenuItem!.price.toStringAsFixed(2)} = ৳${_searchService.calculateItemPrice(unitPrice: _selectedMenuItem!.price, quantity: int.tryParse(_itemQuantityController.text) ?? 0).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _itemNotesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        labelStyle: TextStyle(
                          color: Colors.deepPurple.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.deepPurple.shade200,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.deepPurple.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.note_outlined,
                          color: Colors.deepPurple.shade400,
                        ),
                        filled: true,
                        fillColor: Colors.deepPurple.shade50.withOpacity(0.3),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: Icon(Icons.add_circle_outline, size: 24),
                        label: Text(
                          'Add to Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.deepPurple.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Order Items List
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.deepPurple.shade50,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.list_alt,
                            color: Colors.deepPurple.shade400,
                            size: 26,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Order Items',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.deepPurple.shade200,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_items.length} items',
                              style: TextStyle(
                                color: Colors.deepPurple.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _items.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 72,
                                      color: Colors.deepPurple.shade200,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No items added yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.deepPurple.shade300,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add items using the form above',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: EdgeInsets.all(16),
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    shadowColor: Colors.deepPurple.shade100,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Colors.deepPurple.shade100,
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.all(16),
                                      leading: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade50,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.deepPurple.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            item.quantity.toString(),
                                            style: TextStyle(
                                              color: Colors.deepPurple.shade700,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        item.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.deepPurple.shade900,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item.notes?.isNotEmpty ?? false)
                                            Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Text(
                                                item.notes!,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          if (item.totalPrice > 0)
                                            Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '৳${item.totalPrice.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      color: Colors.deepPurple,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (item
                                                      .inventoryValidated) ...[
                                                    SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors
                                                                .green
                                                                .shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Validated',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors
                                                                  .green
                                                                  .shade700,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              color: Colors.deepPurple.shade400,
                                            ),
                                            onPressed: () => _editItem(index),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red.shade400,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _items.removeAt(index);
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Item removed'),
                                                  backgroundColor:
                                                      Colors.red.shade400,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                    if (_items.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _placeOrder,
                            icon: Icon(Icons.check_circle_outline, size: 24),
                            label: Text(
                              'Continue to Delivery Options',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: Colors.green.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
