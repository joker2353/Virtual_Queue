import 'package:flutter/material.dart';
import '../models/menu_item.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final VoidCallback onAddToCart;

  const MenuItemCard({
    Key? key,
    required this.menuItem,
    required this.onAddToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menuItem.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (menuItem.description.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      menuItem.description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                  SizedBox(height: 4),
                  Text(
                    '৳${menuItem.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (menuItem.isAvailable)
              IconButton(
                icon: Icon(Icons.add_circle),
                color: Colors.deepPurple,
                onPressed: onAddToCart,
                tooltip: 'Add to cart',
              )
            else
              Chip(
                label: Text(
                  'Not Available',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
                backgroundColor: Colors.red[50],
              ),
          ],
        ),
      ),
    );
  }
}
