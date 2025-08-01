import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import '../providers/debt_provider.dart';
import '../models/customer_debt.dart';

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
  late DebtProvider _debtProvider;

  @override
  void initState() {
    super.initState();
    _debtProvider = Provider.of<DebtProvider>(context, listen: false);
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      print('Loading customers for room: ${widget.roomId}');

      // Get all customers for this room
      final customersQuery =
          await firestore.FirebaseFirestore.instance
              .collection('customers')
              .where('roomId', isEqualTo: widget.roomId)
              .get();

      print('Found ${customersQuery.docs.length} customers');
      final List<Map<String, dynamic>> customers = [];

      // Process each customer
      for (var doc in customersQuery.docs) {
        final data = doc.data();
        final phoneNumber = doc.id; // Customer ID is the phone number
        print('Processing customer: ${data['name']}, Phone: $phoneNumber');

        // Get debt using composite key (roomId_phoneNumber)
        double pendingAmount = 0.0;
        final debtId = '${widget.roomId}_$phoneNumber';
        print('Fetching debt for ID: $debtId');

        try {
          final debtDoc =
              await firestore.FirebaseFirestore.instance
                  .collection('customer_debts')
                  .doc(debtId)
                  .get();

          if (debtDoc.exists) {
            final debtData = debtDoc.data()!;
            pendingAmount = (debtData['currentDebt'] as num).toDouble();
            print('Found debt amount: $pendingAmount');
          } else {
            print('No debt record found');
          }
        } catch (debtError) {
          print('Error fetching debt: $debtError');
        }

        // Get latest order date
        DateTime? lastOrderDate;
        try {
          final latestOrder =
              await firestore.FirebaseFirestore.instance
                  .collection('orders')
                  .where('roomId', isEqualTo: widget.roomId)
                  .where('customerContact', isEqualTo: phoneNumber)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .get();

          if (latestOrder.docs.isNotEmpty) {
            lastOrderDate =
                (latestOrder.docs.first.data()['createdAt']
                        as firestore.Timestamp)
                    .toDate();
          }
        } catch (orderError) {
          print('Error fetching latest order: $orderError');
        }

        final customerData = {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'phoneNumber': phoneNumber,
          'email': data['email'],
          'pendingAmount': pendingAmount,
          'lastOrderDate': lastOrderDate,
        };

        print('Adding customer data: $customerData');
        customers.add(customerData);
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
              final contact = customer['phoneNumber'].toString().toLowerCase();
              final email = (customer['email'] ?? '').toString().toLowerCase();
              final searchLower = query.toLowerCase();
              return name.contains(searchLower) ||
                  contact.contains(searchLower) ||
                  email.contains(searchLower);
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

  void _showCustomerDetails(Map<String, dynamic> customer) async {
    print('Showing details for customer: ${customer['name']}');
    final debtId = '${widget.roomId}_${customer['phoneNumber']}';

    try {
      // Get full debt details including history
      final debtDoc =
          await firestore.FirebaseFirestore.instance
              .collection('customer_debts')
              .doc(debtId)
              .get();

      List<DebtHistory> debtHistory = [];
      List<PaymentHistory> paymentHistory = [];

      if (debtDoc.exists) {
        // Get debt history
        final debtHistoryQuery =
            await debtDoc.reference
                .collection('debt_history')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .get();

        debtHistory =
            debtHistoryQuery.docs
                .map((doc) => DebtHistory.fromMap(doc.data()))
                .toList();

        // Get payment history
        final paymentHistoryQuery =
            await debtDoc.reference
                .collection('payment_history')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .get();

        paymentHistory =
            paymentHistoryQuery.docs
                .map((doc) => PaymentHistory.fromMap(doc.id, doc.data()))
                .toList();
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(customer['name']),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone: ${customer['phoneNumber']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    if (customer['email'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Email: ${customer['email']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    SizedBox(height: 16),
                    Text(
                      'Total Baki: ৳${customer['pendingAmount'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            customer['pendingAmount'] > 0
                                ? Colors.red
                                : Colors.green,
                      ),
                    ),
                    if (customer['lastOrderDate'] != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Last Order: ${_formatDate(customer['lastOrderDate'])}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                    if (debtHistory.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Recent Debts:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...debtHistory.map(
                        (debt) => ListTile(
                          dense: true,
                          title: Text(debt.description),
                          subtitle: Text(_formatDate(debt.timestamp)),
                          trailing: Text(
                            '৳${debt.amount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                    if (paymentHistory.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Recent Payments:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...paymentHistory.map(
                        (payment) => ListTile(
                          dense: true,
                          title: Text('Payment (${payment.paymentMethod})'),
                          subtitle: Text(_formatDate(payment.timestamp)),
                          trailing: Text(
                            '৳${payment.amount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      print('Error showing customer details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading customer details'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCustomers,
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Stats
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
                    'Total Baki',
                    '৳${_customers.fold(0.0, (sum, customer) => sum + (customer['pendingAmount'] as double)).toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                final hasPendingAmount =
                    (customer['pendingAmount'] as double) > 0;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          hasPendingAmount
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                      child: Icon(
                        Icons.person,
                        color: hasPendingAmount ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(
                      customer['name'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(customer['phoneNumber']),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Baki',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '৳${customer['pendingAmount'].toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasPendingAmount ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showCustomerDetails(customer),
                  ),
                );
              },
            ),
          ),
        ],
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
      child: Column(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 32),
          SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color:
                  title.contains('Baki') && value != '৳0.00'
                      ? Colors.red
                      : Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}
