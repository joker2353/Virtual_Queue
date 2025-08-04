import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'dart:async';
import '../providers/debt_provider.dart';
import '../models/room.dart';
import '../models/prescription_order.dart';
import '../widgets/loading_indicator.dart';
import 'join_requests_page.dart';
import 'customer_list_page.dart';
import 'medical_order_history_page.dart';
import '../widgets/qr_share_dialog.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'inbox_page.dart';

class MedicalDashboardPage extends StatefulWidget {
  final String roomId;

  const MedicalDashboardPage({super.key, required this.roomId});

  static void navigate(BuildContext context, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalDashboardPage(roomId: roomId),
      ),
    );
  }

  @override
  _MedicalDashboardPageState createState() => _MedicalDashboardPageState();
}

class _MedicalDashboardPageState extends State<MedicalDashboardPage> {
  Room? _room;
  List<PrescriptionOrder> _activeOrders = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _debtsSubscription;
  bool _showQR = false;
  double _totalSales = 0;
  double _totalPendingDebts = 0;
  FlutterSoundPlayer? _audioPlayer;
  late DebtProvider _debtProvider;

  @override
  void initState() {
    super.initState();
    _debtProvider = Provider.of<DebtProvider>(context, listen: false);
    _audioPlayer = FlutterSoundPlayer();
    _audioPlayer!.openPlayer().then((_) {
      print('Audio player initialized');
    });

    _initialize();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _debtsSubscription?.cancel();
    _audioPlayer?.closePlayer();
    super.dispose();
  }

