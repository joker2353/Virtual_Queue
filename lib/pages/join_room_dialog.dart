import 'package:flutter/material.dart';
import 'join_room_code_dialog.dart';

class JoinRoomDialog extends StatelessWidget {
  const JoinRoomDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // Show the first dialog in the sequence for room code entry
    return JoinRoomCodeDialog();
  }
}
