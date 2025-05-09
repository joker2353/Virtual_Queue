import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberDetailsPage extends StatelessWidget {
  final String roomId;
  const MemberDetailsPage({required this.roomId, super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Member Details')),
        body: Center(child: Text('Not signed in.')),
      );
    }
    final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final memberDoc = roomDoc.collection('members').doc(user.uid);

    return Scaffold(
      appBar: AppBar(title: Text('My Queue Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: roomDoc.snapshots(),
        builder: (context, roomSnap) {
          if (!roomSnap.hasData)
            return Center(child: CircularProgressIndicator());
          final roomData = roomSnap.data!.data() as Map<String, dynamic>;
          final currentPosition = roomData['currentPosition'] ?? 1;
          final notice = roomData['notice'] ?? '';

          return StreamBuilder<DocumentSnapshot>(
            stream: memberDoc.snapshots(),
            builder: (context, memberSnap) {
              if (!memberSnap.hasData)
                return Center(child: CircularProgressIndicator());
              if (!memberSnap.data!.exists) {
                return Center(
                  child: Text('You are not a member of this room.'),
                );
              }
              final memberData =
                  memberSnap.data!.data() as Map<String, dynamic>;
              return FutureBuilder<QuerySnapshot>(
                future: roomDoc.collection('members').orderBy('joinedAt').get(),
                builder: (context, membersSnap) {
                  if (!membersSnap.hasData)
                    return Center(child: CircularProgressIndicator());
                  final members = membersSnap.data!.docs;
                  final myIndex = members.indexWhere(
                    (doc) => doc.id == user.uid,
                  );
                  final mySerial = myIndex + 1;
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.meeting_room,
                                    color: Colors.blue,
                                    size: 32,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Room: ${roomData['name']}',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                ],
                              ),
                              Divider(height: 32),
                              Row(
                                children: [
                                  Icon(
                                    Icons.confirmation_number,
                                    color: Colors.deepPurple,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'My Serial Number: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$mySerial',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.format_list_numbered,
                                    color: Colors.deepPurple,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Current Position: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$currentPosition',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.announcement,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Notice: $notice')),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.chat),
                                      label: Text('Chat Now'),
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        // TODO: Implement chat screen
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Chat feature coming soon!',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.exit_to_app),
                                      label: Text('Leave Room'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: Text('Leave Room'),
                                                content: Text(
                                                  'Are you sure you want to leave this room?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: Text('Leave'),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await memberDoc.delete();
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'You have left the room.',
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to leave room: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
