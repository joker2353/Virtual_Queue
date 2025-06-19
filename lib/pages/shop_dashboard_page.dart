import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'dart:async';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import '../models/room.dart';
import '../models/order.dart';
import '../widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'join_requests_page.dart';
import 'customer_list_page.dart'; // New page for customer list
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../widgets/order_processing_dialog.dart';

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
  bool _showQR = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    print('Initializing shop dashboard for room: ${widget.roomId}');
    try {
      // First load the room data
      await _loadRoom();

      // Then set up the orders listener
      if (_room != null) {
        _setupOrdersListener();
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
      // Create the query for orders by roomId
      final orderQuery = firestore.FirebaseFirestore.instance
          .collection('orders')
          .where('roomId', isEqualTo: widget.roomId);

      // Listen to the query
      _ordersSubscription = orderQuery.snapshots().listen(
        (snapshot) {
          print('Received orders update. Count: ${snapshot.docs.length}');

          setState(() {
            _activeOrders =
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  print(
                    'Processing order: ${doc.id}, roomId: ${data['roomId']}',
                  );
                  return Order.fromMap(doc.id, data);
                }).toList();

            // Sort orders in memory instead of in query
            _activeOrders.sort((a, b) {
              // First sort by status
              if (a.status == 'pending' && b.status != 'pending') return -1;
              if (a.status != 'pending' && b.status == 'pending') return 1;
              // Then sort by creation time
              return b.createdAt.compareTo(a.createdAt);
            });
          });
        },
        onError: (error) {
          print('Error in orders listener: $error');
          // Check if the error is about missing index
          if (error.toString().contains('failed-precondition') &&
              error.toString().contains('requires an index')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Setting up database indexes. This may take a few minutes. Please wait...',
                ),
                duration: Duration(seconds: 10),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading orders. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      print('Error setting up orders listener: $e');
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshOrders() async {
    print('Manually refreshing orders');
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
          IconButton(
            icon: Icon(_showQR ? Icons.visibility_off : Icons.qr_code),
            onPressed: _toggleQRCode,
            tooltip: _showQR ? 'Hide QR Code' : 'Show QR Code',
          ),
        ],
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
                    QrImageView(
                      data: _room!.code,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.deepPurple,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.deepPurple,
                      ),
                      embeddedImage: const AssetImage('assets/icon/icon.png'),
                      embeddedImageStyle: QrEmbeddedImageStyle(
                        size: const Size(40, 40),
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
                    child: _buildStatCard(
                      'Active Orders',
                      _activeOrders.length.toString(),
                      Icons.receipt_long,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Total Pending',
                      '৳${_calculateTotalPending().toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
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

  double _calculateTotalPending() {
    double totalPending = 0;
    for (var order in _activeOrders) {
      if (order.status == 'pending') {
        totalPending += order.totalAmount;
      }
    }
    return totalPending;
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Handle card tap
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.deepPurple),
              SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
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
}
