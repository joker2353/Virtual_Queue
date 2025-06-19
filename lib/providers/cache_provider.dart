import 'package:flutter/foundation.dart';
import '../models/order.dart';

class CacheProvider extends ChangeNotifier {
  // Cache for orders by room
  final Map<String, List<Order>> _roomOrdersCache = {};
  final Map<String, DateTime> _roomOrdersLastFetch = {};

  // Cache for customer orders
  final Map<String, List<Order>> _customerOrdersCache = {};
  final Map<String, DateTime> _customerOrdersLastFetch = {};

  // Cache for completed orders
  final Map<String, List<Order>> _completedOrdersCache = {};
  final Map<String, DateTime> _completedOrdersLastFetch = {};

  // Cache expiration duration (5 minutes)
  static const cacheDuration = Duration(minutes: 5);

  // Get orders for a room from cache
  List<Order>? getRoomOrders(String roomId) {
    final lastFetch = _roomOrdersLastFetch[roomId];
    if (lastFetch == null) return null;

    if (DateTime.now().difference(lastFetch) > cacheDuration) {
      // Cache expired
      _roomOrdersCache.remove(roomId);
      _roomOrdersLastFetch.remove(roomId);
      return null;
    }

    return _roomOrdersCache[roomId];
  }

  // Store orders for a room in cache
  void cacheRoomOrders(String roomId, List<Order> orders) {
    _roomOrdersCache[roomId] = orders;
    _roomOrdersLastFetch[roomId] = DateTime.now();
    notifyListeners();
  }

  // Get orders for a customer from cache
  List<Order>? getCustomerOrders(String customerContact) {
    final lastFetch = _customerOrdersLastFetch[customerContact];
    if (lastFetch == null) return null;

    if (DateTime.now().difference(lastFetch) > cacheDuration) {
      // Cache expired
      _customerOrdersCache.remove(customerContact);
      _customerOrdersLastFetch.remove(customerContact);
      return null;
    }

    return _customerOrdersCache[customerContact];
  }

  // Store orders for a customer in cache
  void cacheCustomerOrders(String customerContact, List<Order> orders) {
    _customerOrdersCache[customerContact] = orders;
    _customerOrdersLastFetch[customerContact] = DateTime.now();
    notifyListeners();
  }

  // Get completed orders from cache
  List<Order>? getCompletedOrders(String roomId) {
    final lastFetch = _completedOrdersLastFetch[roomId];
    if (lastFetch == null) return null;

    if (DateTime.now().difference(lastFetch) > cacheDuration) {
      // Cache expired
      _completedOrdersCache.remove(roomId);
      _completedOrdersLastFetch.remove(roomId);
      return null;
    }

    return _completedOrdersCache[roomId];
  }

  // Store completed orders in cache
  void cacheCompletedOrders(String roomId, List<Order> orders) {
    _completedOrdersCache[roomId] = orders;
    _completedOrdersLastFetch[roomId] = DateTime.now();
    notifyListeners();
  }

  // Clear specific cache
  void clearRoomCache(String roomId) {
    _roomOrdersCache.remove(roomId);
    _roomOrdersLastFetch.remove(roomId);
    notifyListeners();
  }

  void clearCustomerCache(String customerContact) {
    _customerOrdersCache.remove(customerContact);
    _customerOrdersLastFetch.remove(customerContact);
    notifyListeners();
  }

  void clearCompletedOrdersCache(String roomId) {
    _completedOrdersCache.remove(roomId);
    _completedOrdersLastFetch.remove(roomId);
    notifyListeners();
  }

  // Clear all cache
  void clearAllCache() {
    _roomOrdersCache.clear();
    _roomOrdersLastFetch.clear();
    _customerOrdersCache.clear();
    _customerOrdersLastFetch.clear();
    _completedOrdersCache.clear();
    _completedOrdersLastFetch.clear();
    notifyListeners();
  }
}
