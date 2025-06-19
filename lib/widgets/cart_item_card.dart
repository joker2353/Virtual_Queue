import 'package:flutter/material.dart';
import '../models/order.dart';

class CartItemCard extends StatelessWidget {
  final OrderItem item;
  final TextEditingController notesController;
  final VoidCallback onRemove;
  final Function(String) onQuantityChanged;
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  onPressed: onRemove,
                  tooltip: 'Remove item',
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text('Quantity: '),
                SizedBox(width: 8),
                Container(
                  width: 60,
                  child: TextFormField(
                    initialValue: item.quantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: onQuantityChanged,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                hintText: 'Add notes (optional)',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
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
