import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/fcm_provider.dart';
import 'loading_indicator.dart';
import '../providers/debt_provider.dart';

class OrderProcessingDialog extends StatefulWidget {
  final Order order;

  const OrderProcessingDialog({super.key, required this.order});

  @override
  _OrderProcessingDialogState createState() => _OrderProcessingDialogState();
}

class _OrderProcessingDialogState extends State<OrderProcessingDialog> {
  late List<OrderItem> _items;
  final _bakiAmountController = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  double bakiAmount = 0.0;
  List<OrderItem> _processedItems = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.order.items);
    _bakiAmountController.text = '0.0';
  }

  @override
  void dispose() {
    _bakiAmountController.dispose();
    super.dispose();
  }

  Future<void> _updateOrder({
    bool markAsReady = false,
    bool markAsCompleted = false,
  }) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final orderRef = firestore.FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id);

      if (markAsCompleted) {
        // Calculate baki amount based on unpaid amount
        bakiAmount = double.parse(_bakiAmountController.text);
      }

      final updatedOrder = widget.order.copyWith(
        items: _items,
        status:
            markAsCompleted
                ? 'completed'
                : (markAsReady ? 'ready_for_pickup' : 'processing'),
        updatedAt: DateTime.now(),
        metadata: {
          ...widget.order.metadata ?? {},
          'processedItems': _processedItems,
          'bakiAmount': bakiAmount,
        },
      );

      await orderRef.update(updatedOrder.toMap());

      // If there's a baki amount, update the customer's debt using the new debt system
      if (markAsCompleted && bakiAmount > 0) {
        final debtProvider = Provider.of<DebtProvider>(context, listen: false);
        await debtProvider.addDebtFromOrder(widget.order, bakiAmount);
      }

      // Get room name for notification
      final roomDoc =
          await firestore.FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.order.roomId)
              .get();

      final String shopName = roomDoc.data()?['name'] ?? 'Shop';

      // Send notification if status is ready_for_pickup
      if (updatedOrder.status == 'ready_for_pickup') {
        final fcmProvider = Provider.of<FCMProvider>(context, listen: false);
        await fcmProvider.sendReadyForPickupNotification(
          customerContact: widget.order.customerContact,
          orderNumber: widget.order.id.substring(0, 8),
          shopName: shopName,
        );
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error updating order: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  void _toggleItemAvailability(int index, bool isAvailable) {
    setState(() {
      _items[index] = _items[index].copyWith(
        isAvailable: isAvailable,
        isChecked: true,
      );
    });

    // If this is the first item being checked, update order status to processing
    if (_items.any((item) => item.isChecked) &&
        widget.order.status == 'pending') {
      _updateOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allItemsChecked = _items.every((item) => item.isChecked);
    final bool isReadyForPickup = widget.order.status == 'ready_for_pickup';
    final bool isCompleted = widget.order.status == 'completed';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Processing',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Order #${widget.order.id.substring(0, 8)}',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Info Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Colors.deepPurple,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Customer Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Name: ${widget.order.customerName}',
                              style: TextStyle(fontSize: 15),
                            ),
                            Text(
                              'Contact: ${widget.order.customerContact}',
                              style: TextStyle(fontSize: 15),
                            ),
                            if (widget.order.deliveryType == 'delivery' &&
                                widget.order.deliveryAddress != null) ...[
                              SizedBox(height: 8),
                              Text(
                                'Delivery Address: ${widget.order.deliveryAddress}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Order Items Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  color: Colors.deepPurple,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Order Items (${widget.order.items.length})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            ...widget.order.items.asMap().entries.map(
                              (entry) => Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      _items[entry.key].isChecked
                                          ? Colors.green.shade50
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        _items[entry.key].isChecked
                                            ? Colors.green.shade200
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (!isReadyForPickup && !isCompleted)
                                      Checkbox(
                                        value: _items[entry.key].isChecked,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _items[entry.key] =
                                                _items[entry.key].copyWith(
                                                  isChecked: value ?? false,
                                                );
                                          });
                                        },
                                        activeColor: Colors.green,
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.value.name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Quantity: ${entry.value.quantity}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (entry.value.totalPrice > 0)
                                            Text(
                                              'Price: ৳${entry.value.totalPrice.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          if (entry.value.notes?.isNotEmpty ??
                                              false)
                                            Text(
                                              'Notes: ${entry.value.notes}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_items[entry.key].isChecked)
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Order Total Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calculate,
                                  color: Colors.deepPurple,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Order Summary',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Amount:',
                                  style: TextStyle(fontSize: 15),
                                ),
                                Text(
                                  '৳${widget.order.totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.order.subtotalAmount > 0 &&
                                widget.order.subtotalAmount !=
                                    widget.order.totalAmount) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Subtotal:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '৳${widget.order.subtotalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.order.deliveryFee > 0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Delivery Fee:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '৳${widget.order.deliveryFee.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Action Buttons
                    if (!isReadyForPickup && !isCompleted) ...[
                      if (allItemsChecked) ...[
                        // Mark as Ready Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isProcessing
                                    ? null
                                    : () => _updateOrder(markAsReady: true),
                            icon:
                                _isProcessing
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Icon(Icons.check_circle_outline),
                            label: Text(
                              _isProcessing
                                  ? 'Processing...'
                                  : 'Mark as Ready for Pickup',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Process Items Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isProcessing ? null : () => _updateOrder(),
                            icon:
                                _isProcessing
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Icon(Icons.play_arrow),
                            label: Text(
                              _isProcessing ? 'Processing...' : 'Process Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else if (isReadyForPickup && !isCompleted) ...[
                      // Baki Amount Input
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Payment Collection',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: _bakiAmountController,
                              decoration: InputDecoration(
                                labelText: 'Unpaid Amount (Baki)',
                                hintText: 'Enter amount not paid by customer',
                                prefixText: '৳',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(
                                  () {},
                                ); // Trigger rebuild to show baki preview
                              },
                            ),
                            if (double.tryParse(_bakiAmountController.text) !=
                                    null &&
                                double.parse(_bakiAmountController.text) >
                                    0) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange.shade700,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '৳${double.parse(_bakiAmountController.text).toStringAsFixed(2)} will be added to customer\'s debt',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Complete Order Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isProcessing
                                  ? null
                                  : () => _updateOrder(markAsCompleted: true),
                          icon:
                              _isProcessing
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Icon(Icons.done_all),
                          label: Text(
                            _isProcessing ? 'Completing...' : 'Complete Order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else if (isCompleted) ...[
                      // Order Completed Status
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order Completed',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Completed on ${_formatDate(widget.order.updatedAt ?? widget.order.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_error != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
