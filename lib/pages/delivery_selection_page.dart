import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../models/room.dart';
import '../models/order.dart';
import '../models/user_room.dart';
import '../providers/room_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/delivery_option_selector.dart';
import '../widgets/address_input_widget.dart';
import '../widgets/order_summary_widget.dart';
import '../services/inventory_search_service.dart';

class DeliverySelectionPage extends StatefulWidget {
  final String roomId;
  final String customerName;
  final String customerContact;
  final List<OrderItem> items;

  const DeliverySelectionPage({
    Key? key,
    required this.roomId,
    required this.customerName,
    required this.customerContact,
    required this.items,
  }) : super(key: key);

  static void navigate(
    BuildContext context,
    String roomId,
    String customerName,
    String customerContact,
    List<OrderItem> items,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DeliverySelectionPage(
              roomId: roomId,
              customerName: customerName,
              customerContact: customerContact,
              items: items,
            ),
      ),
    );
  }

  @override
  State<DeliverySelectionPage> createState() => _DeliverySelectionPageState();
}

class _DeliverySelectionPageState extends State<DeliverySelectionPage> {
  Room? _room;
  String _deliveryType = 'pickup';
  String _deliveryAddress = '';
  bool _isLoading = true;
  String? _error;

  // NEW FIELDS for price calculation
  double _subtotal = 0.0;
  double _totalAmount = 0.0;
  final InventorySearchService _searchService = InventorySearchService();

  @override
  void initState() {
    super.initState();
    _loadRoomAndAddress();
    _calculatePrices();
  }

  Future<void> _loadRoomAndAddress() async {
    try {
      // Load room details
      final roomDoc =
          await firestore.FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (roomDoc.exists) {
        setState(() {
          _room = Room.fromMap(widget.roomId, roomDoc.data()!);
        });
      }

      // Load customer's existing delivery address
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      final userRoom = roomProvider.userRooms.firstWhere(
        (room) => room.roomId == widget.roomId,
        orElse:
            () => UserRoom(
              roomId: widget.roomId,
              name: _room?.name ?? '',
              type: 'joined',
              status: 'active',
              category: _room?.category ?? 'shop',
              position: 0,
              currentPosition: 0,
              memberCount: 0,
              joinedAt: DateTime.now(),
              deliveryAddress: null,
            ),
      );

      if (userRoom.deliveryAddress != null &&
          userRoom.deliveryAddress!.isNotEmpty) {
        setState(() {
          _deliveryAddress = userRoom.deliveryAddress!;
        });
        print('Auto-filled delivery address: $_deliveryAddress');
      } else {
        print('No saved delivery address found for this room');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Calculate prices for all items
  Future<void> _calculatePrices() async {
    double subtotal = 0.0;

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];

      if (item.inventoryValidated && item.totalPrice > 0) {
        subtotal += item.totalPrice;
      } else if (item.menuItemId != null) {
        // Re-validate and calculate price
        try {
          final validation = await _searchService.validateItem(
            menuItemId: item.menuItemId!,
            requestedQuantity: item.quantity,
          );

          if (validation.isValid) {
            final totalPrice = validation.totalPrice!;
            widget.items[i] = item.copyWith(
              totalPrice: totalPrice,
              unitPrice: validation.unitPrice,
              inventoryValidated: true,
            );
            subtotal += totalPrice;
          }
        } catch (e) {
          print('Error validating item ${item.name}: $e');
        }
      }
    }

    setState(() {
      _subtotal = subtotal;
      _totalAmount =
          _subtotal +
          (_deliveryType == 'delivery' ? (_room?.deliveryFee ?? 50.0) : 0.0);
    });
  }

  Future<void> _placeOrder() async {
    if (_deliveryType == 'delivery' && _deliveryAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a delivery address'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Validate all items have prices
      final itemsWithoutPrices =
          widget.items.where((item) => item.totalPrice <= 0).toList();
      if (itemsWithoutPrices.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Some items do not have valid prices. Please review your order.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Calculate delivery fee
      final deliveryFee =
          _deliveryType == 'delivery' ? (_room?.deliveryFee ?? 50.0) : 0.0;

      // Create the order with calculated prices
      final order = Order(
        id: '',
        roomId: widget.roomId,
        userId: '',
        customerName: widget.customerName,
        customerContact: widget.customerContact,
        items: widget.items,
        totalAmount: _totalAmount,
        subtotalAmount: _subtotal,
        status: 'pending',
        paymentMethod: 'cash',
        deliveryType: _deliveryType,
        deliveryAddress: _deliveryType == 'delivery' ? _deliveryAddress : null,
        deliveryFee: deliveryFee,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        inventoryChecked: true,
      );

      // Add the order to Firestore
      final docRef = await firestore.FirebaseFirestore.instance
          .collection('orders')
          .add(order.toMap());

      // Deduct inventory for validated items
      await _deductInventory(order);

      // Update delivery address in user room if delivery is selected
      if (_deliveryType == 'delivery' && _deliveryAddress.isNotEmpty) {
        final roomProvider = Provider.of<RoomProvider>(context, listen: false);
        await roomProvider.updateDeliveryAddress(
          roomId: widget.roomId,
          address: _deliveryAddress,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order placed successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Deduct inventory for validated items
  Future<void> _deductInventory(Order order) async {
    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );

    // Only deduct for items that were inventory validated
    final validatedItems =
        order.items.where((item) => item.inventoryValidated).toList();

    if (validatedItems.isNotEmpty) {
      // Create a temporary order with only validated items for inventory deduction
      final tempOrder = order.copyWith(items: validatedItems);
      // Use adjustStockFromOrder to deduct inventory when order is created
      await inventoryProvider.adjustStockFromOrder(
        tempOrder,
        'pending', // old status
        'completed', // new status (this will trigger stock deduction)
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Error'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text('Error: $_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Options'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            // Delivery Options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    // Delivery Option Selector
                    DeliveryOptionSelector(
                      selectedOption: _deliveryType,
                      onOptionChanged: (option) {
                        setState(() {
                          _deliveryType = option;
                          if (option == 'pickup') {
                            // Don't clear the address when switching to pickup
                            // Keep it for when user switches back to delivery
                          }
                        });
                      },
                      deliveryEnabled: _room?.deliveryEnabled ?? true,
                      deliveryFee: _room?.deliveryFee ?? 50.0,
                    ),

                    SizedBox(height: 16),

                    // Address Input (only show if delivery is selected)
                    if (_deliveryType == 'delivery')
                      AddressInputWidget(
                        initialAddress: _deliveryAddress,
                        onAddressChanged: (address) {
                          setState(() {
                            _deliveryAddress = address;
                          });
                        },
                        isRequired: true,
                      ),

                    SizedBox(height: 16),

                    // Order Summary
                    OrderSummaryWidget(
                      items: widget.items,
                      subtotal: _subtotal,
                      deliveryFee:
                          _deliveryType == 'delivery'
                              ? (_room?.deliveryFee ?? 50.0)
                              : 0.0,
                      total: _totalAmount,
                    ),
                  ],
                ),
              ),
            ),

            // Place Order Button
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
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
    );
  }
}
