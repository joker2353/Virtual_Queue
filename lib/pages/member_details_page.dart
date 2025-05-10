import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/room.dart';
import '../models/membership.dart';
import '../models/user_room.dart';
import '../providers/room_provider.dart';

class MemberDetailsPage extends StatefulWidget {
  final String roomId;

  const MemberDetailsPage({required this.roomId, Key? key}) : super(key: key);

  @override
  _MemberDetailsPageState createState() => _MemberDetailsPageState();
}

class _MemberDetailsPageState extends State<MemberDetailsPage> {
  bool _isLoading = false;
  Room? _room;
  Membership? _membership;
  UserRoom? _userRoom;
  String? _error;
  DateTime? _waitingSince;
  
  // Stream subscriptions for real-time updates
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<DocumentSnapshot>? _membershipSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }
  
  @override
  void dispose() {
    // Cancel subscriptions when the page is disposed
    _roomSubscription?.cancel();
    _membershipSubscription?.cancel();
    super.dispose();
  }
  
  void _setupRealtimeUpdates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception('User not signed in');
      }
      
      // Get room stream
      final roomRef = firestore.collection('rooms').doc(widget.roomId);
      _roomSubscription = roomRef.snapshots().listen(
        (roomSnapshot) {
          if (!roomSnapshot.exists) {
            setState(() {
              _error = 'Room not found';
              _isLoading = false;
            });
            return;
          }
          
          setState(() {
            _room = Room.fromMap(widget.roomId, roomSnapshot.data()!);
            _error = null;
            _isLoading = false;
            
            // Update the UserRoom with latest room details
            if (_userRoom != null && _room != null) {
              _userRoom = _userRoom!.copyWith(
                currentPosition: _room!.currentPosition,
                memberCount: _room!.memberCount,
              );
            }
          });
        },
        onError: (error) {
          setState(() {
            _error = 'Failed to load room: $error';
            _isLoading = false;
          });
        }
      );
      
      // Get membership stream
      final membershipId = '${widget.roomId}_${user.uid}';
      final membershipRef = firestore.collection('memberships').doc(membershipId);
      _membershipSubscription = membershipRef.snapshots().listen(
        (membershipSnapshot) {
          if (!membershipSnapshot.exists) {
            setState(() {
              _error = 'You are not a member of this room';
              _isLoading = false;
            });
            return;
          }
          
          setState(() {
            _membership = Membership.fromMap(membershipId, membershipSnapshot.data()!);
            
            // Calculate waiting time
            if (_membership!.timestamps.approved != null) {
              _waitingSince = _membership!.timestamps.approved;
            }
            
            // Create/update UserRoom with latest data
            if (_room != null) {
              _userRoom = UserRoom(
                roomId: widget.roomId,
                name: _room!.name,
                type: 'joined',
                status: _membership!.status,
                position: _membership!.position,
                currentPosition: _room!.currentPosition,
                memberCount: _room!.memberCount,
                joinedAt: _membership!.timestamps.approved ?? _membership!.timestamps.requested,
              );
            }
            
            _error = null;
            _isLoading = false;
          });
        },
        onError: (error) {
          setState(() {
            _error = 'Failed to load membership: $error';
            _isLoading = false;
          });
        }
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Room'),
        content: Text('Are you sure you want to leave this room? You will lose your position in the queue.'),
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
            child: Text('Leave'),
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
      await roomProvider.leaveRoom(widget.roomId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have left the room')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Queue Details'),
      ),
      body: _isLoading && _room == null
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildDetailsView(),
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
            'Error',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _setupRealtimeUpdates,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsView() {
    if (_room == null || _membership == null || _userRoom == null) {
      return Center(child: Text('Loading room details...'));
    }
    
    final room = _room!;
    final membership = _membership!;
    final userRoom = _userRoom!;
    
    // Calculate time details
    String waitingTime = 'N/A';
    if (_waitingSince != null) {
      final duration = DateTime.now().difference(_waitingSince!);
      if (duration.inDays > 0) {
        waitingTime = '${duration.inDays} days, ${duration.inHours.remainder(24)} hours';
      } else if (duration.inHours > 0) {
        waitingTime = '${duration.inHours} hours, ${duration.inMinutes.remainder(60)} minutes';
      } else {
        waitingTime = '${duration.inMinutes} minutes';
      }
    }
    
    // Calculate position details
    final waitingCount = userRoom.waitingCount;
    final isBeingServed = userRoom.isCurrentlyServed;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoomHeader(room),
          SizedBox(height: 24),
          _buildStatusCard(userRoom, isBeingServed),
          SizedBox(height: 24),
          _buildWaitingTimeCard(waitingTime, userRoom),
          SizedBox(height: 24),
          _buildNoticeBoard(room),
          SizedBox(height: 24),
          _buildActionButtons(),
        ],
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
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.meeting_room,
                color: Colors.blue,
                size: 36,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Capacity: ${room.capacity} members',
                    style: TextStyle(
                      color: Colors.grey[700],
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
  
  Widget _buildStatusCard(UserRoom userRoom, bool isBeingServed) {
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
              'Your Queue Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem(
                  'Your Position',
                  '#${userRoom.position}',
                  Icons.person_pin,
                  Colors.blue,
                ),
                _buildStatusItem(
                  'Current Serving',
                  '#${userRoom.currentPosition}',
                  Icons.call_missed_outgoing,
                  Colors.green,
                ),
                _buildStatusItem(
                  'People Ahead',
                  userRoom.waitingCount.toString(),
                  Icons.people,
                  Colors.orange,
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isBeingServed ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBeingServed ? Colors.green : Colors.orange,
                ),
              ),
              child: Text(
                isBeingServed
                    ? 'It\'s your turn now! 🎉'
                    : userRoom.waitingCount > 0
                        ? 'Please wait, there are ${userRoom.waitingCount} people ahead of you'
                        : 'Almost your turn, get ready!',
                style: TextStyle(
                  color: isBeingServed ? Colors.green[800] : Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingTimeCard(String waitingTime, UserRoom userRoom) {
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
                Icon(Icons.timer, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Waiting Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time in queue:',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        waitingTime,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated wait:',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        userRoom.estimatedWaitTime,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
              children: [
                Icon(Icons.announcement, color: Colors.amber[800]),
                SizedBox(width: 8),
                Text(
                  'Notice Board',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Text(
                room.notice.isNotEmpty
                    ? room.notice
                    : 'No notice available',
                style: TextStyle(
                  color: Colors.amber[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
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
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.exit_to_app),
                    label: Text('Leave Room'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading ? null : _leaveRoom,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
