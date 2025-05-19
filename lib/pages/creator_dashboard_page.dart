import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../models/room.dart';
import '../models/membership.dart';
import '../widgets/loading_indicator.dart';
import 'join_requests_page.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;

class CreatorDashboardPage extends StatefulWidget {
  final String roomId;

  const CreatorDashboardPage({super.key, required this.roomId});

  @override
  _CreatorDashboardPageState createState() => _CreatorDashboardPageState();
}

class _CreatorDashboardPageState extends State<CreatorDashboardPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  Room? _room;
  List<Membership> _activeMembers = [];
  int _pendingRequestsCount = 0;
  String? _error;
  
  // Animation controller for UI effects
  late AnimationController _animationController;
  late Animation<double> _headerAnimation;
  
  // Stream subscriptions
  late Stream<DocumentSnapshot> _roomStream;
  late Stream<QuerySnapshot> _membersStream;
  late Stream<QuerySnapshot> _requestsStream;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuart,
      ),
    );
    
    _setupStreams();
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 5,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.amber.shade600,
                      Colors.amber.shade800,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.campaign,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Update Notice',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: noticeController,
                      decoration: InputDecoration(
                        hintText: 'Enter notice for members',
                        labelText: 'Notice Message',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.amber.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.amber.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.amber.shade600, width: 2),
                        ),
                        prefixIcon: Icon(
                          Icons.announcement,
                          color: Colors.amber.shade600,
                        ),
                        floatingLabelStyle: TextStyle(color: Colors.amber.shade700),
                      ),
                      maxLines: 4,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'This notice will be visible to all members in the queue.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, noticeController.text),
                          icon: Icon(Icons.check),
                          label: Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                          label: Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notice updated successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade800,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade800,
          ),
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
          primaryColor: Theme.of(context).colorScheme.primary,
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
      floatingActionButton: _room != null ? FloatingActionButton.extended(
        onPressed: () => _showRegisterMemberDialog(_room!),
        backgroundColor: Colors.deepPurple,
        icon: Icon(Icons.person_add_alt_1),
        label: Text('Register Member'),
        tooltip: 'Register new member',
      ) : null,
      body: _isLoading && _room == null
          ? Center(child: LoadingIndicator(
              message: 'Loading dashboard...',
              primaryColor: Theme.of(context).colorScheme.primary,
            ))
          : StreamBuilder<DocumentSnapshot>(
              stream: _roomStream,
              initialData: null,
              builder: (context, roomSnapshot) {
                if (!roomSnapshot.hasData && _room == null) {
                  return Center(child: LoadingIndicator(
                    message: 'Loading room data...',
                    primaryColor: Theme.of(context).colorScheme.primary,
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
                        
                        return NestedScrollView(
                          headerSliverBuilder: (context, innerBoxIsScrolled) {
                            return [
                              SliverAppBar(
                                expandedHeight: 180.0,
                                floating: false,
                                pinned: true,
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                flexibleSpace: FlexibleSpaceBar(
                                  centerTitle: true,
                                  title: null,
                                  background: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF673AB7), // Deep Purple
                                          Color(0xFF512DA8), // Darker purple
                                        ],
                                      ),
                                    ),
                                    child: SafeArea(
                                      child: Padding(
                                        padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 60.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Align(
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Room Dashboard',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                      blurRadius: 5.0,
                                                      color: Colors.black.withOpacity(0.3),
                                                      offset: Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Icon(Icons.meeting_room, color: Colors.white.withOpacity(0.9), size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  room.name,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white.withOpacity(0.9),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Text(
                                                  'CODE: ${room.code}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white.withOpacity(0.8),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () {
                                                    Clipboard.setData(ClipboardData(text: room.code));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Room code copied to clipboard')),
                                                    );
                                                  },
                                                  child: Icon(
                                                    Icons.copy,
                                                    size: 16,
                                                    color: Colors.white.withOpacity(0.8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ];
                          },
                          body: RefreshIndicator(
                            onRefresh: _loadInitialData,
                            color: Theme.of(context).colorScheme.primary,
                            child: SingleChildScrollView(
                              physics: BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding for FAB
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildQuickActionsBar(room),
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

  Widget _buildQuickActionsBar(Room room) {
    return Card(
      elevation: 3,
      shadowColor: Colors.deepPurple.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.deepPurple.shade100,
            ],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: Colors.deepPurple.shade800,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuickActionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'QR Code',
                  color: Colors.blue.shade700,
                  onTap: _showQRCodeDialog,
                ),
                _buildQuickActionButton(
                  icon: Icons.person_add_alt_1,
                  label: 'Register',
                  color: Colors.deepPurple,
                  onTap: () => _showRegisterMemberDialog(room),
                ),
                _buildQuickActionButton(
                  icon: Icons.campaign,
                  label: 'Notice',
                  color: Colors.amber.shade700,
                  onTap: _updateNotice,
                ),
                _buildQuickActionButton(
                  icon: Icons.person_outline,
                  label: 'Requests',
                  color: Colors.orange.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JoinRequestsPage(roomId: widget.roomId),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(Room room, int pendingCount) {
    return Container(
      margin: EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _buildStatCard(
            'Members',
            '${room.memberCount}',
            Icons.people,
            [Color(0xFF5C6BC0), Color(0xFF3949AB)],
          ),
          _buildStatCard(
            'Current Position',
            '${room.currentPosition}',
            Icons.queue,
            [Color(0xFF66BB6A), Color(0xFF388E3C)],
          ),
          _buildStatCard(
            'Pending',
            '$pendingCount',
            Icons.person_add,
            [Color(0xFFFFA726), Color(0xFFF57C00)],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          elevation: 3,
          shadowColor: gradientColors[0].withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white.withOpacity(0.9),
                  size: 28,
                ),
                SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueControls(Room room) {
    return Card(
      elevation: 3,
      shadowColor: Colors.purple.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.deepPurple.shade100,
            ],
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.queue_play_next,
                  color: Colors.deepPurple,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Queue Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(color: Colors.deepPurple.withOpacity(0.2)),
            SizedBox(height: 8),
            Text(
              'Current position: ${room.currentPosition}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.deepPurple.shade700,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnimatedControlButton(
                  'Decrease',
                  Icons.remove_circle,
                  Colors.orange.shade600,
                  Colors.orange.shade800,
                  onPressed: room.currentPosition > 0 ? _decreaseQueue : null,
                  delay: 0.2,
                ),
                _buildAnimatedControlButton(
                  'Next',
                  Icons.play_circle_filled,
                  Colors.green.shade600,
                  Colors.green.shade800,
                  onPressed: _advanceQueue,
                  delay: 0.3,
                ),
                _buildAnimatedControlButton(
                  'Reset',
                  Icons.restart_alt,
                  Colors.red.shade600,
                  Colors.red.shade800,
                  onPressed: _resetQueue,
                  delay: 0.4,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedControlButton(
    String label,
    IconData icon,
    Color startColor,
    Color endColor, {
    VoidCallback? onPressed,
    double delay = 0.0,
  }) {
    // Create a delayed animation
    final Animation<double> delayedAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        delay, // Start point of the animation
        1.0, // End point of the animation
        curve: Curves.easeOut,
      ),
    );
    
    return AnimatedBuilder(
      animation: delayedAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: delayedAnimation.value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * delayedAnimation.value),
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  shadowColor: startColor.withOpacity(0.4),
                  shape: CircleBorder(),
                  child: InkWell(
                    onTap: _isLoading ? null : onPressed,
                    customBorder: CircleBorder(),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [startColor, endColor],
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: endColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersList(List<Membership> activeMembers, Room room) {
    return Card(
      elevation: 3,
      shadowColor: Colors.blue.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue[700], size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Active Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total: ${activeMembers.length}',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (activeMembers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No active members in this room',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: activeMembers.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = activeMembers[index];
                  final isBeingServed = member.position == room.currentPosition;
                  final contactNumber = member.formData['contact'] as String? ?? 'No number';
                  
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(vertical: 6),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isBeingServed ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBeingServed ? Colors.green.withOpacity(0.3) : Colors.transparent,
                      ),
                      boxShadow: isBeingServed
                          ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isBeingServed
                                      ? [Colors.green[400]!, Colors.green[700]!]
                                      : [Colors.blue[300]!, Colors.blue[600]!],
                                ),
                              ),
                              child: Text(
                                '${member.position}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.formData['name'] ?? 'Unknown Member',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16, 
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                                      SizedBox(width: 6),
                                      Text(
                                        contactNumber,
                                        style: TextStyle(color: Colors.grey[800]),
                                      ),
                                    ],
                                  ),
                                  if (member.formData.containsKey('address') && member.formData['address'] != null) ...[
                                    SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            member.formData['address'],
                                            style: TextStyle(color: Colors.grey[800]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isBeingServed ? Colors.green : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isBeingServed ? 'Current' : 'Waiting',
                                style: TextStyle(
                                  color: isBeingServed ? Colors.white : Colors.grey[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isBeingServed) ...[
                          SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active, size: 20, color: Colors.green[700]),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Currently being served! WhatsApp notification sent.',
                                    style: TextStyle(color: Colors.green[800], fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildPendingRequests(int pendingCount) {
    return Card(
      elevation: 3,
      shadowColor: Colors.orange.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade50,
                Colors.orange.shade100,
              ],
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.shade400,
                      Colors.orange.shade700,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Join Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount people waiting for approval'
                          : 'No pending requests',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.4),
                ),
                child: Center(
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeBoard(Room room) {
    return Card(
      elevation: 3,
      shadowColor: Colors.amber.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber.shade50,
              Colors.amber.shade100,
            ],
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.campaign,
                      color: Colors.amber.shade800,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Notice Board',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  shape: CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: Colors.amber.shade800,
                    ),
                    onPressed: _updateNotice,
                    tooltip: 'Edit Notice',
                    splashColor: Colors.amber.shade200,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (room.notice.isNotEmpty) ...[
                    Text(
                      room.notice,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.amber.shade900,
                        height: 1.5,
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'No notice available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: _updateNotice,
                        icon: Icon(Icons.add),
                        label: Text('Add Notice'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber.shade800,
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

  // Dialog to register a new member
  Future<void> _showRegisterMemberDialog(Room room) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String contact = '';
    String address = '';
    bool isRegistering = false;
    String? errorMessage;
    
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss while loading
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade600,
                        Colors.deepPurple.shade900,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Register New Member',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (errorMessage != null)
                              Container(
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade800,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.deepPurple.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.deepPurple.shade800,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'For people without smartphones. They will be added directly to the queue.',
                                      style: TextStyle(
                                        color: Colors.deepPurple.shade800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Name',
                                hintText: 'Enter member name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.deepPurple.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                                ),
                                floatingLabelStyle: TextStyle(color: Colors.deepPurple),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter member name';
                                }
                                return null;
                              },
                              onSaved: (value) => name = value ?? '',
                              enabled: !isRegistering,
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Contact Number',
                                hintText: 'Enter with country code (e.g., +1234567890)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.phone, color: Colors.deepPurple),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.deepPurple.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                                ),
                                floatingLabelStyle: TextStyle(color: Colors.deepPurple),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter contact number';
                                }
                                // Basic check for country code
                                if (!value.startsWith('+')) {
                                  return 'Include country code (e.g., +1)';
                                }
                                return null;
                              },
                              onSaved: (value) => contact = value ?? '',
                              keyboardType: TextInputType.phone,
                              enabled: !isRegistering,
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Address',
                                hintText: 'Enter member address',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.home, color: Colors.deepPurple),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.deepPurple.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                                ),
                                floatingLabelStyle: TextStyle(color: Colors.deepPurple),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter member address';
                                }
                                return null;
                              },
                              onSaved: (value) => address = value ?? '',
                              maxLines: 2,
                              enabled: !isRegistering,
                            ),
                            SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: isRegistering ? null : () => Navigator.pop(context),
                                  icon: Icon(Icons.close),
                                  label: Text('Cancel'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade400),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                                SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: isRegistering ? null : () async {
                                    if (formKey.currentState!.validate()) {
                                      formKey.currentState!.save();
                                      
                                      setDialogState(() {
                                        isRegistering = true;
                                        errorMessage = null;
                                      });
                                      
                                      try {
                                        // Generate a unique ID for the customer added by the creator
                                        final uuid = Uuid();
                                        final customerId = uuid.v4(); // Generate random UUID
                                        
                                        // Register member directly using the room code
                                        final roomProvider = Provider.of<RoomProvider>(context, listen: false);
                                        await roomProvider.addCustomerByCreator(
                                          roomCode: room.code,
                                          formData: {
                                            'name': name,
                                            'contact': contact,
                                            'address': address,
                                          },
                                          customerId: customerId,
                                        );
                                        
                                        // Refresh the data
                                        _loadInitialData();
                                        
                                        // Show success message
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Member registered and added to the queue'),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: Colors.green.shade800,
                                          ),
                                        );
                                        
                                        // Close the dialog
                                        Navigator.pop(dialogContext);
                                      } catch (e) {
                                        setDialogState(() {
                                          isRegistering = false;
                                          errorMessage = e.toString();
                                        });
                                      }
                                    }
                                  },
                                  icon: isRegistering
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(Icons.check),
                                  label: Text(isRegistering ? 'Registering...' : 'Register'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this method to show QR code dialog
  void _showQRCodeDialog() {
    if (_room == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 5,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade700,
                      Colors.blue.shade900,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Room QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: QrImageView(
                          data: _room!.code,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade900,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Room Code: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            _room!.code,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade900,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _room!.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Room code copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.green.shade800,
                                ),
                              );
                            },
                            child: Icon(
                              Icons.copy,
                              size: 20,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Share this QR code with people who want to join your room.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _room!.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Room code copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green.shade800,
                              ),
                            );
                          },
                          icon: Icon(Icons.copy),
                          label: Text('Copy Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.close),
                          label: Text('Close'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
