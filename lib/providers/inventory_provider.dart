import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../models/master_sku.dart';
import '../models/order.dart';

class InventoryProvider with ChangeNotifier {
  final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;
  final String _menuCollection = 'menu_items';
  String? _currentUserId;

  void setUserId(String userId) {
    _currentUserId = userId;
  }

  // Create a menu item from a master SKU
  Future<MenuItem> createMenuItemFromSKU(
    MasterSKU sku, {
    required String roomId,
    double? overridePrice,
    int? initialStock,
    int? minimumStock,
    String? priceOverrideReason,
    DateTime? priceOverrideExpiry,
  }) async {
    final docRef = _firestore.collection(_menuCollection).doc();

    final List<PriceAdjustment> priceHistory = [];
    if (overridePrice != null && overridePrice != sku.price) {
      priceHistory.add(
        PriceAdjustment(
          timestamp: DateTime.now(),
          oldPrice: sku.price ?? 0.0,
          newPrice: overridePrice,
          reason: priceOverrideReason ?? 'Initial price override',
          userId: _currentUserId,
          expiryDate: priceOverrideExpiry,
        ),
      );
    }

    final List<StockAdjustment> stockHistory = [];
    if (initialStock != null) {
      stockHistory.add(
        StockAdjustment(
          timestamp: DateTime.now(),
          quantity: initialStock,
          reason: 'Initial stock',
          userId: _currentUserId,
        ),
      );
    }

    final menuItem = MenuItem(
      id: docRef.id,
      name: sku.name,
      description: sku.description,
      price: overridePrice ?? sku.price ?? 0.0,
      roomId: roomId,
      isAvailable: true,
      masterSkuId: sku.id,
      currentStock: initialStock,
      minimumStock: minimumStock,
      imageUrl: sku.imageUrl,
      originalPrice: sku.price,
      priceOverrideExpiry: priceOverrideExpiry,
      stockHistory: stockHistory,
      priceHistory: priceHistory,
    );

    await docRef.set(menuItem.toMap());
    notifyListeners();
    return menuItem;
  }

