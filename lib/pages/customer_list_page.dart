import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/loading_indicator.dart';

class CustomerListPage extends StatefulWidget {
  final String roomId;

  const CustomerListPage({super.key, required this.roomId});

  @override
  _CustomerListPageState createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final customersQuery =
          await firestore.FirebaseFirestore.instance
              .collection('customers')
              .where('roomId', isEqualTo: widget.roomId)
              .get();

      final List<Map<String, dynamic>> customers = [];
      for (var doc in customersQuery.docs) {
        final data = doc.data();
        final contact = doc.id;

        try {
          // Get the latest order for this customer without complex ordering
          final latestOrder =
              await firestore.FirebaseFirestore.instance
                  .collection('orders')
                  .where('roomId', isEqualTo: widget.roomId)
                  .where('customerContact', isEqualTo: contact)
                  .get();

          String customerName = '';
          DateTime? lastOrderDate;

          if (latestOrder.docs.isNotEmpty) {
            // Sort in memory instead of using Firestore ordering
            final sortedOrders =
                latestOrder.docs
                    .map(
                      (doc) => {
                        'data': doc.data(),
                        'createdAt':
                            (doc.data()['createdAt'] as firestore.Timestamp)
                                .toDate(),
                      },
                    )
                    .toList()
                  ..sort(
                    (a, b) => (b['createdAt'] as DateTime).compareTo(
                      a['createdAt'] as DateTime,
                    ),
                  );

            if (sortedOrders.isNotEmpty) {
              final firstOrder = sortedOrders.first;
              customerName =
                  (firstOrder['data'] as Map<String, dynamic>)['customerName']
                      ?.toString() ??
                  '';
              lastOrderDate = firstOrder['createdAt'] as DateTime;
            }
          }

          customers.add({
            'contact': contact,
            'name': customerName,
            'pendingAmount': (data['pendingAmount'] ?? 0).toDouble(),
            'lastOrderDate': lastOrderDate,
          });
        } catch (orderError) {
          print('Error loading orders for customer $contact: $orderError');
          // Add customer even if we can't load their orders
          customers.add({
            'contact': contact,
            'name': 'Unknown',
            'pendingAmount': (data['pendingAmount'] ?? 0).toDouble(),
            'lastOrderDate': null,
          });
        }
      }

      // Sort customers by pending amount (highest first)
      customers.sort(
        (a, b) => (b['pendingAmount'] as double).compareTo(
          a['pendingAmount'] as double,
        ),
      );

      if (mounted) {
        setState(() {
          _customers = customers;
          _filteredCustomers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading customers: $e');
      if (mounted) {
        setState(() {
          _error =
              'Unable to load customers. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers =
            _customers.where((customer) {
              final name = customer['name'].toString().toLowerCase();
              final contact = customer['contact'].toString().toLowerCase();
              final searchLower = query.toLowerCase();
              return name.contains(searchLower) ||
                  contact.contains(searchLower);
            }).toList();
      }
    });
  }

  Future<void> _callCustomer(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No orders yet';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Customer List'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(child: LoadingIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Customer List'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCustomers,
                child: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Customer List'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
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
            // Search Bar
            Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterCustomers,
                decoration: InputDecoration(
                  hintText: 'Search by name or contact',
                  prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),

            // Customer Stats
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Customers',
                      _customers.length.toString(),
                      Icons.people,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Total Pending',
                      '৳${_customers.fold(0.0, (sum, customer) => sum + (customer['pendingAmount'] as double)).toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),
            ),

            // Customers List
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
                child:
                    _filteredCustomers.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No customers found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          padding: EdgeInsets.all(8),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            final hasPendingAmount =
                                (customer['pendingAmount'] as double) > 0;

                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      hasPendingAmount
                                          ? Colors.red.shade50
                                          : Colors.green.shade50,
                                  child: Icon(
                                    Icons.person,
                                    color:
                                        hasPendingAmount
                                            ? Colors.red
                                            : Colors.green,
                                  ),
                                ),
                                title: Text(
                                  customer['name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer['contact'],
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Last Order: ${_formatDate(customer['lastOrderDate'])}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Pending',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '৳${customer['pendingAmount'].toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                hasPendingAmount
                                                    ? Colors.red
                                                    : Colors.green,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 16),
                                    IconButton(
                                      icon: Icon(Icons.phone),
                                      color: Colors.deepPurple,
                                      onPressed:
                                          () => _callCustomer(
                                            customer['contact'],
                                          ),
                                      tooltip: 'Call customer',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 24),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
