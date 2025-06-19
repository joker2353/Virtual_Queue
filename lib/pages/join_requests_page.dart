import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/membership.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';

class JoinRequestsPage extends StatefulWidget {
  final String roomId;

  const JoinRequestsPage({super.key, required this.roomId});

  @override
  _JoinRequestsPageState createState() => _JoinRequestsPageState();
}

class _JoinRequestsPageState extends State<JoinRequestsPage> {
  bool _isLoading = false;
  List<Membership> _pendingRequests = [];
  String? _error;
  final Set<String> _processingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final pendingRequestsSnapshot =
          await firestore
              .collection('memberships')
              .where('roomId', isEqualTo: widget.roomId)
              .where('status', isEqualTo: 'pending')
              .get();

      _pendingRequests =
          pendingRequestsSnapshot.docs
              .map((doc) => Membership.fromMap(doc.id, doc.data()))
              .toList();

      _pendingRequests.sort(
        (a, b) => a.timestamps.requested.compareTo(b.timestamps.requested),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAcceptRequest(Membership membership) async {
    setState(() {
      _processingRequests.add(membership.id);
    });

    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.acceptJoinRequest(widget.roomId, membership.userId);

      setState(() {
        _pendingRequests.removeWhere((req) => req.id == membership.id);
        _processingRequests.remove(membership.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Request accepted successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _processingRequests.remove(membership.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleRejectRequest(Membership membership) async {
    setState(() {
      _processingRequests.add(membership.id);
    });

    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.rejectJoinRequest(widget.roomId, membership.userId);

      setState(() {
        _pendingRequests.removeWhere((req) => req.id == membership.id);
        _processingRequests.remove(membership.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 12),
              Text('Request rejected'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _processingRequests.remove(membership.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Requests'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPendingRequests,
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
        child:
            _isLoading && _pendingRequests.isEmpty
                ? Center(
                  child: LoadingIndicator(
                    primaryColor: Colors.white,
                    size: 40,
                    message: 'Loading requests...',
                  ),
                )
                : _error != null
                ? _buildErrorView()
                : _pendingRequests.isEmpty
                ? _buildEmptyView()
                : _buildRequestsList(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(24),
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            SizedBox(height: 24),
            Text(
              'Error Loading Requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade300),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPendingRequests,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(24),
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'All Caught Up!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'There are no pending join requests\nfor this room at the moment.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return RefreshIndicator(
      onRefresh: _loadPendingRequests,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final request = _pendingRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(Membership request) {
    final isProcessing = _processingRequests.contains(request.id);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.formData['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                            if (request.formData['email'] != null) ...[
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    request.formData['email'],
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (request.formData['phone'] != null) ...[
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    request.formData['phone'],
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _formatDate(request.timestamps.requested),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (request.formData['purpose'] != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: Colors.deepPurple,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Purpose of Visit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            request.formData['purpose'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isProcessing)
                    Container(
                      margin: EdgeInsets.only(right: 16),
                      child: LoadingIndicator(
                        size: 24,
                        primaryColor: Colors.deepPurple,
                      ),
                    )
                  else ...[
                    TextButton.icon(
                      onPressed:
                          isProcessing
                              ? null
                              : () => _handleRejectRequest(request),
                      icon: Icon(Icons.close),
                      label: Text('Reject'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed:
                          isProcessing
                              ? null
                              : () => _handleAcceptRequest(request),
                      icon: Icon(Icons.check),
                      label: Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade400,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} at $hour:$minute';
  }
}
