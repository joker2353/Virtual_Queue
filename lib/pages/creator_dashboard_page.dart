import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/fcm_provider.dart';
import '../models/room.dart';
import '../models/membership.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/qr_share_dialog.dart';
import 'join_requests_page.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class CreatorDashboardPage extends StatefulWidget {
  final String roomId;

  const CreatorDashboardPage({super.key, required this.roomId});

  // Static helper method to properly navigate to this page with all necessary providers
  static void navigate(BuildContext context, String roomId) {
    // First capture all providers outside of the navigation
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final fcmProvider = Provider.of<FCMProvider>(context, listen: false);

    // Then perform the navigation with the captured providers
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
                ChangeNotifierProvider<RoomProvider>.value(value: roomProvider),
                ChangeNotifierProvider<FCMProvider>.value(value: fcmProvider),
              ],
              child: CreatorDashboardPage(roomId: roomId),
            ),
      ),
    );
  }

  @override
  _CreatorDashboardPageState createState() => _CreatorDashboardPageState();
}

class _CreatorDashboardPageState extends State<CreatorDashboardPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  Room? _room;
  List<Membership> _activeMembers = [];
  int _pendingRequestsCount = 0;
  String? _error;
  final Set<String> _removingMembers =
      {}; // Track which members are being removed

  // Animation controller for UI effects
  late AnimationController _animationController;
  late Animation<double> _headerAnimation;

  // Stream subscriptions
  late Stream<DocumentSnapshot> _roomStream;
  late Stream<QuerySnapshot> _membersStream;
  late Stream<QuerySnapshot> _requestsStream;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
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

    // Active members stream - exclude creator
    _membersStream =
        firestore
            .collection('memberships')
            .where('roomId', isEqualTo: widget.roomId)
            .where('status', isEqualTo: 'active')
            .where(
              'role',
              isEqualTo: 'member',
            ) // Only get regular members, not creator
            .snapshots();

    // Pending requests stream
    _requestsStream =
        firestore
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
      final roomDoc =
          await firestore.collection('rooms').doc(widget.roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      _room = Room.fromMap(widget.roomId, roomDoc.data()!);

      // Get active members - exclude creator
      final membersSnapshot =
          await firestore
              .collection('memberships')
              .where('roomId', isEqualTo: widget.roomId)
              .where('status', isEqualTo: 'active')
              .where('role', isEqualTo: 'member') // Only get regular members
              .get();

      _activeMembers =
          membersSnapshot.docs
              .map((doc) => Membership.fromMap(doc.id, doc.data()))
              .toList();

      // Sort members by position
      _activeMembers.sort((a, b) => a.position.compareTo(b.position));

      // Get pending requests count
      final requestsSnapshot =
          await firestore
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
      if (e is QueueCompletionException) {
        // Show completion message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(e.toString()),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Queue'),
            content: const Text(
              'Are you sure you want to reset the queue to position 1? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reset'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 5,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Notice',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noticeController,
                    decoration: const InputDecoration(
                      hintText: 'Enter notice for members',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            () => Navigator.pop(context, noticeController.text),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (result != null) {
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
            content: const Text('Notice updated successfully'),
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // Clean the phone number - keep only digits and + sign
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Use the number as-is without forcing a country code
      // This allows for local numbers and international numbers with existing country codes
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone dialer for $phoneNumber'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error making phone call: ${e.toString()}'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _room == null) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Dashboard'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: LoadingIndicator(
            message: 'Loading dashboard...',
            primaryColor: Colors.deepPurple,
            backgroundColor: Colors.white.withOpacity(0.8),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Dashboard'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading room',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Room Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: _buildEndDrawer(),
      floatingActionButton:
          _room != null
              ? FloatingActionButton.extended(
                onPressed: () => _showRegisterMemberDialog(_room!),
                backgroundColor: Colors.deepPurple,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Member'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              )
              : null,
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
            _isLoading && _room == null
                ? Center(
                  child: LoadingIndicator(
                    message: 'Loading dashboard...',
                    primaryColor: Colors.white,
                    backgroundColor: Colors.deepPurple.shade300,
                  ),
                )
                : StreamBuilder<DocumentSnapshot>(
                  stream: _roomStream,
                  initialData: null,
                  builder: (context, roomSnapshot) {
                    if (!roomSnapshot.hasData && _room == null) {
                      return Center(
                        child: LoadingIndicator(
                          message: 'Loading room data...',
                          primaryColor: Colors.white,
                          backgroundColor: Colors.deepPurple.shade300,
                        ),
                      );
                    }

                    // Use the latest room data from stream or fallback to initial data
                    final Room room =
                        roomSnapshot.hasData && roomSnapshot.data!.exists
                            ? Room.fromMap(
                              widget.roomId,
                              roomSnapshot.data!.data() as Map<String, dynamic>,
                            )
                            : _room!;

                    return StreamBuilder<QuerySnapshot>(
                      stream: _membersStream,
                      builder: (context, membersSnapshot) {
                        // Process active members
                        List<Membership> activeMembers = _activeMembers;
                        if (membersSnapshot.hasData) {
                          activeMembers =
                              membersSnapshot.data!.docs
                                  .map(
                                    (doc) => Membership.fromMap(
                                      doc.id,
                                      doc.data() as Map<String, dynamic>,
                                    ),
                                  )
                                  .toList();
                          activeMembers.sort(
                            (a, b) => a.position.compareTo(b.position),
                          );
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: _requestsStream,
                          builder: (context, requestsSnapshot) {
                            // Process pending requests count
                            int pendingCount = _pendingRequestsCount;
                            if (requestsSnapshot.hasData) {
                              pendingCount = requestsSnapshot.data!.docs.length;
                            }

                            return SafeArea(
                              child: RefreshIndicator(
                                onRefresh: _loadInitialData,
                                child: ListView(
                                  padding: const EdgeInsets.all(20),
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    _buildRoomInfoCard(room, pendingCount),
                                    const SizedBox(height: 20),
                                    _buildQueueControlCard(room),
                                    const SizedBox(height: 20),
                                    _buildNoticeCard(room),
                                    const SizedBox(height: 20),
                                    _buildMembersCard(activeMembers, room),
                                    const SizedBox(height: 20),
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
      ),
    );
  }

  Widget _buildEndDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white, Colors.white],
            stops: const [0.0, 0.2, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.meeting_room,
                        color: Colors.deepPurple.shade700,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_room != null)
                      Text(
                        _room!.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Room Settings',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.deepPurple.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.qr_code_rounded,
                      title: 'Share QR Code',
                      subtitle: 'Let members join via QR',
                      onTap: _showQRCodeDialog,
                    ),
                    _buildDrawerItem(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      subtitle: 'Manage room notifications',
                      onTap: () {
                        // TODO: Implement notifications settings
                        Navigator.pop(context);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.analytics_rounded,
                      title: 'Analytics',
                      subtitle: 'View room statistics',
                      onTap: () {
                        // TODO: Implement analytics
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 32),
                    _buildDrawerItem(
                      icon: Icons.restart_alt_rounded,
                      title: 'Reset Queue',
                      subtitle: 'Start queue from position 1',
                      onTap: _resetQueue,
                      color: Colors.red,
                      isDanger: true,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Room Code: ${_room?.code ?? ""}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    bool isDanger = false,
  }) {
    final itemColor = color ?? Colors.deepPurple;
    final bgColor = isDanger ? Colors.red.shade50 : itemColor.withOpacity(0.05);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: bgColor,
          minLeadingWidth: 0,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isDanger ? Colors.red.shade100 : itemColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDanger ? Colors.red.shade700 : itemColor,
              size: 22,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isDanger ? Colors.red.shade700 : itemColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: isDanger ? Colors.red.shade600 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: (isDanger ? Colors.red : itemColor).withOpacity(0.5),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard(Room room, int pendingCount) {
    return Card(
      elevation: 6,
      shadowColor: Colors.deepPurple.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.deepPurple.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.meeting_room,
                      color: Colors.deepPurple,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: room.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Room code copied to clipboard',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green.shade700,
                                margin: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.vpn_key,
                                size: 16,
                                color: Colors.deepPurple.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Code: ${room.code}',
                                style: TextStyle(
                                  color: Colors.deepPurple.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy,
                                size: 14,
                                color: Colors.deepPurple.shade400,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade500,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '#${room.currentPosition}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Current Position',
                    '${room.currentPosition}',
                    Icons.person_pin,
                    Colors.blue.shade600,
                  ),
                  _buildStatItem(
                    'In Queue',
                    '${_activeMembers.length}',
                    Icons.people,
                    Colors.deepPurple.shade600,
                  ),
                  _buildStatItem(
                    'Pending Requests',
                    '$pendingCount',
                    Icons.person_add,
                    Colors.orange.shade600,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  JoinRequestsPage(roomId: widget.roomId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueControlCard(Room room) {
    return Card(
      elevation: 6,
      shadowColor: Colors.deepPurple.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.deepPurple.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.queue,
                      color: Colors.blue.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Queue Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Currently Serving: #${room.currentPosition}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildControlButton(
                          'Previous',
                          Icons.arrow_back,
                          onPressed:
                              room.currentPosition > 0 ? _decreaseQueue : null,
                          color: Colors.orange.shade600,
                        ),
                        _buildControlButton(
                          'Next',
                          Icons.arrow_forward,
                          onPressed: _advanceQueue,
                          isPrimary: true,
                          color: Colors.deepPurple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Use the controls above to manage your queue position.',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 14,
                        ),
                      ),
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

  Widget _buildControlButton(
    String label,
    IconData icon, {
    VoidCallback? onPressed,
    bool isPrimary = false,
    required Color color,
  }) {
    final isDisabled = onPressed == null || _isLoading;

    return Column(
      children: [
        Material(
          elevation: isPrimary ? 8 : 4,
          shadowColor: color.withOpacity(0.4),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isDisabled
                        ? Colors.grey.shade300
                        : isPrimary
                        ? color
                        : Colors.white,
                border:
                    isPrimary
                        ? null
                        : Border.all(color: color.withOpacity(0.5)),
              ),
              child: Icon(
                icon,
                color:
                    isDisabled
                        ? Colors.grey.shade600
                        : isPrimary
                        ? Colors.white
                        : color,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color:
                isDisabled
                    ? Colors.grey.shade500
                    : isPrimary
                    ? color
                    : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard(Room room) {
    return Card(
      elevation: 8,
      shadowColor: Colors.amber.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.amber.shade50, Colors.orange.shade50],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -25,
              right: -25,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.shade200.withOpacity(0.3),
                ),
              ),
            ),
            Positioned(
              bottom: -15,
              left: -15,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade200.withOpacity(0.2),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.amber.shade600,
                                  Colors.orange.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.shade400.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notice Board',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: 3,
                                width: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade600,
                                      Colors.orange.shade500,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _updateNotice,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Colors.amber.shade50],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.amber.shade200,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 22,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.amber.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child:
                        room.notice.isNotEmpty
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_rounded,
                                      color: Colors.amber.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Current Notice',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.amber.shade800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  room.notice,
                                  style: TextStyle(
                                    height: 1.5,
                                    fontSize: 16,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                            : Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100.withOpacity(
                                        0.7,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 40,
                                      color: Colors.amber.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notice available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add a notice to inform your queue members',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.shade400
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: _updateNotice,
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 20,
                                      ),
                                      label: const Text('Add Notice'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade600,
                                        foregroundColor: Colors.white,
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersCard(List<Membership> activeMembers, Room room) {
    return Card(
      elevation: 6,
      shadowColor: Colors.green.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.people,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Queue Members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${activeMembers.length} in queue',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (activeMembers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.people_outline,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No active members in this room',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Use the "Add Member" button to register members',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showRegisterMemberDialog(_room!),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Member'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('memberships')
                          .where('roomId', isEqualTo: room.id)
                          .where('role', isEqualTo: 'member')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allMembers =
                        snapshot.data!.docs
                            .map(
                              (doc) => Membership.fromMap(
                                doc.id,
                                doc.data() as Map<String, dynamic>,
                              ),
                            )
                            .toList();

                    // Separate members by status
                    final activeMembers =
                        allMembers.where((m) => m.isActive).toList()
                          ..sort((a, b) => a.position.compareTo(b.position));
                    final servedMembers =
                        allMembers
                            .where(
                              (m) => m.isServed && m.timestamps.served != null,
                            )
                            .toList()
                          ..sort((a, b) {
                            // Ensure both timestamps exist before comparing
                            final aTime = a.timestamps.served;
                            final bTime = b.timestamps.served;
                            if (aTime == null && bTime == null) return 0;
                            if (aTime == null) return 1;
                            if (bTime == null) return -1;
                            return bTime.compareTo(aTime);
                          });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.white,
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.1),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (activeMembers.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Active Members',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple.shade800,
                                      ),
                                    ),
                                  ),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: activeMembers.length,
                                    separatorBuilder:
                                        (context, index) =>
                                            const Divider(height: 1),
                                    itemBuilder:
                                        (context, index) => _buildMemberTile(
                                          activeMembers[index],
                                          room,
                                        ),
                                  ),
                                ],
                                if (servedMembers.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Served Members',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: servedMembers.length,
                                    separatorBuilder:
                                        (context, index) =>
                                            const Divider(height: 1),
                                    itemBuilder:
                                        (context, index) =>
                                            _buildServedMemberTile(
                                              servedMembers[index],
                                            ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(Membership member, Room room) {
    final isBeingServed = member.position == room.currentPosition;
    final isNextInLine = member.position == room.currentPosition + 1;

    return Container(
      decoration: BoxDecoration(
        color:
            isBeingServed
                ? Colors.green.withOpacity(0.1)
                : isNextInLine
                ? Colors.amber.withOpacity(0.05)
                : Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              isBeingServed
                  ? Colors.green
                  : isNextInLine
                  ? Colors.amber
                  : Colors.deepPurple,
          child: Text(
            '${member.position}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          member.formData['name'] ?? 'Unknown Member',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  member.formData['contact'] as String? ?? 'No number',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (member.formData.containsKey('address') &&
                member.formData['address'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        member.formData['address'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isBeingServed
                        ? Colors.green.shade100
                        : isNextInLine
                        ? Colors.amber.shade100
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isBeingServed
                            ? Colors.green
                            : isNextInLine
                            ? Colors.amber
                            : Colors.grey)
                        .withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                isBeingServed
                    ? 'Current'
                    : isNextInLine
                    ? 'Next'
                    : 'Waiting',
                style: TextStyle(
                  color:
                      isBeingServed
                          ? Colors.green.shade800
                          : isNextInLine
                          ? Colors.amber.shade800
                          : Colors.grey.shade800,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (member.role != 'creator')
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder:
                    (context) => [
                      if (member.formData['contact'] != null &&
                          member.formData['contact'].toString().isNotEmpty)
                        PopupMenuItem<String>(
                          value: 'call',
                          child: ListTile(
                            leading: Icon(
                              Icons.phone,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            title: const Text(
                              'Call Member',
                              style: TextStyle(fontSize: 14),
                            ),
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (!_removingMembers.contains(member.userId))
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: ListTile(
                            leading: Icon(
                              Icons.person_remove,
                              color: Colors.red.shade600,
                              size: 20,
                            ),
                            title: const Text(
                              'Remove Member',
                              style: TextStyle(fontSize: 14),
                            ),
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                onSelected: (value) {
                  switch (value) {
                    case 'call':
                      _makePhoneCall(member.formData['contact'].toString());
                      break;
                    case 'remove':
                      _showRemoveMemberDialog(member);
                      break;
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServedMemberTile(Membership member) {
    // Ensure we have a served timestamp
    final servedTime = member.timestamps.served;
    if (servedTime == null) {
      return Container(); // Return empty container if no timestamp
    }

    return Container(
      color: Colors.grey.shade50,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade300,
          child: Icon(
            Icons.check_circle,
            color: Colors.grey.shade700,
            size: 24,
          ),
        ),
        title: Text(
          member.formData['name'] ?? 'Unknown Member',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              'Served at ${_formatDateTime(servedTime)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Served',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showQRCodeDialog() {
    if (_room == null) return;

    showDialog(
      context: context,
      builder:
          (context) =>
              QRShareDialog(roomCode: _room!.code, roomName: _room!.name),
    );
  }

  Future<void> _showRegisterMemberDialog(Room room) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String contact = '';
    String address = '';
    bool isRegistering = false;
    String? errorMessage;

    // Capture the RoomProvider before creating the dialog
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Register New Member'),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 16),
                            color: Colors.red.shade50,
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person),
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
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Contact Number',
                            prefixIcon: Icon(Icons.phone),
                            hintText: '1234567890',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter contact number';
                            }
                            // Count only digits in the phone number
                            String digitsOnly = value.replaceAll(
                              RegExp(r'[^\d]'),
                              '',
                            );
                            if (digitsOnly.length < 7) {
                              return 'Please enter a valid contact number';
                            }
                            return null;
                          },
                          onSaved: (value) => contact = value ?? '',
                          keyboardType: TextInputType.phone,
                          enabled: !isRegistering,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            prefixIcon: Icon(Icons.home),
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
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isRegistering ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isRegistering
                              ? null
                              : () async {
                                if (formKey.currentState!.validate()) {
                                  formKey.currentState!.save();

                                  setDialogState(() {
                                    isRegistering = true;
                                    errorMessage = null;
                                  });

                                  try {
                                    // Generate a unique ID for the customer
                                    final customerId = const Uuid().v4();

                                    // Register member directly using the captured provider
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
                                        content: const Text(
                                          'Member registered and added to the queue',
                                        ),
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
                      child:
                          isRegistering
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Register'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _showRemoveMemberDialog(Membership member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Member'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to remove "${member.formData['name'] ?? 'this member'}" from the queue?',
                ),
                const SizedBox(height: 8),
                Text(
                  'Position: #${member.position}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _removingMembers.add(member.userId);
      });

      try {
        final roomProvider = Provider.of<RoomProvider>(context, listen: false);

        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        await roomProvider.removeMember(widget.roomId, member.userId);

        // Hide loading indicator
        Navigator.of(context).pop();

        // Refresh the data immediately
        await _loadInitialData();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.formData['name'] ?? 'Member'} removed from the queue',
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        // Hide loading indicator if still showing
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _removingMembers.remove(member.userId);
          });
        }
      }
    }
  }
}
