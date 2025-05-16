import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import '../models/user_room.dart';
import 'join_room_dialog.dart';
import 'create_room_dialog.dart';
import 'member_details_page.dart';
import 'creator_dashboard_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Refresh rooms when the page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      roomProvider.refreshRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final roomProvider = Provider.of<RoomProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Virtual Queue'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundImage:
                  auth.user?.photoURL != null
                      ? NetworkImage(auth.user!.photoURL!)
                      : null,
              child: auth.user?.photoURL == null ? Icon(Icons.person) : null,
            ),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage()),
              );
            },
          ),
        ],
      ),
      body: roomProvider.isLoading
          ? Center(child: LoadingIndicator(
              message: 'Loading your rooms...',
            ))
          : roomProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Error loading rooms',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      Text(
                        roomProvider.error!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          roomProvider.refreshRooms();
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => roomProvider.refreshRooms(),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildWelcomeCard(context, auth),
                      SizedBox(height: 32),
                      _buildRoomSection(
                        context, 
                        'My Created Rooms', 
                        roomProvider.createdRooms,
                        (room) => _buildCreatedRoomCard(context, room),
                      ),
                      SizedBox(height: 32),
                      _buildRoomSection(
                        context, 
                        'Joined Rooms', 
                        roomProvider.activeRooms,
                        (room) => _buildJoinedRoomCard(context, room),
                      ),
                      SizedBox(height: 32),
                      _buildRoomSection(
                        context, 
                        'Pending Requests', 
                        roomProvider.pendingRooms,
                        (room) => _buildPendingRoomCard(context, room),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, AuthProvider auth) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              'Welcome, ${auth.user?.displayName ?? 'User'}!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              'Manage your virtual queues with ease.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.group_add),
                    label: Text('Join Room'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => JoinRoomDialog(),
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add_box),
                    label: Text('Create Room'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => CreateRoomDialog(),
                      ).then((roomId) {
                        if (roomId != null) {
                          // If a room was created successfully, navigate to its dashboard
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatorDashboardPage(roomId: roomId),
                            ),
                          );
                        }
                      });
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

  Widget _buildRoomSection(
    BuildContext context, 
    String title, 
    List<UserRoom> rooms,
    Widget Function(UserRoom) cardBuilder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        if (rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                'No rooms to display',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ...rooms.map(cardBuilder),
      ],
    );
  }

  Widget _buildCreatedRoomCard(BuildContext context, UserRoom room) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 6),
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatorDashboardPage(roomId: room.roomId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Members: ${room.memberCount} • Current Position: ${room.currentPosition}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Creator',
                  style: TextStyle(
                    color: Colors.green[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRoomCard(BuildContext context, UserRoom room) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 6),
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    room.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    'Pending Approval',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Waiting for the room creator to accept your request.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinedRoomCard(BuildContext context, UserRoom room) {
    final isCurrentlyServed = room.isCurrentlyServed;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 6),
      color: isCurrentlyServed ? Colors.green[50] : Colors.blue[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberDetailsPage(roomId: room.roomId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCurrentlyServed ? Icons.check_circle : Icons.people,
                    color: isCurrentlyServed ? Colors.green : Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      room.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentlyServed ? Colors.green[100] : Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCurrentlyServed ? 'Your Turn!' : 'Member',
                      style: TextStyle(
                        color: isCurrentlyServed ? Colors.green[900] : Colors.blue[900],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQueueStat(
                    'Current Queue',
                    '${room.currentPosition}',
                    Colors.blue[700]!,
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: isCurrentlyServed ? Colors.green[200] : Colors.blue[200],
                  ),
                  _buildQueueStat(
                    'Your Position',
                    '${room.position}',
                    isCurrentlyServed
                        ? Colors.green[700]!
                        : Colors.blue[700]!,
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: isCurrentlyServed ? Colors.green[200] : Colors.blue[200],
                  ),
                  _buildQueueStat(
                    'Waiting',
                    '${room.waitingCount}',
                    isCurrentlyServed ? Colors.green[700]! : Colors.blue[700]!,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
