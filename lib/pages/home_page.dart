import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import 'join_room_dialog.dart';
import 'create_room_dialog.dart';
import 'member_details_page.dart';
import 'creator_dashboard_page.dart';
import 'profile_page.dart';

class HomePage extends StatelessWidget {
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
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
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'My Created Rooms',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          ...roomProvider.joinedRooms
              .where((room) => room.creatorId == auth.user?.uid)
              .map((room) {
                return Card(
                  elevation: 1,
                  margin: EdgeInsets.symmetric(vertical: 6),
                  color: Colors.green[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.verified_user, color: Colors.green),
                    title: Text(
                      room.name,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Current Position: ${room.currentPosition}'),
                    trailing: Text(
                      'Creator',
                      style: TextStyle(color: Colors.green[900]),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatorDashboardPage(roomId: room.id),
                        ),
                      );
                    },
                  ),
                );
              })
              .toList(),
          SizedBox(height: 32),
          Text('Joined Rooms', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          ...roomProvider.joinedRooms
              .where((room) => room.creatorId != auth.user?.uid)
              .map((room) {
                if (room.isPending) {
                  // Show pending join request status
                  return Card(
                    elevation: 1,
                    margin: EdgeInsets.symmetric(vertical: 6),
                    color: Colors.orange[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.hourglass_empty,
                        color: Colors.orange,
                      ),
                      title: Text(
                        room.name,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Join Request Pending'),
                      trailing: Text(
                        'Pending',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberDetailsPage(roomId: room.id),
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  // Show member status with position
                  return Card(
                    elevation: 1,
                    margin: EdgeInsets.symmetric(vertical: 6),
                    color: Colors.blue[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.people,
                        color: Colors.blue,
                      ),
                      title: Text(
                        room.name,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Queue: ${room.currentPosition}'),
                          Text('Your Position: ${room.userPosition}'),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        'Member',
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberDetailsPage(roomId: room.id),
                          ),
                        );
                      },
                    ),
                  );
                }
              })
              .toList(),
        ],
      ),
    );
  }
}
