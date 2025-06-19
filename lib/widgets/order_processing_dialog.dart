import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../models/order.dart';

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
    setState(() => _isProcessing = true);

    try {
      final orderRef = firestore.FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id);

      double finalAmount = widget.order.totalAmount;

      if (markAsCompleted) {
        // Add baki amount to the previous total
        finalAmount =
            widget.order.totalAmount + double.parse(_bakiAmountController.text);
      } else if (markAsReady) {
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
      );

      await orderRef.update(updatedOrder.toMap());

      // If there's a baki amount, update the customer's pending amount
      if (markAsCompleted && double.parse(_bakiAmountController.text) > 0) {
        final customerRef = firestore.FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.order.customerContact);

        await customerRef.set({
          'pendingAmount': firestore.FieldValue.increment(
            double.parse(_bakiAmountController.text),
          ),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
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
    final allItemsChecked = _items.every((item) => item.isChecked);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    widget.order.isReadyForPickup
                        ? 'Complete Order'
                        : 'Process Order',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Order #${widget.order.id.substring(0, 8)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              Divider(height: 24),
              if (!widget.order.isReadyForPickup) ...[
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          item.isChecked
                              ? (item.isAvailable
                                  ? Colors.green.shade50
                                  : Colors.red.shade50)
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            item.isChecked
                                ? (item.isAvailable
                                    ? Colors.green.shade200
                                    : Colors.red.shade200)
                                : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                item.quantity,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              if (item.notes?.isNotEmpty ?? false)
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    item.notes!,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!item.isChecked) ...[
                          IconButton(
                            icon: Icon(Icons.check_circle_outline),
                            color: Colors.green,
                            onPressed:
                                () => _toggleItemAvailability(index, true),
                            tooltip: 'Mark as available',
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel_outlined),
                            color: Colors.red,
                            onPressed:
                                () => _toggleItemAvailability(index, false),
                            tooltip: 'Mark as unavailable',
                          ),
                        ] else
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  item.isAvailable
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                color:
                                    item.isAvailable
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                if (allItemsChecked) ...[
                  SizedBox(height: 16),
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
                // Show completion UI when order is ready for pickup
                Text(
                  'Previous Total Amount: ৳${widget.order.totalAmount.toStringAsFixed(2)}',
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
                    labelText: 'Additional Amount (Baki)',
                    prefixText: '৳',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Enter any additional amount to be added',
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
                    'Final Amount: ৳${(widget.order.totalAmount + double.parse(_bakiAmountController.text)).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
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
      ),
    );
  }
}
