import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../models/prescription_order.dart';
import '../widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import '../providers/cache_provider.dart';

class MedicalOrderHistoryPage extends StatefulWidget {
  final String roomId;

  const MedicalOrderHistoryPage({super.key, required this.roomId});

  static void navigate(BuildContext context, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalOrderHistoryPage(roomId: roomId),
      ),
    );
  }

  @override
  _MedicalOrderHistoryPageState createState() =>
      _MedicalOrderHistoryPageState();
}

class _MedicalOrderHistoryPageState extends State<MedicalOrderHistoryPage> {
  List<PrescriptionOrder> _completedOrders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompletedOrders();
  }

  Future<void> _loadCompletedOrders() async {
    try {
      print('Loading completed prescription orders for room: ${widget.roomId}');

      // First check the cache
      final cache = Provider.of<CacheProvider>(context, listen: false);
      final cachedOrders = cache.getCompletedPrescriptionOrders(widget.roomId);

      if (cachedOrders != null) {
        print('Using cached completed prescription orders');
        if (mounted) {
          setState(() {
            _completedOrders = cachedOrders;
            _isLoading = false;
            _error = null;
          });
          return;
        }
      }

      // Query prescription orders
      final querySnapshot =
          await firestore.FirebaseFirestore.instance
              .collection('prescription_orders')
              .where('roomId', isEqualTo: widget.roomId)
              .get();

      print('Query completed. Processing prescription orders...');

      if (mounted) {
        // Filter and sort in memory
        final orders =
            querySnapshot.docs
                .map((doc) => PrescriptionOrder.fromMap(doc.id, doc.data()))
                .where(
                  (order) => order.status == 'completed',
                ) // Filter in memory
                .toList()
              ..sort(
                (a, b) => // Sort in memory
                    (b.updatedAt ?? b.createdAt).compareTo(
                  a.updatedAt ?? a.createdAt,
                ),
              );

        setState(() {
          _completedOrders = orders;
          print(
            'Found ${_completedOrders.length} completed prescription orders',
          );
          _isLoading = false;
          _error = null;
        });

        // Cache the completed orders
        cache.cacheCompletedPrescriptionOrders(widget.roomId, orders);
      }
    } catch (e) {
      print('Error loading completed prescription orders: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshOrders() async {
    print('Refreshing completed prescription orders');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Clear cache before refreshing
    final cache = Provider.of<CacheProvider>(context, listen: false);
    cache.clearCompletedPrescriptionOrdersCache(widget.roomId);

    await _loadCompletedOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Prescription Order History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child:
            _isLoading
                ? Center(child: LoadingIndicator())
                : _error != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Error loading orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(_error!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshOrders,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
                : _completedOrders.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No completed orders yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Completed prescription orders will appear here',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _completedOrders.length,
                  itemBuilder: (context, index) {
                    final order = _completedOrders[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          order.customerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              'Contact: ${order.customerContact}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              'Images: ${order.prescriptionImageUrls.length}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (order.hasAudioInstructions)
                              Text(
                                'Has audio instructions',
                                style: TextStyle(color: Colors.blue.shade600),
                              ),
                            if (order.totalAmount > 0)
                              Text(
                                'Amount: ৳${order.totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Text(
                              'Completed: ${_formatDate(order.updatedAt ?? order.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () => _showOrderDetails(order),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  void _showOrderDetails(PrescriptionOrder order) {
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
                        'Prescription Order Details',
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
                  Text(
                    'Completed: ${_formatDate(order.updatedAt ?? order.createdAt)}',
                  ),
                  SizedBox(height: 16),

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
                ],
              ),
            ),
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
