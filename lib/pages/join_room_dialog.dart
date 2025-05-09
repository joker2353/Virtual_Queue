import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';

class JoinRoomDialog extends StatefulWidget {
  const JoinRoomDialog({super.key});

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  String roomCode = '';
  String name = '';
  String contact = '';
  String address = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Join Room'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: '6-digit Room Code'),
                maxLength: 6,
                keyboardType: TextInputType.number,
                onChanged: (v) => roomCode = v,
                validator:
                    (v) => v == null || v.length != 6 ? 'Enter 6 digits' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Name'),
                onChanged: (v) => name = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => contact = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Address'),
                onChanged: (v) => address = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
          child: Text('Join'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final roomProvider = Provider.of<RoomProvider>(
                context,
                listen: false,
              );
              await roomProvider.sendJoinRequest(roomCode, {
                'name': name,
                'contact': contact,
                'address': address,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Join request sent!')));
            }
          },
        ),
      ],
    );
  }
}
