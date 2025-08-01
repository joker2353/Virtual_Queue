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
  final _totalAmountController = TextEditingController();
  final _bakiAmountController = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  double bakiAmount = 0.0;
  List<OrderItem> _processedItems = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.order.items);
    _totalAmountController.text = widget.order.totalAmount.toString();
    _bakiAmountController.text = '0.0';
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
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

      double finalAmount = widget.order.totalAmount;

      if (markAsCompleted) {
        // Calculate baki amount based on unpaid amount
        bakiAmount = double.parse(_bakiAmountController.text);
      } else if (markAsReady) {
        // Set the total amount when marking as ready
        finalAmount = double.parse(_totalAmountController.text);
      }

      final updatedOrder = widget.order.copyWith(
        items: _items,
        status:
            markAsCompleted
                ? 'completed'
                : (markAsReady ? 'ready_for_pickup' : 'processing'),
        totalAmount: finalAmount,
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Customer: ${widget.order.customerName}',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              'Contact: ${widget.order.customerContact}',
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 24),
            Text(
              'Items:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 12),
            ...widget.order.items.asMap().entries.map(
              (entry) => CheckboxListTile(
                value: _items[entry.key].isChecked,
                onChanged:
                    !isReadyForPickup
                        ? (bool? value) {
                          setState(() {
                            _items[entry.key] = _items[entry.key].copyWith(
                              isChecked: value ?? false,
                            );
                          });
                        }
                        : null,
                title: Text(entry.value.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity: ${entry.value.quantity}'),
                    if (entry.value.notes?.isNotEmpty ?? false)
                      Text(
                        'Notes: ${entry.value.notes}',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            if (!isReadyForPickup) ...[
              if (allItemsChecked) ...[
                TextFormField(
                  controller: _totalAmountController,
                  decoration: InputDecoration(
                    labelText: 'Total Amount',
                    prefixText: '৳',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed:
                      _isProcessing
                          ? null
                          : () => _updateOrder(markAsReady: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isProcessing
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Mark as Ready for Pickup',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
              ],
            ] else ...[
              Text(
                'Total Amount: ৳${widget.order.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _bakiAmountController,
                decoration: InputDecoration(
                  labelText: 'Unpaid Amount (Baki)',
                  prefixText: '৳',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    _isProcessing
                        ? null
                        : () => _updateOrder(markAsCompleted: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isProcessing
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          'Complete Order',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
              if (double.parse(_bakiAmountController.text) > 0) ...[
                SizedBox(height: 8),
                Text(
                  'Amount to be added to baki: ৳${double.parse(_bakiAmountController.text).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
            SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
