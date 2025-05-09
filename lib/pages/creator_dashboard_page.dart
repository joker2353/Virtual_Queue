import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:virtual_queue/providers/room_provider.dart' show RoomProvider;

class CreatorDashboardPage extends StatefulWidget {
  final String roomId;
  const CreatorDashboardPage({required this.roomId, super.key});

  @override
  State<CreatorDashboardPage> createState() => _CreatorDashboardPageState();
}

class _CreatorDashboardPageState extends State<CreatorDashboardPage> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final roomDoc = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);

    return ChangeNotifierProvider(
      create:
          (_) => RoomProvider(userId: FirebaseAuth.instance.currentUser!.uid),
      child: Consumer<RoomProvider>(
        builder: (context, roomProvider, _) {
          return Scaffold(
            appBar: AppBar(title: Text('Creator Dashboard')),
            body: StreamBuilder<DocumentSnapshot>(
              stream: roomDoc.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final currentPosition = data['currentPosition'] ?? 1;
                final notice = data['notice'] ?? '';
                final status = data['status'] ?? 'open';

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
                                  Icons.verified_user,
                                  color: Colors.green,
                                  size: 32,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Room: ${data['name']}',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Spacer(),
                                Chip(
                                  label: Text(status.toUpperCase()),
                                  backgroundColor:
                                      status == 'open'
                                          ? Colors.green[100]
                                          : Colors.red[100],
                                  labelStyle: TextStyle(
                                    color:
                                        status == 'open'
                                            ? Colors.green[900]
                                            : Colors.red[900],
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 32),
                            Row(
                              children: [
                                Icon(
                                  Icons.format_list_numbered,
                                  color: Colors.deepPurple,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Current Position: ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '$currentPosition',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.announcement, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(child: Text('Notice: $notice')),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.arrow_forward),
                                    label: Text('Progress'),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed:
                                        _loading
                                            ? null
                                            : () async {
                                              setState(() => _loading = true);
                                              try {
                                                await roomDoc.update({
                                                  'currentPosition':
                                                      currentPosition + 1,
                                                });
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Failed: $e'),
                                                  ),
                                                );
                                              } finally {
                                                setState(
                                                  () => _loading = false,
                                                );
                                              }
                                            },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.arrow_back),
                                    label: Text('Decrease'),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed:
                                        _loading
                                            ? null
                                            : () async {
                                              setState(() => _loading = true);
                                              try {
                                                await roomDoc.update({
                                                  'currentPosition':
                                                      currentPosition > 1
                                                          ? currentPosition - 1
                                                          : 1,
                                                });
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Failed: $e'),
                                                  ),
                                                );
                                              } finally {
                                                setState(
                                                  () => _loading = false,
                                                );
                                              }
                                            },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.edit),
                                    label: Text('Edit Notice'),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed:
                                        _loading
                                            ? null
                                            : () async {
                                              final controller =
                                                  TextEditingController(
                                                    text: notice,
                                                  );
                                              final result = await showDialog<
                                                String
                                              >(
                                                context: context,
                                                builder:
                                                    (context) => AlertDialog(
                                                      title: Text(
                                                        'Edit Notice',
                                                      ),
                                                      content: TextField(
                                                        controller: controller,
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                  ),
                                                          child: Text('Cancel'),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    controller
                                                                        .text,
                                                                  ),
                                                          child: Text('Save'),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                              if (result != null) {
                                                setState(() => _loading = true);
                                                try {
                                                  await roomDoc.update({
                                                    'notice': result,
                                                  });
                                                } catch (e) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Failed: $e',
                                                      ),
                                                    ),
                                                  );
                                                } finally {
                                                  setState(
                                                    () => _loading = false,
                                                  );
                                                }
                                              }
                                            },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.refresh),
                                    label: Text('Reset Position'),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed:
                                        _loading
                                            ? null
                                            : () async {
                                              setState(() => _loading = true);
                                              try {
                                                await roomDoc.update({
                                                  'currentPosition': 1,
                                                });
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Failed: $e'),
                                                  ),
                                                );
                                              } finally {
                                                setState(
                                                  () => _loading = false,
                                                );
                                              }
                                            },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: Icon(
                                Icons.stop_circle,
                                color: Colors.white,
                              ),
                              label: Text('End Room'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  _loading
                                      ? null
                                      : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: Text('End Room'),
                                                content: Text(
                                                  'Are you sure you want to end this room? This cannot be undone.',
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
                                                    child: Text('End Room'),
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
                                          setState(() => _loading = true);
                                          try {
                                            await roomDoc.update({
                                              'status': 'closed',
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Room ended.'),
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed: $e'),
                                              ),
                                            );
                                          } finally {
                                            setState(() => _loading = false);
                                          }
                                        }
                                      },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Pending Join Requests',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    JoinRequestsList(roomId: widget.roomId),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class JoinRequestsList extends StatelessWidget {
  final String roomId;
  const JoinRequestsList({required this.roomId, super.key});

  @override
  Widget build(BuildContext context) {
    final joinRequests =
        FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .collection('joinRequests')
            .where('status', isEqualTo: 'pending')
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: joinRequests,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return Center(child: Text('No pending join requests.'));
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final formData = data['formData'] as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.person, color: Colors.deepPurple),
                title: Text(
                  formData['name'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contact: ${formData['contact'] ?? ''}'),
                    Text('Address: ${formData['address'] ?? ''}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Accept',
                      child: IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('rooms')
                                .doc(roomId)
                                .collection('members')
                                .doc(data['userId'])
                                .set({
                                  'userId': data['userId'],
                                  'joinData': formData,
                                  'joinedAt': FieldValue.serverTimestamp(),
                                });
                            await docs[index].reference.update({
                              'status': 'accepted',
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Request accepted!')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Decline',
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          await docs[index].reference.update({
                            'status': 'declined',
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Request declined.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