  // Update menu item stock with reason
  Future<void> updateStock(
    String menuItemId, {
    required int newStock,
    required String reason,
  }) async {
    final docRef = _firestore.collection(_menuCollection).doc(menuItemId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) {
        throw Exception('Menu item not found');
      }

      final currentItem = MenuItem.fromMap(doc.id, doc.data()!);
      final stockAdjustment = StockAdjustment(
        timestamp: DateTime.now(),
        quantity: newStock - (currentItem.currentStock ?? 0),
        reason: reason,
        userId: _currentUserId,
      );

      final updatedStockHistory = List<StockAdjustment>.from(
        currentItem.stockHistory,
      )..add(stockAdjustment);

      transaction.update(docRef, {
        'currentStock': newStock,
        'isAvailable': newStock > 0,
        'stockHistory': updatedStockHistory.map((e) => e.toMap()).toList(),
      });
    });

    notifyListeners();
  }

  // Update price with reason and optional expiry
  Future<void> updatePrice(
    String menuItemId, {
    required double newPrice,
    required String reason,
    DateTime? expiryDate,
  }) async {
    final docRef = _firestore.collection(_menuCollection).doc(menuItemId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) {
        throw Exception('Menu item not found');
      }

      final currentItem = MenuItem.fromMap(doc.id, doc.data()!);
      final priceAdjustment = PriceAdjustment(
        timestamp: DateTime.now(),
        oldPrice: currentItem.price,
        newPrice: newPrice,
        reason: reason,
        userId: _currentUserId,
        expiryDate: expiryDate,
      );

      final updatedPriceHistory = List<PriceAdjustment>.from(
        currentItem.priceHistory,
      )..add(priceAdjustment);

      transaction.update(docRef, {
        'price': newPrice,
        'priceOverrideExpiry': expiryDate?.toIso8601String(),
        'priceHistory': updatedPriceHistory.map((e) => e.toMap()).toList(),
      });
    });

    notifyListeners();
  }

  // Batch update stock for multiple items
  Future<void> batchUpdateStock(
    List<MapEntry<String, int>> updates, {
    required String reason,
  }) async {
    final batch = _firestore.batch();
    final timestamp = DateTime.now();

    for (final update in updates) {
      final docRef = _firestore.collection(_menuCollection).doc(update.key);
      final doc = await docRef.get();

      if (!doc.exists) continue;

      final currentItem = MenuItem.fromMap(doc.id, doc.data()!);
      final stockAdjustment = StockAdjustment(
        timestamp: timestamp,
        quantity: update.value - (currentItem.currentStock ?? 0),
        reason: reason,
        userId: _currentUserId,
      );

      final updatedStockHistory = List<StockAdjustment>.from(
        currentItem.stockHistory,
      )..add(stockAdjustment);

      batch.update(docRef, {
        'currentStock': update.value,
        'isAvailable': update.value > 0,
        'stockHistory': updatedStockHistory.map((e) => e.toMap()).toList(),
      });
    }

    await batch.commit();
    notifyListeners();
  }

  // Adjust stock based on order status changes
  Future<void> adjustStockFromOrder(
    Order order,
    String oldStatus,
    String newStatus,
  ) async {
    // Only process stock changes for specific status transitions
    final shouldDeductStock =
        oldStatus != 'completed' && newStatus == 'completed';
    final shouldRestoreStock =
        oldStatus == 'completed' && newStatus != 'completed';

    if (!shouldDeductStock && !shouldRestoreStock) return;

    // Group items by masterSkuId
    final Map<String?, List<OrderItem>> itemsByMasterSku = {};
    for (final item in order.items) {
      if (item.masterSkuId != null) {
        itemsByMasterSku.putIfAbsent(item.masterSkuId, () => []).add(item);
      }
    }

    final batch = _firestore.batch();
    final timestamp = DateTime.now();
    final reason =
        shouldDeductStock ? 'Order completed' : 'Order status reverted';

    // Process each master SKU
    for (final entry in itemsByMasterSku.entries) {
      final masterSkuId = entry.key;
      if (masterSkuId == null) continue;

      // Calculate total quantity for this SKU
      final totalQuantity = entry.value.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

      // Get all menu items using this master SKU
      final menuItemsSnapshot =
          await _firestore
              .collection(_menuCollection)
              .where('masterSkuId', isEqualTo: masterSkuId)
              .get();

      // Update each menu item's stock
      for (final doc in menuItemsSnapshot.docs) {
        final currentItem = MenuItem.fromMap(doc.id, doc.data());
        final currentStock = currentItem.currentStock ?? 0;
        final newStock =
            shouldDeductStock
                ? currentStock - totalQuantity
                : currentStock + totalQuantity;

        final stockAdjustment = StockAdjustment(
          timestamp: timestamp,
          quantity: shouldDeductStock ? -totalQuantity : totalQuantity,
          reason: reason,
          userId: _currentUserId,
        );

        final updatedStockHistory = List<StockAdjustment>.from(
          currentItem.stockHistory,
        )..add(stockAdjustment);

        batch.update(doc.reference, {
          'currentStock': newStock,
          'isAvailable': newStock > 0,
          'stockHistory': updatedStockHistory.map((e) => e.toMap()).toList(),
        });
      }
    }

    await batch.commit();
    notifyListeners();
  }

  // Get low stock items
  Stream<List<MenuItem>> streamLowStockItems() {
    return _firestore
        .collection(_menuCollection)
        .where('currentStock', isGreaterThan: 0)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
                  .where((item) => item.isLowStock)
                  .toList();
          return items;
        });
  }

  // Get out of stock items
  Stream<List<MenuItem>> streamOutOfStockItems() {
    return _firestore
        .collection(_menuCollection)
        .where('currentStock', isLessThanOrEqualTo: 0)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // Update minimum stock level
  Future<void> updateMinimumStock(String menuItemId, int minimumStock) async {
    await _firestore.collection(_menuCollection).doc(menuItemId).update({
      'minimumStock': minimumStock,
    });
    notifyListeners();
  }

  // Get menu items by master SKU
  Future<List<MenuItem>> getMenuItemsByMasterSKU(String masterSkuId) async {
    final snapshot =
        await _firestore
            .collection(_menuCollection)
            .where('masterSkuId', isEqualTo: masterSkuId)
            .get();

    return snapshot.docs
        .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
        .toList();
  }

  // Stream available menu items for a room
  Stream<List<MenuItem>> streamAvailableItems(String roomId) {
    return _firestore
        .collection(_menuCollection)
        .where('roomId', isEqualTo: roomId)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // Check and reset expired price overrides
  Future<void> checkAndResetExpiredPriceOverrides() async {
    final now = DateTime.now();
    final snapshot =
        await _firestore
            .collection(_menuCollection)
            .where('priceOverrideExpiry', isLessThan: now.toIso8601String())
            .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final item = MenuItem.fromMap(doc.id, doc.data());
      if (item.originalPrice == null) continue;

      final priceAdjustment = PriceAdjustment(
        timestamp: now,
        oldPrice: item.price,
        newPrice: item.originalPrice!,
        reason: 'Price override expired',
        userId: _currentUserId,
      );

      final updatedPriceHistory = List<PriceAdjustment>.from(item.priceHistory)
        ..add(priceAdjustment);

      batch.update(doc.reference, {
        'price': item.originalPrice,
        'priceOverrideExpiry': null,
        'priceHistory': updatedPriceHistory.map((e) => e.toMap()).toList(),
      });
    }

    await batch.commit();
    notifyListeners();
  }
}
