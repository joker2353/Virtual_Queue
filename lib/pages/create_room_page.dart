import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import '../models/user_room.dart';
import 'create_room_dialog.dart';
import 'creator_dashboard_page.dart';
import 'shop_dashboard_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  _CreateRoomPageState createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
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
        title: Text(
          'Create Room',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
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
                  icon: Icons.meeting_room,
                  primaryColor: Colors.white,
                  backgroundColor: Colors.deepPurple.shade300,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _handlePullToRefresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCreateRoomCard(context),
                  SizedBox(height: 24),
                  Text(
                    'Created Rooms',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (roomProvider.createdRooms.isEmpty)
                    _buildEmptyState()
                  else
                    ...roomProvider.createdRooms.map(
                      (room) => _buildCreatedRoomCard(context, room),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCreateRoomCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => CreateRoomDialog(),
          ).then((roomId) async {
            if (roomId != null) {
              final roomDoc =
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(roomId)
                      .get();

              if (roomDoc.exists) {
                final roomData = Room.fromMap(roomId, roomDoc.data()!);
                if (roomData.category == 'shop') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShopDashboardPage(roomId: roomId),
                    ),
                  );
                } else {
                  CreatorDashboardPage.navigate(context, roomId);
                }
              }
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.add_box_rounded, size: 48, color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Create New Room',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Create a queue or shop room',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.8),
          ),
          SizedBox(height: 16),
          Text(
            'No rooms created yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first room to get started',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedRoomCard(BuildContext context, UserRoom room) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final roomDoc =
              await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(room.roomId)
                  .get();

          if (roomDoc.exists) {
            final roomData = Room.fromMap(room.roomId, roomDoc.data()!);
            if (roomData.category == 'shop') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopDashboardPage(roomId: room.roomId),
                ),
              );
            } else {
              CreatorDashboardPage.navigate(context, room.roomId);
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.green.shade50, Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.meeting_room,
                    color: Colors.green.shade700,
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
                    Row(
                      children: [
                        _buildStatusChip(
                          label: 'Owner',
                          color: Colors.green,
                          icon: Icons.verified_user,
                        ),
                        SizedBox(width: 8),
                        _buildStatusChip(
                          label: '${room.memberCount} members',
                          color: Colors.blue,
                          icon: Icons.people,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.green.shade700,
                size: 18,
              ),
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
}
