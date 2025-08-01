import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../models/room.dart';
import '../models/order.dart';
import '../models/customer_debt.dart';
import '../widgets/loading_indicator.dart';
import 'shop_order_page.dart';
import 'purchase_history_page.dart';
import 'package:provider/provider.dart';
import '../providers/cache_provider.dart';
import '../providers/debt_provider.dart';
import 'edit_order_page.dart';
import '../widgets/qr_share_dialog.dart';

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
  CustomerDebt? _customerDebt;
  bool _isLoading = true;
  String? _error;
  bool _showQR = false;
  StreamSubscription? _ordersSubscription;
  StreamSubscription<firestore.DocumentSnapshot>? _debtSubscription;
  late DebtProvider _debtProvider;
  double _totalBakiAmount = 0.0; // Add this field

  double _getBakiAmount(Order order) {
    return (order.metadata?['bakiAmount'] as num?)?.toDouble() ?? 0;
  }

  Future<void> _calculateTotalBakiAmount() async {
    try {
      // Query all completed orders for this customer in this room
      final ordersQuery =
          await firestore.FirebaseFirestore.instance
              .collection('orders')
              .where('customerContact', isEqualTo: widget.customerContact)
              .where('roomId', isEqualTo: widget.roomId)
              .where('status', isEqualTo: 'completed')
              .get();

      double totalBaki = 0.0;
      for (var doc in ordersQuery.docs) {
        try {
          final order = Order.fromMap(doc.id, doc.data());
          final bakiAmount = _getBakiAmount(order);
          totalBaki += bakiAmount;
        } catch (e) {
          print('Error parsing order ${doc.id}: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _totalBakiAmount = totalBaki;
        });
      }
    } catch (e) {
      print('Error calculating total baki amount: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _debtProvider = Provider.of<DebtProvider>(context, listen: false);
    _initialize();
  }

  @override
  void dispose() {
    print('Disposing CustomerPage - cleaning up listeners');
    _ordersSubscription?.cancel();
    _debtSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      print('Initializing customer page for room: ${widget.roomId}');
      print('Customer contact: ${widget.customerContact}');

      // First load the room data
      await _loadRoom();

      // Calculate total baki amount
      await _calculateTotalBakiAmount();

      // Then set up the listeners
      _setupDebtListener();
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

  Future<String?> _getPhoneNumberFromEmail(String email) async {
    try {
      final userQuery =
          await firestore.FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.data()['contactNumber'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting phone number from email: $e');
      return null;
    }
  }

  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<void> _setupDebtListener() async {
    try {
      print('Setting up debt listener for: ${widget.customerContact}');

      String contactToUse = widget.customerContact;
      bool isEmail = widget.customerContact.contains('@');

      // If the contact is an email, try to get the phone number
      if (isEmail) {
        print('Contact is an email, fetching phone number...');
        final phoneNumber = await _getPhoneNumberFromEmail(
          widget.customerContact,
        );
        if (phoneNumber != null) {
          print(
            'Found phone number: $phoneNumber for email: ${widget.customerContact}',
          );
          contactToUse = phoneNumber;
        } else {
          print('No phone number found for email: ${widget.customerContact}');
        }
      }

      // Normalize the phone number if it's not an email
      if (!contactToUse.contains('@')) {
        final normalizedPhone = _normalizePhoneNumber(contactToUse);
        print('Normalized phone number: $normalizedPhone from: $contactToUse');
        contactToUse = normalizedPhone;
      }

      final debtId = '${widget.roomId}_$contactToUse';
      print('Using debt ID: $debtId');

      // First try to get the current debt state
      final initialDebt = await _debtProvider.getCustomerDebt(
        widget.roomId,
        contactToUse,
      );
      if (initialDebt != null) {
        print('Found initial debt: ${initialDebt.currentDebt}');
        if (mounted) {
          setState(() {
            _customerDebt = initialDebt;
          });
        }
      }

      // Set up real-time listener
      _debtSubscription = firestore.FirebaseFirestore.instance
          .collection('customer_debts')
          .doc(debtId)
          .snapshots()
          .listen(
            (snapshot) async {
              print('Received debt data update for ID: $debtId');
              if (mounted) {
                if (snapshot.exists) {
                  print('Debt document exists, fetching history...');
                  // Get debt history and payment history
                  final debtHistoryQuery =
                      await snapshot.reference
                          .collection('debt_history')
                          .orderBy('timestamp', descending: true)
                          .limit(10)
                          .get();

                  final paymentHistoryQuery =
                      await snapshot.reference
                          .collection('payment_history')
                          .orderBy('timestamp', descending: true)
                          .limit(10)
                          .get();

                  final debt = CustomerDebt.fromMap(
                    snapshot.id,
                    snapshot.data()!,
                  ).copyWith(
                    debtHistory:
                        debtHistoryQuery.docs
                            .map((doc) => DebtHistory.fromMap(doc.data()))
                            .toList(),
                    paymentHistory:
                        paymentHistoryQuery.docs
                            .map(
                              (doc) =>
                                  PaymentHistory.fromMap(doc.id, doc.data()),
                            )
                            .toList(),
                  );

                  print('Current debt amount: ${debt.currentDebt}');
                  setState(() {
                    _customerDebt = debt;
                  });
                } else {
                  print('No debt document found for ID: $debtId');
                  // If no debt found with phone number and original contact was email,
                  // try looking up with email as fallback
                  if (isEmail && contactToUse != widget.customerContact) {
                    print('Trying fallback to email-based debt ID...');
                    final emailDebtId =
                        '${widget.roomId}_${widget.customerContact}';
                    final emailDebtDoc =
                        await firestore.FirebaseFirestore.instance
                            .collection('customer_debts')
                            .doc(emailDebtId)
                            .get();

                    if (emailDebtDoc.exists) {
                      print('Found old email-based debt, migrating...');
                      // Let DebtProvider handle the migration
                      await _debtProvider.getCustomerDebt(
                        widget.roomId,
                        widget.customerContact,
                      );
                      // The migration will trigger a new snapshot with the phone-based ID
                      return;
                    }
                  }

                  setState(() {
                    _customerDebt = null;
                  });
                }
              }
            },
            onError: (error) {
              print('Error in debt listener: $error');
              if (mounted) {
                setState(() {
                  _error = error.toString();
                  _isLoading = false;
                });
              }
            },
          );
    } catch (e) {
      print('Error setting up debt listener: $e');
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
                // Only add non-completed orders to the recent orders list
                if (order.status != 'completed') {
                  validOrders.add(order);
                }
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
        width: MediaQuery.of(context).size.width * 0.65,
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
                        'Customer Menu',
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
                        subtitle: 'Share shop with others',
                        onTap: () {
                          Navigator.pop(context);
                          _showQRDialog();
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.exit_to_app_rounded,
                        title: 'Leave Shop',
                        subtitle: 'Remove from saved shops',
                        onTap: () {
                          Navigator.pop(context);
                          _showLeaveConfirmation();
                        },
                        isDanger: true,
                      ),
                    ],
                  ),
                ),
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
                        size: 150,
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
                        '৳${_totalBakiAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              _totalBakiAmount > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (_totalBakiAmount > 0)
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Show payment history and record payment dialog
                      },
                      icon: Icon(Icons.payment, color: Colors.deepPurple),
                      label: Text(
                        'Record Payment',
                        style: TextStyle(color: Colors.deepPurple),
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
                                    child: InkWell(
                                      onTap: () {
                                        // Only allow editing if order is pending
                                        if (order.status == 'pending') {
                                          _navigateToEditOrder(order);
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Only pending orders can be edited',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              backgroundColor: Colors.orange,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border:
                                              order.status == 'pending'
                                                  ? Border.all(
                                                    color:
                                                        Colors
                                                            .deepPurple
                                                            .shade200,
                                                    width: 2,
                                                  )
                                                  : null,
                                        ),
                                        child: Column(
                                          children: [
                                            ListTile(
                                              contentPadding: EdgeInsets.all(
                                                16,
                                              ),
                                              leading: Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.1),
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
                                                    _formatDate(
                                                      order.createdAt,
                                                    ),
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
                                                  color: statusColor
                                                      .withOpacity(0.1),
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
                                                  borderRadius:
                                                      BorderRadius.only(
                                                        bottomLeft:
                                                            Radius.circular(12),
                                                        bottomRight:
                                                            Radius.circular(12),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.deepPurple,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
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

  void _showQRDialog() {
    showDialog(
      context: context,
      builder:
          (context) =>
              QRShareDialog(roomCode: _room!.code, roomName: _room!.name),
    );
  }

  void _showLeaveConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Leave Room'),
            content: Text('Are you sure you want to leave this room?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _leaveRoom();
                },
                child: Text('Leave', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _leaveRoom() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToEditOrder(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditOrderPage(
              roomId: widget.roomId,
              customerName: widget.customerName,
              customerContact: widget.customerContact,
              existingOrder: order,
            ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final itemColor = isDanger ? Colors.red : Colors.deepPurple;
    final bgColor =
        isDanger ? Colors.red.shade50 : Colors.deepPurple.withOpacity(0.05);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: bgColor,
          minLeadingWidth: 0,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isDanger
                      ? Colors.red.shade100
                      : Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDanger ? Colors.red.shade700 : Colors.deepPurple,
              size: 22,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isDanger ? Colors.red.shade700 : Colors.deepPurple,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: isDanger ? Colors.red.shade600 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: (isDanger ? Colors.red : Colors.deepPurple).withOpacity(0.5),
            size: 20,
          ),
        ),
      ),
    );
  }
}
