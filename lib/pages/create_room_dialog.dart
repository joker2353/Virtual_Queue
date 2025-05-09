import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import '../pages/creator_dashboard_page.dart';

class CreateRoomDialog extends StatefulWidget {
  const CreateRoomDialog({super.key});

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  String roomName = '';
  int capacity = 1;
  String notice = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Room'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Room Name'),
                onChanged: (v) => roomName = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
                initialValue: '1',
                onChanged: (v) => capacity = int.tryParse(v) ?? 1,
                validator:
                    (v) =>
                        v == null || int.tryParse(v) == null || int.parse(v) < 1
                            ? 'Enter a valid number'
                            : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Initial Notice'),
                onChanged: (v) => notice = v,
              ),
              // For simplicity, formSchema is fixed for now
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Form fields: Name, Contact, Address (default)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('Create'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final roomProvider = Provider.of<RoomProvider>(
                context,
                listen: false,
              );
              final roomId = await roomProvider.createRoom(
                roomName,
                capacity,
                notice,
                [
                  {'fieldId': 'name', 'label': 'Name', 'type': 'string'},
                  {
                    'fieldId': 'contact',
                    'label': 'Contact No.',
                    'type': 'string',
                  },
                  {'fieldId': 'address', 'label': 'Address', 'type': 'string'},
                ],
              );
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatorDashboardPage(roomId: roomId),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

String generateRoomCode() {
  final random = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
  return random.toString().padLeft(6, '0');
}
