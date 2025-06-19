import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../models/room.dart';
import '../models/order.dart';
import '../widgets/loading_indicator.dart';

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

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _items.add(
          OrderItem(
            name: _itemNameController.text,
            quantity: _itemQuantityController.text.trim(),
            price: 0, // Price will be set by shop owner
            notes: _itemNotesController.text.trim(),
            isAvailable: true,
          ),
        );
      });

      // Clear form
      _itemNameController.clear();
      _itemQuantityController.clear();
      _itemNotesController.clear();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(text: item.quantity);
    final notesController = TextEditingController(text: item.notes ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Item'),
            content: Form(
              key: GlobalKey<FormState>(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
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
                        Icons.shopping_bag_outlined,
                        color: Colors.deepPurple.shade400,
                      ),
                      filled: true,
                      fillColor: Colors.deepPurple.shade50.withOpacity(0.3),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter item name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity (e.g., 2 kg, 1 liter)',
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
                      fillColor: Colors.deepPurple.shade50.withOpacity(0.3),
                      hintText: 'Enter quantity with unit',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter quantity';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
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
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _items[index] = OrderItem(
                      name: nameController.text,
                      quantity: quantityController.text.trim(),
                      price: 0,
                      notes: notesController.text.trim(),
                      isAvailable: true,
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Item updated successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Save Changes'),
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

    try {
      print('Placing order for customer: ${widget.customerContact}');
      print('Room ID: ${widget.roomId}');

      // Verify room exists before creating order
      final roomDoc =
          await firestore.FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      // Create the order with proper data
      final order = Order(
        id: '',
        roomId: widget.roomId,
        userId: '',
        customerName: widget.customerName,
        customerContact: widget.customerContact,
        items:
            _items
                .map(
                  (item) => OrderItem(
                    name: item.name,
                    quantity: item.quantity,
                    price: 0, // Price will be set by shop owner
                    notes: item.notes,
                    isAvailable: true,
                  ),
                )
                .toList(),
        totalAmount: 0, // Total will be calculated by shop owner
        status: 'pending',
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Creating order with data:');
      print('Customer: ${order.customerContact}');
      print('Room ID: ${order.roomId}');
      print('Items count: ${order.items.length}');

      // Add the order to Firestore
      final docRef = await firestore.FirebaseFirestore.instance
          .collection('orders')
          .add(order.toMap());

      print('Order created with ID: ${docRef.id}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order placed successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error placing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                    TextFormField(
                      controller: _itemNameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
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
                          Icons.shopping_bag_outlined,
                          color: Colors.deepPurple.shade400,
                        ),
                        filled: true,
                        fillColor: Colors.deepPurple.shade50.withOpacity(0.3),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter item name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _itemQuantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity (e.g., 2 kg, 1 liter)',
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
                        fillColor: Colors.deepPurple.shade50.withOpacity(0.3),
                        hintText: 'Enter quantity with unit',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        return null;
                      },
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
                                            item.quantity,
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
                                      subtitle:
                                          item.notes?.isNotEmpty ?? false
                                              ? Padding(
                                                padding: EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  item.notes!,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 14,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              )
                                              : null,
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
                              'Place Order',
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
