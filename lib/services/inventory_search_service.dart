import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item.dart';
import '../models/order.dart';

class InventorySearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search menu items by name (autocomplete)
  Future<List<MenuItem>> searchMenuItems({
    required String roomId,
    required String searchQuery,
    int limit = 10,
  }) async {
    try {
      if (searchQuery.trim().isEmpty) {
        return [];
      }

      // Search in menu_items collection
      final querySnapshot =
          await _firestore
              .collection('menu_items')
              .where('roomId', isEqualTo: roomId)
              .where('isAvailable', isEqualTo: true)
              .get();

      // Filter results locally for better performance
      final allItems =
          querySnapshot.docs
              .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
              .where(
                (item) =>
                    item.name.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    item.description.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ),
              )
              .where(
                (item) => item.currentStock != null && item.currentStock! > 0,
              )
              .take(limit)
              .toList();

      return allItems;
    } catch (e) {
      print('Error searching menu items: $e');
      return [];
    }
  }

  // Validate item availability and stock
  Future<InventoryValidationResult> validateItem({
    required String menuItemId,
    required int requestedQuantity,
  }) async {
    try {
      final docSnapshot =
          await _firestore.collection('menu_items').doc(menuItemId).get();

      if (!docSnapshot.exists) {
        return InventoryValidationResult(
          isValid: false,
          errorMessage: 'Item not found in inventory',
        );
      }

      final menuItem = MenuItem.fromMap(docSnapshot.id, docSnapshot.data()!);

      if (!menuItem.isAvailable) {
        return InventoryValidationResult(
          isValid: false,
          errorMessage: 'Item is currently unavailable',
        );
      }

      final availableStock = menuItem.currentStock ?? 0;
      if (availableStock < requestedQuantity) {
        return InventoryValidationResult(
          isValid: false,
          errorMessage:
              'Insufficient stock. Available: $availableStock, Requested: $requestedQuantity',
          availableStock: availableStock,
        );
      }

      final totalPrice = calculateItemPrice(
        unitPrice: menuItem.price,
        quantity: requestedQuantity,
      );

      return InventoryValidationResult(
        isValid: true,
        menuItem: menuItem,
        unitPrice: menuItem.price,
        availableStock: availableStock,
        totalPrice: totalPrice,
      );
    } catch (e) {
      print('Error validating item: $e');
      return InventoryValidationResult(
        isValid: false,
        errorMessage: 'Error validating item: $e',
      );
    }
  }

  // Calculate item price
  double calculateItemPrice({
    required double unitPrice,
    required int quantity,
  }) {
    return unitPrice * quantity;
  }

  // Calculate order total
  double calculateOrderTotal({
    required List<OrderItem> items,
    required double deliveryFee,
  }) {
    final subtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    return subtotal + deliveryFee;
  }

  // Validate multiple items at once
  Future<List<InventoryValidationResult>> validateItems({
    required List<OrderItem> items,
  }) async {
    final results = <InventoryValidationResult>[];

    for (final item in items) {
      if (item.menuItemId != null) {
        final result = await validateItem(
          menuItemId: item.menuItemId!,
          requestedQuantity: item.quantity,
        );
        results.add(result);
      } else {
        // For items without menuItemId (manual entries), create a valid result
        results.add(
          InventoryValidationResult(isValid: true, totalPrice: item.totalPrice),
        );
      }
    }

    return results;
  }
}

class InventoryValidationResult {
  final bool isValid;
  final String? errorMessage;
  final MenuItem? menuItem;
  final double? unitPrice;
  final int? availableStock;
  final double? totalPrice;

  InventoryValidationResult({
    required this.isValid,
    this.errorMessage,
    this.menuItem,
    this.unitPrice,
    this.availableStock,
    this.totalPrice,
  });
}
