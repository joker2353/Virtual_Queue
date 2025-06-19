import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../providers/room_provider.dart';
import '../models/room.dart';
import '../models/membership.dart';
import '../widgets/loading_indicator.dart';
import 'homepage2.dart';

class PositionDetailsPage extends StatefulWidget {
  final String roomId;
  final String memberId;
  final String phoneNumber;

  const PositionDetailsPage({
    super.key,
    required this.roomId,
    required this.memberId,
    required this.phoneNumber,
  });

  static void navigate(
    BuildContext context, {
    required String roomId,
    required String memberId,
    required String phoneNumber,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PositionDetailsPage(
              roomId: roomId,
              memberId: memberId,
              phoneNumber: phoneNumber,
            ),
      ),
    );
  }

  @override
  State<PositionDetailsPage> createState() => _PositionDetailsPageState();
}

class _PositionDetailsPageState extends State<PositionDetailsPage>
    with TickerProviderStateMixin {
  Room? _room;
  Membership? _membership;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<DocumentSnapshot>? _membershipSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load room data
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        setState(() {
          _error = 'Room not found';
          _isLoading = false;
        });
        return;
      }

      // Try to load membership data from memberships collection first
      DocumentSnapshot? membershipDoc;

      // First try: memberships collection (primary storage)
      try {
        membershipDoc =
            await FirebaseFirestore.instance
                .collection('memberships')
                .doc(widget.memberId)
                .get();

        print('📋 Trying memberships collection: ${membershipDoc.exists}');
      } catch (e) {
        print('⚠️ Error accessing memberships collection: $e');
      }

      // If not found in memberships, try subcollection
      if (membershipDoc == null || !membershipDoc.exists) {
        print('🔄 Trying subcollection...');
        try {
          membershipDoc =
              await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('members')
                  .doc(widget.memberId)
                  .get();

          print('📋 Trying subcollection: ${membershipDoc.exists}');
        } catch (e) {
          print('⚠️ Error accessing subcollection: $e');
        }
      }

      if (membershipDoc == null || !membershipDoc.exists) {
        setState(() {
          _error = 'Membership not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _room = Room.fromMap(roomDoc.id, roomDoc.data()!);
        _membership = Membership.fromMap(
          membershipDoc!.id,
          membershipDoc!.data()! as Map<String, dynamic>,
        );
        _isLoading = false;
      });

      // Set up real-time listeners
      _setupRealTimeListeners();
    } catch (e) {
      setState(() {
        _error = 'Error loading data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _setupRealTimeListeners() {
    // Listen to room changes
    _roomSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              _room = Room.fromMap(snapshot.id, snapshot.data()!);
            });
          }
        });

    // Set up membership listener - try memberships collection first
    _setupMembershipListener();
  }

  void _setupMembershipListener() {
    // Try memberships collection first
    _membershipSubscription = FirebaseFirestore.instance
        .collection('memberships')
        .doc(widget.memberId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && mounted) {
              setState(() {
                _membership = Membership.fromMap(snapshot.id, snapshot.data()!);
              });
            }
          },
          onError: (error) {
            print('⚠️ Memberships listener error: $error');
            // Fallback to subcollection listener
            _setupSubcollectionListener();
          },
        );
  }

  void _setupSubcollectionListener() {
    _membershipSubscription?.cancel();

    _membershipSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('members')
        .doc(widget.memberId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              _membership = Membership.fromMap(snapshot.id, snapshot.data()!);
            });
          }
        });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _roomSubscription?.cancel();
    _membershipSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade400,
              Colors.purple.shade200,
            ],
          ),
        ),
        child: SafeArea(
          child:
              _isLoading
                  ? _buildLoadingView()
                  : _error != null
                  ? _buildErrorView()
                  : _buildContentView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: LoadingIndicator(
        message: 'Loading your queue position...',
        icon: Icons.queue_rounded,
        primaryColor: Colors.white,
        backgroundColor: Colors.deepPurple.shade300,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
          children: [
            Icon(Icons.error_outline, size: 70, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 15),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            SizedBox(height: 25),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: Icon(Icons.refresh),
                  label: Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => HomePage2.navigate(context),
                  icon: Icon(Icons.home),
                  label: Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    if (_room == null || _membership == null) return Container();

    final isActive = _membership!.status == 'active';
    final isPending = _membership!.status == 'pending';
    final position = _membership!.position;
    final currentPosition = _room!.currentPosition;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          SizedBox(height: 30),

          // Position Card
          _buildPositionCard(position, currentPosition, isActive, isPending),
          SizedBox(height: 20),

          // Room Info Card
          _buildRoomInfoCard(),
          SizedBox(height: 20),

          // Member Info Card
          _buildMemberInfoCard(),
          SizedBox(height: 20),

          // Status Info
          _buildStatusInfo(isActive, isPending),
          SizedBox(height: 30),

          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.deepPurple.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.deepPurple.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 3,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.shade100.withOpacity(0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.shade100.withOpacity(0.4),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade600,
                        Colors.purple.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.shade400.withOpacity(0.4),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.queue_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _room!.name,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade800,
                          letterSpacing: 0.5,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade100,
                              Colors.purple.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.deepPurple.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.vpn_key_rounded,
                              size: 16,
                              color: Colors.deepPurple.shade600,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Code: ${_room!.code}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.deepPurple.shade700,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => HomePage2.navigate(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.deepPurple.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        color: Colors.deepPurple.shade600,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(
    int position,
    int currentPosition,
    bool isActive,
    bool isPending,
  ) {
    Color primaryColor;
    Color lightColor;
    Color backgroundColor;
    Color borderColor;
    String statusText;
    IconData statusIcon;
    List<Color> gradientColors;

    if (isPending) {
      primaryColor = Colors.orange.shade800;
      lightColor = Colors.orange.shade600;
      backgroundColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      statusText = 'Awaiting Approval';
      statusIcon = Icons.hourglass_top_rounded;
      gradientColors = [Colors.orange.shade50, Colors.amber.shade50];
    } else if (isActive) {
      if (position <= currentPosition) {
        primaryColor = Colors.green.shade800;
        lightColor = Colors.green.shade600;
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        statusText = 'YOUR TURN NOW!';
        statusIcon = Icons.celebration_rounded;
        gradientColors = [Colors.green.shade50, Colors.teal.shade50];
      } else {
        primaryColor = Colors.blue.shade800;
        lightColor = Colors.blue.shade600;
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        statusText = 'In Queue';
        statusIcon = Icons.queue_play_next_rounded;
        gradientColors = [Colors.blue.shade50, Colors.indigo.shade50];
      }
    } else {
      primaryColor = Colors.grey.shade800;
      lightColor = Colors.grey.shade600;
      backgroundColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade300;
      statusText = 'Not Active';
      statusIcon = Icons.pause_circle_outline_rounded;
      gradientColors = [Colors.grey.shade50, Colors.blueGrey.shade50];
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale:
              position <= currentPosition && isActive
                  ? _pulseAnimation.value
                  : 1.0,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background decorative elements
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lightColor.withOpacity(0.15),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -25,
                  left: -25,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withOpacity(0.1),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Status icon and text
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [primaryColor, lightColor],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(statusIcon, size: 48, color: Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize:
                              position <= currentPosition && isActive ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!isPending) ...[
                        SizedBox(height: 24),
                        // Position display
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: lightColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'Position ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: lightColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '#$position',
                                    style: TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: lightColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Currently serving: #$currentPosition',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: lightColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (position > currentPosition) ...[
                                SizedBox(height: 10),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${position - currentPosition} ${position - currentPosition == 1 ? 'person' : 'people'} ahead',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: primaryColor.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
      },
    );
  }

  Widget _buildRoomInfoCard() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.indigo.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.indigo.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -25,
            right: -25,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.shade100.withOpacity(0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100.withOpacity(0.3),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.indigo.shade600,
                            Colors.blue.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.shade400.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.info_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room Information',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            height: 3,
                            width: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.indigo.shade600,
                                  Colors.blue.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Info items
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.indigo.shade100, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.people_rounded,
                        'Total Members',
                        '${_room!.memberCount}',
                        Colors.indigo.shade600,
                      ),
                      SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.group_work_rounded,
                        'Capacity',
                        '${_room!.capacity}',
                        Colors.blue.shade600,
                      ),
                      SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.info_outline_rounded,
                        'Status',
                        _room!.status.toUpperCase(),
                        Colors.green.shade600,
                      ),
                    ],
                  ),
                ),
                if (_room!.notice.isNotEmpty) ...[
                  SizedBox(height: 20),
                  // Enhanced elegant notice display
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.shade50,
                          Colors.orange.shade50,
                          Colors.deepOrange.shade50,
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.amber.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 3,
                          offset: Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 1,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Sophisticated background patterns
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.amber.shade200.withOpacity(0.4),
                                  Colors.amber.shade100.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -25,
                          left: -25,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.orange.shade200.withOpacity(0.3),
                                  Colors.orange.shade100.withOpacity(0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Elegant geometric pattern
                        Positioned(
                          top: 20,
                          left: 20,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.shade400.withOpacity(0.6),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 35,
                          left: 35,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.shade400.withOpacity(0.5),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 30,
                          right: 25,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.shade300.withOpacity(0.4),
                            ),
                          ),
                        ),
                        // Main content
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sophisticated header
                              Row(
                                children: [
                                  // Elegant icon container
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.amber.shade600,
                                          Colors.orange.shade500,
                                          Colors.deepOrange.shade500,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.shade500
                                              .withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: Colors.orange.shade400
                                              .withOpacity(0.2),
                                          blurRadius: 20,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Notice Board',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              height: 3,
                                              width: 30,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.amber.shade600,
                                                    Colors.orange.shade500,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(1.5),
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Container(
                                              height: 3,
                                              width: 15,
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade400,
                                                borderRadius:
                                                    BorderRadius.circular(1.5),
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Container(
                                              height: 3,
                                              width: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade400,
                                                borderRadius:
                                                    BorderRadius.circular(1.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Elegant status indicator
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.teal.shade400,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.shade400
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.fiber_manual_record,
                                          color: Colors.white,
                                          size: 8,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              // Elegant content container
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber.shade200,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.1),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                      offset: Offset(0, 5),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.9),
                                      blurRadius: 10,
                                      spreadRadius: -2,
                                      offset: Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Content header
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.campaign_rounded,
                                            color: Colors.amber.shade700,
                                            size: 18,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Important Announcement',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.amber.shade900,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              Text(
                                                'Please read carefully',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.amber.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Priority indicator
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.red.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'HIGH',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    // Divider
                                    Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.amber.shade200,
                                            Colors.amber.shade300,
                                            Colors.amber.shade200,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    // Notice content with elegant typography
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.amber.shade50.withOpacity(
                                              0.5,
                                            ),
                                            Colors.orange.shade50.withOpacity(
                                              0.3,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.amber.shade200
                                              .withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _room!.notice,
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 16,
                                          height: 1.6,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    // Elegant footer
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          color: Colors.amber.shade600,
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Posted by Room Creator',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.amber.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        Spacer(),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'OFFICIAL',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade700,
                                              letterSpacing: 0.5,
                                            ),
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
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberInfoCard() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.teal.shade50, Colors.cyan.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.teal.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -25,
            right: -25,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade100.withOpacity(0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyan.shade100.withOpacity(0.3),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.teal.shade600, Colors.cyan.shade500],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.shade400.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Information',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            height: 3,
                            width: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.shade600,
                                  Colors.cyan.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Info items
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.teal.shade100, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.phone_rounded,
                        'Phone Number',
                        widget.phoneNumber,
                        Colors.teal.shade600,
                      ),
                      if (_membership!.formData.isNotEmpty) ...[
                        ..._membership!.formData.entries.map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: _buildInfoRow(
                              Icons.info_rounded,
                              entry.key.toUpperCase(),
                              entry.value.toString(),
                              Colors.cyan.shade600,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.access_time_rounded,
                        'Joined At',
                        _membership!.timestamps.requested.toString().split(
                          '.',
                        )[0],
                        Colors.teal.shade500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(bool isActive, bool isPending) {
    if (isPending) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade50, Colors.amber.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -15,
              right: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade100.withOpacity(0.4),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.shade100.withOpacity(0.3),
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  // Animated icon container
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.orange.shade500, Colors.amber.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.shade400.withOpacity(0.4),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Pending Approval',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange.shade800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'WAITING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.shade100,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Your join request is pending approval from the room creator. You will be notified once approved.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container();
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50, Colors.blueGrey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -25,
            right: -25,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueGrey.shade200.withOpacity(0.3),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blueGrey.shade600,
                            Colors.grey.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.shade400.withOpacity(0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            height: 3,
                            width: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueGrey.shade600,
                                  Colors.grey.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Action buttons
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Refresh button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.shade400.withOpacity(
                                0.3,
                              ),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: Icon(Icons.refresh_rounded, size: 24),
                          label: Text(
                            'Refresh Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      // Back to home button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.8),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () => HomePage2.navigate(context),
                          icon: Icon(Icons.home_rounded, size: 24),
                          label: Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple.shade600,
                            side: BorderSide(
                              color: Colors.deepPurple.shade300,
                              width: 2,
                            ),
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
