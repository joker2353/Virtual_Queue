import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../models/room.dart';
import '../models/order.dart';
import '../widgets/loading_indicator.dart';
import 'shop_order_page.dart';
import 'purchase_history_page.dart';
import 'package:provider/provider.dart';
import '../providers/cache_provider.dart';

class CustomerPage extends StatefulWidget {
  final String roomId;
  final String customerName;
  final String customerContact;

  const CustomerPage({
    super.key,
    required this.roomId,
    required this.customerName,
    required this.customerContact,
  });

  static void navigate(
    BuildContext context,
    String roomId,
    String customerName,
    String customerContact,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CustomerPage(
              roomId: roomId,
              customerName: customerName,
              customerContact: customerContact,
            ),
      ),
    );
  }

  @override
  _CustomerPageState createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  Room? _room;
  List<Order> _recentOrders = [];
  double _pendingAmount = 0;
  bool _isLoading = true;
  String? _error;
  bool _showQR = false;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _customerDataSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    print('Disposing CustomerPage - cleaning up listeners');
    _ordersSubscription?.cancel();
    _customerDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      print('Initializing customer page for room: ${widget.roomId}');
      print('Customer contact: ${widget.customerContact}');

      // First load the room data
      await _loadRoom();

      // Then set up the listeners
      _setupCustomerDataListener();
      _setupOrdersListener();

      // Update loading state after everything is set up
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in initialize: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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

      if (mounted) {
        setState(() {
          _room = Room.fromMap(widget.roomId, roomDoc.data()!);
        });
      }
    } catch (e) {
      print('Error loading room: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
      throw e; // Re-throw to be caught by _initialize
    }
  }

  void _setupCustomerDataListener() {
    try {
      print('Setting up customer data listener for: ${widget.customerContact}');

      _customerDataSubscription = firestore.FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerContact)
          .snapshots()
          .listen(
            (snapshot) {
              print('Received customer data update');
              if (mounted) {
                setState(() {
                  _pendingAmount =
                      (snapshot.data()?['pendingAmount'] ?? 0).toDouble();
                });
              }
            },
            onError: (error) {
              print('Error in customer data listener: $error');
              if (mounted) {
                setState(() {
                  _error = error.toString();
                  _isLoading = false;
                });
              }
            },
          );
    } catch (e) {
      print('Error setting up customer data listener: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setupOrdersListener() {
    try {
      print(
        'Setting up orders listener for customer: ${widget.customerContact}',
      );

      // First check the cache
      final cache = Provider.of<CacheProvider>(context, listen: false);
      final cachedOrders = cache.getCustomerOrders(widget.customerContact);

      if (cachedOrders != null) {
        print('Using cached orders');
        if (mounted) {
          setState(() {
            _recentOrders = cachedOrders;
            _isLoading = false;
            _error = null;
          });
        }
      }

      // Query orders for this customer in this room
      final ordersQuery = firestore.FirebaseFirestore.instance
          .collection('orders')
          .where('customerContact', isEqualTo: widget.customerContact)
          .where('roomId', isEqualTo: widget.roomId);

      print('Executing Firestore query...');

      _ordersSubscription = ordersQuery.snapshots().listen(
        (snapshot) {
          print(
            'Received orders snapshot. Document count: ${snapshot.docs.length}',
          );

          if (snapshot.docs.isEmpty) {
            print('No orders found in snapshot');
            if (mounted) {
              setState(() {
                _recentOrders = [];
                _isLoading = false;
                _error = null;
              });
              // Update cache with empty list
              cache.cacheCustomerOrders(widget.customerContact, []);
            }
          } else {
            List<Order> validOrders = [];

            for (var doc in snapshot.docs) {
              try {
                final order = Order.fromMap(doc.id, doc.data());
                validOrders.add(order);
                print('Successfully parsed order: ${doc.id}');
              } catch (e) {
                print('Error parsing order ${doc.id}: $e');
                continue;
              }
            }

            // Sort orders by date
            validOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (mounted) {
              setState(() {
                _recentOrders = validOrders;
                _isLoading = false;
                _error = null;
              });
              // Update cache with new orders
              cache.cacheCustomerOrders(widget.customerContact, validOrders);
            }
          }
        },
        onError: (error) {
          print('Error in orders listener: $error');
          if (mounted) {
            setState(() {
              _error = 'Failed to load orders. Please try again later.';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Error setting up orders listener: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
        title: Text(_room!.name),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
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
            // QR Code (Collapsible)
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
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    QrImageView(
                      data: _room!.code,
                      version: QrVersions.auto,
                      size: 150,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                    ),
                  ],
                ),
              ),

            // Pending Amount Card
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Payment',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '৳${_pendingAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _pendingAmount > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          _pendingAmount > 0
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _pendingAmount > 0
                          ? Icons.account_balance_wallet
                          : Icons.check_circle,
                      color: _pendingAmount > 0 ? Colors.red : Colors.green,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToPlaceOrder(),
                        icon: Icon(Icons.shopping_cart),
                        label: Text(
                          'Place Order',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToPurchaseHistory(),
                        icon: Icon(Icons.history),
                        label: Text('History', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.deepPurple),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Recent Orders List
            Expanded(
              child: Container(
                margin: EdgeInsets.all(16),
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
                            'Recent Orders',
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
                          _recentOrders.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No orders yet',
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
                                itemCount: _recentOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _recentOrders[index];
                                  final statusColor = _getStatusColor(
                                    order.status,
                                  );

                                  return Card(
                                    margin: EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          contentPadding: EdgeInsets.all(16),
                                          leading: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _getStatusIcon(order.status),
                                              color: statusColor,
                                            ),
                                          ),
                                          title: Text(
                                            'Order #${order.id.substring(0, 8)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 4),
                                              Text(
                                                '${order.items.length} items',
                                              ),
                                              Text(
                                                _formatDate(order.createdAt),
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _getStatusText(order.status),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (order.isReadyForPickup ||
                                            order.isCompleted)
                                          Container(
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.only(
                                                bottomLeft: Radius.circular(12),
                                                bottomRight: Radius.circular(
                                                  12,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Total Amount:',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  '৳${order.totalAmount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.deepPurple,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.green.shade600;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'processing':
        return Icons.sync;
      case 'ready_for_pickup':
        return Icons.check_circle;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ready_for_pickup':
        return 'READY FOR PICKUP';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToPlaceOrder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ShopOrderPage(
              roomId: widget.roomId,
              customerName: widget.customerName,
              customerContact: widget.customerContact,
            ),
      ),
    );
    print('Returned from order placement - orders should update automatically');
  }

  void _navigateToPurchaseHistory() {
    PurchaseHistoryPage.navigate(
      context,
      widget.roomId,
      widget.customerName,
      widget.customerContact,
    );
  }
}
