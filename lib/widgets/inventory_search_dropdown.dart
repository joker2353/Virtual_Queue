import 'package:flutter/material.dart';
import '../models/menu_item.dart';

class InventorySearchDropdown extends StatelessWidget {
  final List<MenuItem> searchResults;
  final bool isLoading;
  final Function(MenuItem) onItemSelected;
  final bool showDropdown;

  const InventorySearchDropdown({
    Key? key,
    required this.searchResults,
    required this.isLoading,
    required this.onItemSelected,
    this.showDropdown = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showDropdown) {
      return SizedBox.shrink();
    }

    if (isLoading) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Searching...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'No items found',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final item = searchResults[index];
          final isAvailable =
              item.currentStock != null && item.currentStock! > 0;

          return ListTile(
            dense: true,
            title: Text(
              item.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isAvailable ? Colors.black87 : Colors.grey[600],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '৳${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Stock: ${item.currentStock ?? 0}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAvailable ? Colors.green[600] : Colors.red[600],
                  ),
                ),
              ],
            ),
            trailing:
                isAvailable
                    ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                    : Icon(Icons.cancel, color: Colors.red, size: 20),
            onTap: isAvailable ? () => onItemSelected(item) : null,
            tileColor: isAvailable ? null : Colors.grey[50],
          );
        },
      ),
    );
  }
}
