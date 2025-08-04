import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'dart:async';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/debt_provider.dart';
import '../models/room.dart';
import '../models/order.dart';
import '../models/customer_debt.dart';
import '../widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'join_requests_page.dart';
import 'customer_list_page.dart'; // New page for customer list
import 'order_history_page.dart';
import 'inventory_management_page.dart'; // Add this import
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../widgets/order_processing_dialog.dart';
import '../providers/cache_provider.dart';
import '../widgets/qr_share_dialog.dart';
import 'inbox_page.dart';

class ShopDashboardPage extends StatefulWidget {
  final String roomId;

  const ShopDashboardPage({super.key, required this.roomId});

  static void navigate(BuildContext context, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDashboardPage(roomId: roomId),
      ),
    );
  }

  @override
  _ShopDashboardPageState createState() => _ShopDashboardPageState();
}

class _ShopDashboardPageState extends State<ShopDashboardPage> {
  Room? _room;
  List<Order> _activeOrders = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _debtsSubscription;
  bool _showQR = false;
  double _totalSales = 0;
  double _totalPendingDebts = 0;
  late DebtProvider _debtProvider;

  @override
  void initState() {
    super.initState();
    _debtProvider = Provider.of<DebtProvider>(context, listen: false);
    _initialize();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _debtsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    print('Initializing shop dashboard for room: ${widget.roomId}');
    try {
      // First load the room data
      await _loadRoom();

      // Then set up the listeners
      if (_room != null) {
        _setupOrdersListener();
        _setupDebtsListener();
      }
    } catch (e) {
      print('Error initializing shop dashboard: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoom() async {
    try {
      final roomDoc =
          await firestore.FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      setState(() {
        _room = Room.fromMap(widget.roomId, roomDoc.data()!);
        _isLoading = false;
      });

      print('Room loaded successfully: ${_room?.name}');
    } catch (e) {
      print('Error loading room: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setupOrdersListener() {
    print('Setting up orders listener for room: ${widget.roomId}');

    try {
      // Create the query for all orders to calculate total sales
      final allOrdersQuery = firestore.FirebaseFirestore.instance
          .collection('orders')
          .where('roomId', isEqualTo: widget.roomId)
          .where('status', isEqualTo: 'completed');

      // Listen to all orders for total sales calculation
      allOrdersQuery.snapshots().listen(
        (snapshot) {
          if (mounted) {
            double totalSales = 0;
            for (var doc in snapshot.docs) {
              totalSales += (doc.data()['totalAmount'] ?? 0).toDouble();
            }
            setState(() {
              _totalSales = totalSales;
            });
          }
        },
        onError: (error) {
          print('Error calculating total sales: $error');
        },
      );

      // First check the cache
      final cache = Provider.of<CacheProvider>(context, listen: false);
      final cachedOrders = cache.getRoomOrders(widget.roomId);

      if (cachedOrders != null) {
        print('Using cached orders');
        if (mounted) {
          setState(() {
            _activeOrders = cachedOrders;
            _isLoading = false;
          });
        }
      }

      // Create the query for active orders (not completed or cancelled)
      final orderQuery = firestore.FirebaseFirestore.instance
          .collection('orders')
          .where('roomId', isEqualTo: widget.roomId)
          .where(
            'status',
            whereIn: ['pending', 'processing', 'ready_for_pickup'],
          );

      // Listen to the query
      _ordersSubscription = orderQuery.snapshots().listen(
        (snapshot) {
          print('Received orders update. Count: ${snapshot.docs.length}');

          if (mounted) {
            final orders =
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  print(
                    'Processing order: ${doc.id}, roomId: ${data['roomId']}',
                  );
                  return Order.fromMap(doc.id, data);
                }).toList();

            // Sort orders in memory
            orders.sort((a, b) {
              // First sort by status priority
              final statusPriority = {
                'pending': 0,
                'processing': 1,
                'ready_for_pickup': 2,
              };
              final priorityCompare = (statusPriority[a.status] ?? 3).compareTo(
                statusPriority[b.status] ?? 3,
              );
              if (priorityCompare != 0) return priorityCompare;

              // Then sort by creation time (newest first)
              return b.createdAt.compareTo(a.createdAt);
            });

            setState(() {
              _activeOrders = orders;
            });

            // Update cache with new orders
            cache.cacheRoomOrders(widget.roomId, orders);
          }
        },
        onError: (error) {
          print('Error in orders listener: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading orders: ${error.toString()}'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () {
                    // Cancel existing subscription and retry
                    _ordersSubscription?.cancel();
                    _setupOrdersListener();
                  },
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      print('Error setting up orders listener: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _setupDebtsListener() {
    try {
      print('Setting up debts listener for room: ${widget.roomId}');

      // Listen to all debts for this room
      _debtsSubscription = firestore.FirebaseFirestore.instance
          .collection('customer_debts')
          .where('roomId', isEqualTo: widget.roomId)
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                double totalPendingDebts = 0;
                for (var doc in snapshot.docs) {
                  totalPendingDebts +=
                      (doc.data()['currentDebt'] ?? 0).toDouble();
                }
                setState(() {
                  _totalPendingDebts = totalPendingDebts;
                });
              }
            },
            onError: (error) {
              print('Error in debts listener: $error');
              if (mounted) {
                setState(() {
                  _error = error.toString();
                });
              }
            },
          );
    } catch (e) {
      print('Error setting up debts listener: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _refreshOrders() async {
    print('Manually refreshing orders');
    // Clear cache before refreshing
    final cache = Provider.of<CacheProvider>(context, listen: false);
    cache.clearRoomCache(widget.roomId);
    await _initialize();
  }

  void _toggleQRCode() {
    setState(() {
      _showQR = !_showQR;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading...'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(child: LoadingIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Error'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_room!.name, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Builder(
            builder:
                (context) => IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.65, // Reduced width
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.deepPurple.shade50, Colors.white, Colors.white],
              stops: [0.0, 0.2, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.store_rounded,
                          color: Colors.deepPurple.shade700,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _room!.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shop Settings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepPurple.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    children: [
                      _buildDrawerItem(
                        icon: Icons.qr_code_rounded,
                        title: 'Share QR Code',
                        subtitle: 'Let customers join via QR',
                        onTap: () {
                          Navigator.pop(context);
                          _showQRDialog();
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.inbox_rounded,
                        title: 'Inbox',
                        subtitle: 'Customer messages',
                        onTap: () {
                          Navigator.pop(context);
                          InboxPage.navigate(context, widget.roomId);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.inventory_2_rounded,
                        title: 'Inventory',
                        subtitle: 'Manage shop items',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => InventoryManagementPage(
                                    roomId: widget.roomId,
                                  ),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.history_rounded,
                        title: 'Order History',
                        subtitle: 'View past orders',
                        onTap: () {
                          Navigator.pop(context);
                          OrderHistoryPage.navigate(context, widget.roomId);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.analytics_rounded,
                        title: 'Analytics',
                        subtitle: 'View shop statistics',
                        onTap: () {
                          // TODO: Implement analytics
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Shop Code: ${_room?.code ?? ""}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.deepPurple.shade50],
            stops: const [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            // QR Code Section (Collapsible)
            if (_showQR)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Room Code: ${_room!.code}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: QrImageView(
                        data: _room!.code,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        gapless: false,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        padding: const EdgeInsets.all(0),
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildStatCard(
                      'Active Orders',
                      _activeOrders.length.toString(),
                      Icons.receipt_long,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _buildStatCard(
                      'Total Baki',
                      '৳${_totalPendingDebts.toStringAsFixed(0)}',
                      Icons.account_balance_wallet,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _buildStatCard(
                      'Sales',
                      '৳${_totalSales.toStringAsFixed(0)}',
                      Icons.payments_rounded,
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.people,
                      label: 'Customers',
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      CustomerListPage(roomId: widget.roomId),
                            ),
                          ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.inventory,
                      label: 'Inventory',
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => InventoryManagementPage(
                                    roomId: widget.roomId,
                                  ),
                            ),
                          ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.person_add,
                      label: 'Requests',
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      JoinRequestsPage(roomId: widget.roomId),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),

            // Orders List
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            'Active Orders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _activeOrders.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No active orders',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _activeOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _activeOrders[index];
                                  return _buildOrderCard(order);
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        order.customerContact,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 24),
              Text(
                'Items:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              ...order.items.map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity}x ${item.name}',
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              if (order.status != 'pending' && order.totalAmount > 0)
                Column(
                  children: [
                    Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '৳${order.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => OrderProcessingDialog(order: order),
    ).then((updated) {
      if (updated == true) {
        // Refresh data if needed
        setState(() {});
      }
    });
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Handle card tap
        },
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.deepPurple),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder:
          (context) =>
              QRShareDialog(roomCode: _room!.code, roomName: _room!.name),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: Colors.deepPurple.withOpacity(0.05),
          minLeadingWidth: 0,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Colors.deepPurple.withOpacity(0.5),
            size: 20,
          ),
        ),
      ),
    );
  }
}
