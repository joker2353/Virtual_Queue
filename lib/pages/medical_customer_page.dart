import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'dart:async';
import '../models/room.dart';
import '../models/prescription_order.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/qr_share_dialog.dart';
import 'prescription_upload_page.dart';

class MedicalCustomerPage extends StatefulWidget {
  final String roomId;
  final String customerName;
  final String customerContact;

  const MedicalCustomerPage({
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
            (context) => MedicalCustomerPage(
              roomId: roomId,
              customerName: customerName,
              customerContact: customerContact,
            ),
      ),
    );
  }

  @override
  _MedicalCustomerPageState createState() => _MedicalCustomerPageState();
}

class _MedicalCustomerPageState extends State<MedicalCustomerPage> {
  Room? _room;
  List<PrescriptionOrder> _recentOrders = [];
  bool _isLoading = true;
  String? _error;
  bool _showQR = false;
  StreamSubscription? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    print('Disposing MedicalCustomerPage - cleaning up listeners');
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      print('Initializing medical customer page for room: ${widget.roomId}');
      print('Customer contact: ${widget.customerContact}');

      await _loadRoom();
      _setupOrdersListener();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing medical customer page: $e');
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
      print('Loading room data for: ${widget.roomId}');
      final roomDoc =
          await firestore.FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        throw Exception('Medical shop not found');
      }

      final roomData = roomDoc.data()!;
      print('Room data loaded: ${roomData['name']}');

      if (mounted) {
        setState(() {
          _room = Room.fromMap(widget.roomId, roomData);
          _error = null;
        });
      }

      print('Room loaded successfully: ${_room?.name}');
    } catch (e) {
      print('Error loading room: $e');
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
        'Setting up prescription orders listener for customer: ${widget.customerContact}',
      );

      final ordersQuery = firestore.FirebaseFirestore.instance
          .collection('prescription_orders')
          .where('customerContact', isEqualTo: widget.customerContact)
          .where('roomId', isEqualTo: widget.roomId);

      print('Executing Firestore query...');

      _ordersSubscription = ordersQuery.snapshots().listen(
        (snapshot) {
          print(
            'Received prescription orders snapshot. Document count: ${snapshot.docs.length}',
          );

          if (snapshot.docs.isEmpty) {
            print('No prescription orders found in snapshot');
            if (mounted) {
              setState(() {
                _recentOrders = [];
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
                print(
                  'Added prescription order: ${order.id}, Status: ${order.status}',
                );
              } catch (e) {
                print('Error parsing prescription order ${doc.id}: $e');
                continue;
              }
            }

            // Sort orders by creation date (newest first)
            validOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (mounted) {
              setState(() {
                _recentOrders = validOrders;
                _isLoading = false;
                _error = null;
              });
            }

            print('Updated _recentOrders with ${validOrders.length} orders');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading medical shop',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _refreshOrders, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_room!.name} - Medical',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(onPressed: _showQRDialog, icon: const Icon(Icons.qr_code)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.teal.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to ${_room!.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Medical Pharmacy',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Customer: ${widget.customerName}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Order prescription button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToUploadPrescription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.local_pharmacy, size: 28),
                    label: const Text(
                      'Upload Prescription',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Recent orders section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Prescription Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    if (_recentOrders.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          // Navigate to full order history if needed
                        },
                        child: const Text('View All'),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Orders list or empty state
                _recentOrders.isEmpty
                    ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.medical_services_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No prescription orders yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload your prescription to place your first order',
                            style: TextStyle(color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children:
                          _recentOrders.take(5).map((order) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      order.status,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(order.status),
                                    color: _getStatusColor(order.status),
                                    size: 24,
                                  ),
                                ),
                                title: const Text(
                                  'Prescription Order',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              order.status,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            _getStatusText(order.status),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Images: ${order.prescriptionImageUrls.length}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (order.hasAudioInstructions)
                                      Text(
                                        'Has audio instructions',
                                        style: TextStyle(
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                    if (order.totalAmount > 0)
                                      Text(
                                        'Amount: ₹${order.totalAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.green.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Text(
                                      _formatDate(order.createdAt),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing:
                                    order.isReadyForPickup
                                        ? Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        )
                                        : null,
                              ),
                            );
                          }).toList(),
                    ),

                const SizedBox(height: 32),
              ],
            ),
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

  void _navigateToUploadPrescription() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PrescriptionUploadPage(
              roomId: widget.roomId,
              customerName: widget.customerName,
              customerContact: widget.customerContact,
            ),
      ),
    );
    print(
      'Returned from prescription upload - orders should update automatically',
    );
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder:
          (context) => QRShareDialog(
            roomCode: _room!.code,
            roomName: '${_room!.name} - Medical',
          ),
    );
  }

  void _showLeaveConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Medical Shop'),
            content: const Text('Are you sure you want to leave this medical shop?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to previous screen
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }
}
