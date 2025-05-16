import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../models/room.dart';
import '../models/membership.dart';
import '../widgets/loading_indicator.dart';
import 'join_requests_page.dart';

class CreatorDashboardPage extends StatefulWidget {
  final String roomId;

  const CreatorDashboardPage({super.key, required this.roomId});

  @override
  _CreatorDashboardPageState createState() => _CreatorDashboardPageState();
}

class _CreatorDashboardPageState extends State<CreatorDashboardPage> {
  bool _isLoading = false;
  Room? _room;
  List<Membership> _activeMembers = [];
  int _pendingRequestsCount = 0;
  String? _error;
  
  // Stream subscriptions
  late Stream<DocumentSnapshot> _roomStream;
  late Stream<QuerySnapshot> _membersStream;
  late Stream<QuerySnapshot> _requestsStream;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _setupStreams() {
    final firestore = FirebaseFirestore.instance;
    
    // Room data stream
    _roomStream = firestore.collection('rooms').doc(widget.roomId).snapshots();
    
    // Active members stream
    _membersStream = firestore
        .collection('memberships')
        .where('roomId', isEqualTo: widget.roomId)
        .where('status', isEqualTo: 'active')
        .snapshots();
    
    // Pending requests stream
    _requestsStream = firestore
        .collection('memberships')
        .where('roomId', isEqualTo: widget.roomId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
    
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get room data
      final roomDoc = await firestore.collection('rooms').doc(widget.roomId).get();
      
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      _room = Room.fromMap(widget.roomId, roomDoc.data()!);
      
      // Get active members
      final membersSnapshot = await firestore
          .collection('memberships')
          .where('roomId', isEqualTo: widget.roomId)
          .where('status', isEqualTo: 'active')
          .get();
      
      _activeMembers = membersSnapshot.docs
          .map((doc) => Membership.fromMap(doc.id, doc.data()))
          .toList();
      
      // Sort members by position
      _activeMembers.sort((a, b) => a.position.compareTo(b.position));
      
      // Get pending requests count
      final requestsSnapshot = await firestore
          .collection('memberships')
          .where('roomId', isEqualTo: widget.roomId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      _pendingRequestsCount = requestsSnapshot.docs.length;
      
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

  Future<void> _advanceQueue() async {
    if (_room == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.advanceQueue(widget.roomId);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _decreaseQueue() async {
    if (_room == null || _room!.currentPosition <= 0) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.decreaseQueue(widget.roomId);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetQueue() async {
    if (_room == null) return;
    
    // Ask for confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Queue'),
        content: Text('Are you sure you want to reset the queue to position 1? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.resetQueue(widget.roomId);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNotice() async {
    if (_room == null) return;
    
    final noticeController = TextEditingController(text: _room!.notice);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Notice'),
        content: TextField(
          controller: noticeController,
          decoration: InputDecoration(
            hintText: 'Enter notice for members',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noticeController.text),
            child: Text('Update'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final roomProvider = Provider.of<RoomProvider>(context, listen: false);
        await roomProvider.updateNotice(widget.roomId, result);
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _room == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Dashboard')),
        body: Center(child: LoadingIndicator(
          message: 'Loading dashboard...',
        )),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error loading room',
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
                onPressed: _loadInitialData,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Room Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadInitialData,
          ),
        ],
      ),
      body: _isLoading && _room == null
          ? Center(child: LoadingIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _roomStream,
              initialData: null,
              builder: (context, roomSnapshot) {
                if (!roomSnapshot.hasData && _room == null) {
                  return Center(child: LoadingIndicator(
                    message: 'Loading room data...',
                  ));
                }
                
                // Use the latest room data from stream or fallback to initial data
                final Room room = roomSnapshot.hasData && roomSnapshot.data!.exists
                    ? Room.fromMap(widget.roomId, roomSnapshot.data!.data() as Map<String, dynamic>)
                    : _room!;
                
                return StreamBuilder<QuerySnapshot>(
                  stream: _membersStream,
                  builder: (context, membersSnapshot) {
                    // Process active members
                    List<Membership> activeMembers = _activeMembers;
                    if (membersSnapshot.hasData) {
                      activeMembers = membersSnapshot.data!.docs
                          .map((doc) => Membership.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                          .toList();
                      activeMembers.sort((a, b) => a.position.compareTo(b.position));
                    }
                    
                    return StreamBuilder<QuerySnapshot>(
                      stream: _requestsStream,
                      builder: (context, requestsSnapshot) {
                        // Process pending requests count
                        int pendingCount = _pendingRequestsCount;
                        if (requestsSnapshot.hasData) {
                          pendingCount = requestsSnapshot.data!.docs.length;
                        }
                        
                        return RefreshIndicator(
                          onRefresh: _loadInitialData,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRoomHeader(room),
                                SizedBox(height: 24),
                                _buildStatsSection(room, pendingCount),
                                SizedBox(height: 24),
                                _buildQueueControls(room),
                                SizedBox(height: 24),
                                _buildMembersList(activeMembers, room),
                                SizedBox(height: 24),
                                _buildPendingRequests(pendingCount),
                                SizedBox(height: 24),
                                _buildNoticeBoard(room),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildRoomHeader(Room room) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.meeting_room, color: Colors.deepPurple),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    room.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CODE: ${room.code}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            Text(
              'Room Capacity: ${room.capacity}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Created on: ${_formatDate(room.createdAt)}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(Room room, int pendingCount) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Members',
            '${room.memberCount}',
            Icons.people,
            Colors.blue,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Current Position',
            '${room.currentPosition}',
            Icons.queue,
            Colors.green,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pending Requests',
            '$pendingCount',
            Icons.person_add,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueControls(Room room) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Queue Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildControlButton(
                  'Decrease',
                  Icons.remove_circle,
                  Colors.orange,
                  onPressed: room.currentPosition > 0 ? _decreaseQueue : null,
                ),
                _buildControlButton(
                  'Next',
                  Icons.play_circle_filled,
                  Colors.green,
                  onPressed: _advanceQueue,
                ),
                _buildControlButton(
                  'Reset',
                  Icons.restart_alt,
                  Colors.red,
                  onPressed: _resetQueue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(List<Membership> activeMembers, Room room) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            if (activeMembers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No active members in this room',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: activeMembers.length,
                itemBuilder: (context, index) {
                  final member = activeMembers[index];
                  final isBeingServed = member.position == room.currentPosition;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isBeingServed ? Colors.green[100] : Colors.blue[100],
                      child: Icon(
                        Icons.person,
                        color: isBeingServed ? Colors.green : Colors.blue,
                      ),
                    ),
                    title: Text(
                      member.formData['name'] ?? 'Unknown Member',
                      style: TextStyle(
                        fontWeight: isBeingServed ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('Position: ${member.position}'),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isBeingServed ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBeingServed ? Colors.green : Colors.grey,
                        ),
                      ),
                      child: Text(
                        isBeingServed ? 'Current' : 'Waiting',
                        style: TextStyle(
                          color: isBeingServed ? Colors.green[800] : Colors.grey[800],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequests(int pendingCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JoinRequestsPage(roomId: widget.roomId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.person_add,
                color: Colors.orange,
                size: 24,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Join Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount people waiting for approval'
                          : 'No pending requests',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeBoard(Room room) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notice Board',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: _updateNotice,
                  tooltip: 'Edit Notice',
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Text(
                room.notice.isNotEmpty
                    ? room.notice
                    : 'No notice available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.amber[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    String label,
    IconData icon,
    Color color, {
    VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: CircleBorder(),
            padding: EdgeInsets.all(16),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),
        SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
