import 'package:flutter/material.dart';
import '../models/order.dart';

class CartItemCard extends StatelessWidget {
  final OrderItem item;
  final TextEditingController notesController;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;
  final Function(String) onNotesChanged;

  const CartItemCard({
    Key? key,
    required this.item,
    required this.notesController,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onNotesChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  onPressed: onRemove,
                  tooltip: 'Remove item',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Quantity: '),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      final newQuantity = int.tryParse(value);
                      if (newQuantity != null && newQuantity > 0) {
                        onQuantityChanged(newQuantity);
                      }
                    },
                  ),
                ),
                if (item.unitPrice != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Price: ৳${(item.unitPrice! * item.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                hintText: 'Add notes (optional)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: onNotesChanged,
            ),
          ],
        ),
      ),
    );
  }
}
