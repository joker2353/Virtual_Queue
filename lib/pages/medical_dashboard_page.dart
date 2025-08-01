import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'dart:async';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import '../models/room.dart';
import '../models/prescription_order.dart';
import '../widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'join_requests_page.dart';
import 'customer_list_page.dart';
import 'order_history_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../providers/cache_provider.dart';
import '../widgets/qr_share_dialog.dart';
import 'package:flutter_sound/flutter_sound.dart';

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
  bool _showQR = false;
  double _totalSales = 0;
  FlutterSoundPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = FlutterSoundPlayer();
    _audioPlayer!.openPlayer().then((_) {
      print('Audio player initialized');
    });

    _initialize();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _audioPlayer?.closePlayer();
    super.dispose();
  }

  Future<void> _initialize() async {
    print('Initializing medical dashboard for room: ${widget.roomId}');
    try {
      await _loadRoom();
      if (_room != null) {
        _setupOrdersListener();
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

  Future<void> _refreshOrders() async {
    print('Manually refreshing prescription orders');
    await _initialize();
  }

  void _toggleQRCode() {
    setState(() {
      _showQR = !_showQR;
    });
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
            title: Text('Update Order Amount'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Customer: ${order.customerName}'),
                SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Total Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0) {
                    try {
                      await firestore.FirebaseFirestore.instance
                          .collection('prescription_orders')
                          .doc(order.id)
                          .update({
                            'totalAmount': amount,
                            'status': 'ready_for_pickup',
                            'updatedAt': firestore.Timestamp.now(),
                          });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order amount updated successfully'),
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
                child: Text('Update'),
              ),
            ],
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
                  Text('Amount: ₹${order.totalAmount.toStringAsFixed(2)}'),
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
                            _updateOrderStatus(order, 'completed');
                          },
                          child: Text('Mark Completed'),
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
                    'Total Sales: ₹${_totalSales.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
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
              leading: Icon(Icons.history),
              title: Text('Order History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => OrderHistoryPage(roomId: widget.roomId),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code),
              title: Text('Show QR Code'),
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
                              '₹${_totalSales.toStringAsFixed(0)}',
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
                                      'Amount: ₹${order.totalAmount.toStringAsFixed(2)}',
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
