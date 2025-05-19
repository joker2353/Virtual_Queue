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
  final bool _isProcessingRequest = false; // New flag for individual request processing
  List<Membership> _pendingRequests = [];
  String? _error;
  final Set<String> _processingRequests = {}; // Track which requests are being processed

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
      
      // Get all pending memberships for this room
      final pendingRequestsSnapshot = await firestore
          .collection('memberships')
          .where('roomId', isEqualTo: widget.roomId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      _pendingRequests = pendingRequestsSnapshot.docs
          .map((doc) => Membership.fromMap(doc.id, doc.data()))
          .toList();
      
      // Sort by requested time
      _pendingRequests.sort((a, b) => 
        a.timestamps.requested.compareTo(b.timestamps.requested)
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
    // Add this request to processing set
    setState(() {
      _processingRequests.add(membership.id);
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.acceptJoinRequest(widget.roomId, membership.userId);
      
      // Remove from list
      setState(() {
        _pendingRequests.removeWhere((req) => req.id == membership.id);
        _processingRequests.remove(membership.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request accepted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _processingRequests.remove(membership.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRejectRequest(Membership membership) async {
    // Add this request to processing set
    setState(() {
      _processingRequests.add(membership.id);
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.rejectJoinRequest(widget.roomId, membership.userId);
      
      // Remove from list
      setState(() {
        _pendingRequests.removeWhere((req) => req.id == membership.id);
        _processingRequests.remove(membership.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() {
        _processingRequests.remove(membership.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPendingRequests,
          ),
        ],
      ),
      body: _isLoading && _pendingRequests.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _pendingRequests.isEmpty
                  ? _buildEmptyView()
                  : _buildRequestsList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error loading requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPendingRequests,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(
            'There are no pending join requests for this room.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
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
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.person, color: Colors.blue),
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
                        ),
                      ),
                      if (request.formData['email'] != null) ...[
                        SizedBox(height: 4),
                        Text(
                          request.formData['email'],
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (request.formData['phone'] != null) ...[
                        SizedBox(height: 4),
                        Text(
                          request.formData['phone'],
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                      Text(
                        'Requested on: ${_formatDate(request.timestamps.requested)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            if (request.formData['purpose'] != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purpose of Visit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      request.formData['purpose'],
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            
            Divider(),
            SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isProcessing)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: LoadingIndicator(
                        size: 20,
                        primaryColor: Colors.orange,
                        message: null,
                      ),
                    ),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _handleRejectRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Reject'),
                  ),
                  SizedBox(width: 12),
                ],
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () => _handleAcceptRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 