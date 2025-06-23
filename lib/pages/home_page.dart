import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/virtual_queue_logo.dart';
import '../models/user_room.dart';
import '../models/room.dart';
import 'join_room_code_dialog.dart';
import 'create_room_dialog.dart';
import 'member_details_page.dart';
import 'creator_dashboard_page.dart';
import 'profile_page.dart';
import '../providers/fcm_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shop_dashboard_page.dart';
import 'shop_order_page.dart';
import '../models/order.dart' as app_models;
import 'customer_page.dart';
import 'homepage2.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _refreshOnInit();
  }

  Future<void> _refreshOnInit() async {
    await Future.microtask(() async {
      if (!mounted) return;
      await Provider.of<RoomProvider>(context, listen: false).refreshRooms();
    });
  }

  Future<void> _handlePullToRefresh() async {
    if (!mounted) return;
    try {
      await Provider.of<RoomProvider>(context, listen: false).refreshRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing rooms: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VirtualQueueLogo(size: 32, showText: false),
            const SizedBox(width: 12),
            Text(
              'Virtual Queue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                ProfilePage.navigate(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.deepPurple.shade300,
                  backgroundImage:
                      Provider.of<AuthProvider>(context).user?.photoURL != null
                          ? NetworkImage(
                            Provider.of<AuthProvider>(context).user!.photoURL!,
                          )
                          : null,
                  child:
                      Provider.of<AuthProvider>(context).user?.photoURL == null
                          ? Icon(Icons.person, color: Colors.white)
                          : null,
                ),
              ),
            ),
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
        child: Consumer<RoomProvider>(
          builder: (context, roomProvider, child) {
            if (roomProvider.isLoading) {
              return Center(
                child: LoadingIndicator(
                  message: 'Loading your rooms...',
                  icon: Icons.home_rounded,
                  primaryColor: Colors.white,
                  backgroundColor: Colors.deepPurple.shade300,
                ),
              );
            }

            if (roomProvider.error != null) {
              return _buildErrorView(context, roomProvider);
            }

            print('DEBUG: HomePage - RoomProvider loaded');
            final queueRooms = roomProvider.queueRooms;
            print('DEBUG: HomePage - Queue rooms count: ${queueRooms.length}');
            print(
              'DEBUG: HomePage - Queue rooms: ${queueRooms.map((r) => '${r.name}(${r.category})').toList()}',
            );

            return RefreshIndicator(
              onRefresh: _handlePullToRefresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildWelcomeCard(context),
                  SizedBox(height: 32),
                  _buildRoomSection(
                    context,
                    'Joined Queues',
                    queueRooms,
                    (room) => _buildJoinedRoomCard(context, room),
                    Colors.blue,
                  ),
                  SizedBox(height: 32),
                  _buildRoomSection(
                    context,
                    'Pending Requests',
                    roomProvider.pendingRooms,
                    (room) => _buildPendingRoomCard(context, room),
                    Colors.amber,
                  ),
                  SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, RoomProvider roomProvider) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(20),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 70, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Error Loading Rooms',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                roomProvider.error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: _handlePullToRefresh,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

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
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        child: Column(
          children: [
            Text(
              'Welcome, ${auth.user?.displayName ?? 'User'}!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade800,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Manage your virtual queues with ease.',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.group_add,
                    label: 'Join Room',
                    color: Colors.blue.shade600,
                    onPressed: () {
                      final roomProvider = Provider.of<RoomProvider>(
                        context,
                        listen: false,
                      );

                      showDialog(
                        context: context,
                        builder:
                            (context) =>
                                JoinRoomCodeDialog(roomProvider: roomProvider),
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.search,
                    label: 'Check Position',
                    color: Colors.deepPurple,
                    onPressed: () {
                      HomePage2.navigate(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildRoomSection(
    BuildContext context,
    String title,
    List<UserRoom> rooms,
    Widget Function(UserRoom) cardBuilder,
    MaterialColor accentColor,
  ) {
    return Container(
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
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getSectionIcon(title), color: accentColor, size: 24),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor.shade800,
                ),
              ),
            ],
          ),
          Divider(height: 25, thickness: 1.5, color: accentColor.shade100),
          if (rooms.isEmpty)
            _buildEmptyState(accentColor)
          else
            ...rooms.map(cardBuilder),
        ],
      ),
    );
  }

  IconData _getSectionIcon(String title) {
    if (title.contains('Joined')) return Icons.group;
    if (title.contains('Pending')) return Icons.hourglass_empty;
    return Icons.folder;
  }

  Widget _buildEmptyState(MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox, size: 48, color: color.shade300),
            SizedBox(height: 10),
            Text(
              'No rooms to display',
              style: TextStyle(
                color: color.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinedRoomCard(BuildContext context, UserRoom room) {
    final isBeingServed = room.isCurrentlyServed;
    final color = isBeingServed ? Colors.green : Colors.blue;
    final statusText =
        isBeingServed
            ? "It's your turn!"
            : room.waitingCount > 0
            ? "${room.waitingCount} ahead of you"
            : "Almost your turn";

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          MemberDetailsPage.navigate(context, room.roomId);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [color.shade50, Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '#${room.position}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color.shade700,
                      ),
                    ),
                    CircularProgressIndicator(
                      value:
                          isBeingServed
                              ? 1.0
                              : room.waitingCount == 0
                              ? 0.95
                              : null,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      color: color.shade300,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStatusChip(
                          label: statusText,
                          color: color,
                          icon:
                              isBeingServed
                                  ? Icons.check_circle
                                  : Icons.access_time,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color.shade700, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required MaterialColor color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRoomCard(BuildContext context, UserRoom room) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.amber.shade50, Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.2),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.hourglass_empty,
                  color: Colors.amber.shade700,
                  size: 30,
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 6),
                  _buildStatusChip(
                    label: 'Waiting for approval',
                    color: Colors.amber,
                    icon: Icons.pending_actions,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
