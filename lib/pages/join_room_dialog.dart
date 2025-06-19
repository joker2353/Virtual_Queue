import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import 'join_room_code_dialog.dart';

class JoinRoomDialog extends StatelessWidget {
  const JoinRoomDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // Capture the RoomProvider from context
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    // Show the first dialog in the sequence for room code entry with provider
    return JoinRoomCodeDialog(roomProvider: roomProvider);
  }
}
