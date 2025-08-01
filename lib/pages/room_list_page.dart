import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'dart:async';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/fcm_provider.dart';
import '../models/room.dart';
import '../widgets/loading_indicator.dart';
import 'create_room_dialog.dart';
import 'shop_dashboard_page.dart';
import 'shop_order_page.dart';
import 'creator_dashboard_page.dart';
import 'medical_dashboard_page.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({Key? key}) : super(key: key);

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  bool _isLoading = false;
  String _selectedCategory = 'all';

  void _showCreateRoomDialog() {
    CreateRoomDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRoomDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Rooms')),
                  DropdownMenuItem(value: 'queue', child: Text('Queues')),
                  DropdownMenuItem(value: 'shop', child: Text('Shops')),
                  DropdownMenuItem(
                    value: 'medical',
                    child: Text('Medical Shops'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<firestore.QuerySnapshot>(
                stream:
                    firestore.FirebaseFirestore.instance
                        .collection('rooms')
                        .where('creatorId', isEqualTo: user.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rooms =
                      snapshot.data?.docs
                          .map(
                            (doc) => Room.fromMap(
                              doc.id,
                              doc.data() as Map<String, dynamic>,
                            ),
                          )
                          .where((room) {
                            if (_selectedCategory == 'all') return true;
                            return room.category == _selectedCategory;
                          })
                          .toList() ??
                      [];

                  if (rooms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedCategory == 'all'
                                ? Icons.meeting_room
                                : _selectedCategory == 'queue'
                                ? Icons.queue
                                : Icons.store,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCategory == 'all'
                                ? 'No rooms created yet'
                                : _selectedCategory == 'queue'
                                ? 'No queue rooms created yet'
                                : 'No shop rooms created yet',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _showCreateRoomDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Room'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _buildRoomCard(context, room);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, Room room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          if (room.category == 'shop') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShopDashboardPage(roomId: room.id),
              ),
            );
          } else if (room.category == 'medical') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MedicalDashboardPage(roomId: room.id),
              ),
            );
          } else {
            // Navigate to creator dashboard for queue rooms
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatorDashboardPage(roomId: room.id),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    room.category == 'shop' ? Icons.store : Icons.queue,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      room.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          room.category == 'shop'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      room.category == 'shop' ? 'Shop' : 'Queue',
                      style: TextStyle(
                        color:
                            room.category == 'shop'
                                ? Colors.green
                                : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Room Code: ${room.code}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              if (room.notice != null && room.notice!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  room.notice!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${room.memberCount} members',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  Text(
                    'Capacity: ${room.capacity}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
