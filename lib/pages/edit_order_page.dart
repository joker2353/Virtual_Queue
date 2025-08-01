import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/room.dart';
import '../models/menu_item.dart';
import '../providers/inventory_provider.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/cart_item_card.dart';

class EditOrderPage extends StatefulWidget {
  final String roomId;
  final String customerName;
  final String customerContact;
  final Order existingOrder;

  const EditOrderPage({
    Key? key,
    required this.roomId,
    required this.customerName,
    required this.customerContact,
    required this.existingOrder,
  }) : super(key: key);

  @override
  _EditOrderPageState createState() => _EditOrderPageState();
}

class _EditOrderPageState extends State<EditOrderPage> {
  Room? _room;
  List<OrderItem> _items = [];
  bool _isLoading = true;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _itemQuantityController = TextEditingController();
  final _itemNotesController = TextEditingController();
  MenuItem? _selectedMenuItem;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemQuantityController.dispose();
    _itemNotesController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // Load room data
      final roomDoc =
          await firestore.FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      // Initialize items with existing order items
      _items = List.from(widget.existingOrder.items);

      setState(() {
        _room = Room.fromMap(widget.roomId, roomDoc.data()!);
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing edit order page: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      final quantity = int.tryParse(_itemQuantityController.text.trim());
      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid quantity'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedMenuItem != null) {
        // Check stock availability
        if (_selectedMenuItem!.currentStock != null &&
            quantity > _selectedMenuItem!.currentStock!) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not enough stock available'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _items.add(
          OrderItem(
            name: _selectedMenuItem?.name ?? _itemNameController.text,
            quantity: quantity,
            notes: _itemNotesController.text.trim(),
            isAvailable: true,
            masterSkuId: _selectedMenuItem?.masterSkuId,
            unitPrice: _selectedMenuItem?.price,
          ),
        );
      });

      // Clear form
      _itemNameController.clear();
      _itemQuantityController.clear();
      _itemNotesController.clear();
      setState(() {
        _selectedMenuItem = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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

  Future<void> _updateOrder() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to your order'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calculate total amount
      final totalAmount = _items.fold<double>(
        0,
        (sum, item) => sum + (item.unitPrice ?? 0) * item.quantity,
      );

      // Update the existing order
      await firestore.FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.existingOrder.id)
          .update({
            'items': _items.map((item) => item.toMap()).toList(),
            'totalAmount': totalAmount,
            'updatedAt': firestore.FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating order: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Order')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Menu item selection
                  StreamBuilder<List<MenuItem>>(
                    stream: Provider.of<InventoryProvider>(
                      context,
                    ).streamAvailableItems(widget.roomId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      if (!snapshot.hasData) {
                        return const LoadingIndicator();
                      }

                      final items = snapshot.data!;
                      return DropdownButtonFormField<MenuItem>(
                        value: _selectedMenuItem,
                        decoration: InputDecoration(
                          labelText: 'Select Item',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items:
                            items.map((item) {
                              return DropdownMenuItem(
                                value: item,
                                child: Text(
                                  '${item.name} (\$${item.price.toStringAsFixed(2) ?? "N/A"})',
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMenuItem = value;
                            if (value != null) {
                              _itemNameController.text = value.name;
                            }
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Manual item name input
                  if (_selectedMenuItem == null)
                    TextFormField(
                      controller: _itemNameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (_selectedMenuItem == null &&
                            (value == null || value.isEmpty)) {
                          return 'Please enter item name or select from menu';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  // Quantity input
                  TextFormField(
                    controller: _itemQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
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
                  // Notes input
                  TextFormField(
                    controller: _itemNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addItem,
                    child: const Text('Add Item'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return CartItemCard(
                  item: item,
                  notesController: TextEditingController(text: item.notes),
                  onRemove: () => _removeItem(index),
                  onQuantityChanged: (quantity) {
                    setState(() {
                      _items[index] = item.copyWith(quantity: quantity);
                    });
                  },
                  onNotesChanged: (notes) {
                    setState(() {
                      _items[index] = item.copyWith(notes: notes);
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_items.isNotEmpty) ...[
                Text(
                  'Total: \$${_items.fold<double>(0, (sum, item) => sum + (item.unitPrice ?? 0) * item.quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _items.isEmpty ? null : _updateOrder,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Update Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