  Future<void> _initialize() async {
    print('Initializing medical dashboard for room: ${widget.roomId}');
    try {
      await _loadRoom();
      if (_room != null) {
        _setupOrdersListener();
        _setupDebtsListener();
      }
    } catch (e) {
      print('Error initializing medical dashboard: $e');
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

      print('Medical room loaded successfully: ${_room?.name}');
    } catch (e) {
      print('Error loading room: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setupOrdersListener() {
    try {
      // Listen to completed orders for total sales calculation
      final completedOrdersQuery = firestore.FirebaseFirestore.instance
          .collection('prescription_orders')
          .where('roomId', isEqualTo: widget.roomId)
          .where('status', isEqualTo: 'completed');

      completedOrdersQuery.snapshots().listen(
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

      // Listen to active prescription orders
      final orderQuery = firestore.FirebaseFirestore.instance
          .collection('prescription_orders')
          .where('roomId', isEqualTo: widget.roomId)
          .where(
            'status',
            whereIn: ['pending', 'processing', 'ready_for_pickup'],
          );

      _ordersSubscription = orderQuery.snapshots().listen(
        (snapshot) {
          print(
            'Received prescription orders snapshot. Document count: ${snapshot.docs.length}',
          );

          if (snapshot.docs.isEmpty) {
            if (mounted) {
              setState(() {
                _activeOrders = [];
                _isLoading = false;
                _error = null;
              });
            }
          } else {
            List<PrescriptionOrder> validOrders = [];

            for (var doc in snapshot.docs) {
              try {
                final order = PrescriptionOrder.fromMap(doc.id, doc.data());
                validOrders.add(order);
                print('Added prescription order: ${order.id}');
              } catch (e) {
                print('Error parsing prescription order ${doc.id}: $e');
                continue;
              }
            }

            // Sort orders by creation date (newest first)
            validOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (mounted) {
              setState(() {
                _activeOrders = validOrders;
                _isLoading = false;
                _error = null;
              });
            }
          }
        },
        onError: (error) {
          print('Error in prescription orders listener: $error');
          if (mounted) {
            setState(() {
              _error = error.toString();
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Error setting up prescription orders listener: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _setupDebtsListener() {
    try {
      print('Setting up debts listener for medical room: ${widget.roomId}');

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
    print('Manually refreshing prescription orders');
    await _initialize();
  }

  Future<void> _updateOrderStatus(
    PrescriptionOrder order,
    String newStatus,
  ) async {
    try {
      await firestore.FirebaseFirestore.instance
          .collection('prescription_orders')
          .doc(order.id)
          .update({
            'status': newStatus,
            'updatedAt': firestore.Timestamp.now(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error updating order status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order status'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateOrderAmount(PrescriptionOrder order) async {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Set Order Amount'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Customer: ${order.customerName}'),
                SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Total Amount',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 16),
                Text(
                  'This will mark the order as ready for pickup. Baki amount will be set during order completion.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final totalAmount = double.tryParse(amountController.text);

                  if (totalAmount != null && totalAmount > 0) {
                    try {
                      // Update order amount and mark as ready for pickup
                      await firestore.FirebaseFirestore.instance
                          .collection('prescription_orders')
                          .doc(order.id)
                          .update({
                            'totalAmount': totalAmount,
                            'status': 'ready_for_pickup',
                            'updatedAt': firestore.Timestamp.now(),
                          });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order amount set successfully'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      print('Error updating order amount: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating order amount'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid amount'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text('Set Amount'),
              ),
            ],
          ),
    );
  }

  Future<void> _completeOrder(PrescriptionOrder order) async {
    final TextEditingController paidAmountController = TextEditingController();
    bool isDebt = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Complete Order'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Customer: ${order.customerName}'),
                      Text(
                        'Total Amount: ৳${order.totalAmount.toStringAsFixed(2)}',
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: paidAmountController,
                        decoration: InputDecoration(
                          labelText: 'Paid Amount',
                          prefixText: '৳ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: isDebt,
                            onChanged: (value) {
                              setDialogState(() {
                                isDebt = value ?? false;
                              });
                            },
                          ),
                          Text('Customer will pay later (Baki)'),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final paidAmount =
                            double.tryParse(paidAmountController.text) ?? 0.0;

                        if (paidAmount >= 0 &&
                            paidAmount <= order.totalAmount) {
                          try {
                            // Update order status to completed
                            await firestore.FirebaseFirestore.instance
                                .collection('prescription_orders')
                                .doc(order.id)
                                .update({
                                  'status': 'completed',
                                  'updatedAt': firestore.Timestamp.now(),
                                });

                            // Handle debt if applicable
                            if (isDebt || paidAmount < order.totalAmount) {
                              final debtAmount = order.totalAmount - paidAmount;
                              if (debtAmount > 0) {
                                await _debtProvider
                                    .addDebtFromPrescriptionOrder(
                                      order,
                                      debtAmount,
                                    );
                              }
                            }

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order completed successfully'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            print('Error completing order: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error completing order'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Paid amount cannot exceed total amount',
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Text('Complete Order'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showPrescriptionDetails(PrescriptionOrder order) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Prescription Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text('Customer: ${order.customerName}'),
                  Text('Contact: ${order.customerContact}'),
                  Text('Status: ${order.status.toUpperCase()}'),
                  Text('Amount: ৳${order.totalAmount.toStringAsFixed(2)}'),
                  SizedBox(height: 16),

                  // Audio instructions section
                  if (order.hasAudioInstructions) ...[
                    Text(
                      'Audio Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await _audioPlayer!.startPlayer(
                                fromURI: order.audioInstructionUrl!,
                                whenFinished: () {
                                  print('Audio playback completed');
                                },
                              );
                            } catch (e) {
                              print('Error playing audio: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error playing audio')),
                              );
                            }
                          },
                          icon: Icon(Icons.play_arrow),
                          label: Text('Play Audio'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _audioPlayer!.stopPlayer();
                          },
                          icon: Icon(Icons.stop),
                          label: Text('Stop'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],

                  // Prescription images section
                  Text(
                    'Prescription Images:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: order.prescriptionImageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Show full screen image
                            showDialog(
                              context: context,
                              builder:
                                  (context) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        order.prescriptionImageUrls[index],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                order.prescriptionImageUrls[index],
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(Icons.error, color: Colors.red),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (order.isPending)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateOrderStatus(order, 'processing');
                          },
                          child: Text('Start Processing'),
                        ),
                      if (order.isProcessing)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateOrderAmount(order);
                          },
                          child: Text('Set Amount'),
                        ),
                      if (order.isReadyForPickup)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _completeOrder(order);
                          },
                          child: Text('Complete Order'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading...'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: Center(child: LoadingIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Error'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_room!.name} - Medical',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
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
        width: MediaQuery.of(context).size.width * 0.65,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medical Shop',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  Text(
                    _room!.name,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Total Sales: ৳${_totalSales.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    'Total Baki: ৳${_totalPendingDebts.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.qr_code),
              title: Text('Share QR Code'),
              subtitle: Text('Let customers join via QR'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder:
                      (context) => QRShareDialog(
                        roomCode: _room!.code,
                        roomName: _room!.name,
                      ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('Order History'),
              subtitle: Text('View completed orders'),
              onTap: () {
                Navigator.pop(context);
                MedicalOrderHistoryPage.navigate(context, widget.roomId);
              },
            ),
            ListTile(
              leading: Icon(Icons.inbox),
              title: Text('Inbox'),
              subtitle: Text('Customer messages'),
              onTap: () {
                Navigator.pop(context);
                InboxPage.navigate(context, widget.roomId);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('Join Requests'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => JoinRequestsPage(roomId: widget.roomId),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.group),
              title: Text('Customer List'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => CustomerListPage(roomId: widget.roomId),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet),
              title: Text('Debt Management'),
              onTap: () {
                Navigator.pop(context);
                _showDebtManagementDialog();
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child: Column(
          children: [
            // Stats cards
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.teal.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Active Orders',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            Text(
                              '${_activeOrders.length}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Total Sales',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              '৳${_totalSales.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Total Baki',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            Text(
                              '৳${_totalPendingDebts.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Orders list
            Expanded(
              child:
                  _activeOrders.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_pharmacy,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No active prescription orders',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Orders will appear here when customers place them',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _activeOrders.length,
                        itemBuilder: (context, index) {
                          final order = _activeOrders[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(order.status),
                                child: Icon(
                                  Icons.local_pharmacy,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                order.customerName,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Contact: ${order.customerContact}'),
                                  Text('Status: ${order.status.toUpperCase()}'),
                                  Text(
                                    'Images: ${order.prescriptionImageUrls.length}',
                                  ),
                                  if (order.hasAudioInstructions)
                                    Text('Has audio instructions'),
                                  if (order.totalAmount > 0)
                                    Text(
                                      'Amount: ৳${order.totalAmount.toStringAsFixed(2)}',
                                    ),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward_ios),
                              onTap: () => _showPrescriptionDetails(order),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtManagementDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Debt Management'),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Pending Debts: ৳${_totalPendingDebts.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This feature allows you to manage customer debts. When customers pay later (baki), the amount is tracked here.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigate to detailed debt management page
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Debt management feature coming soon!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    child: Text('View All Debts'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
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
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
