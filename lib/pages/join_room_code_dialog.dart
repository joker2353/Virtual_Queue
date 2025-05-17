import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import 'join_room_details_dialog.dart';

class JoinRoomCodeDialog extends StatefulWidget {
  const JoinRoomCodeDialog({super.key});

  @override
  _JoinRoomCodeDialogState createState() => _JoinRoomCodeDialogState();
}

class _JoinRoomCodeDialogState extends State<JoinRoomCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyRoomCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      
      // Verify the room code exists
      final roomDetails = await roomProvider.verifyRoomCode(_codeController.text.trim());
      
      // If the code is valid, show the next dialog to enter user details
      if (!mounted) return;
      
      // Close the current dialog
      Navigator.of(context).pop();
      
      // Show the details dialog
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => JoinRoomDetailsDialog(
          roomCode: _codeController.text.trim(),
          roomName: roomDetails.name,
        ),
      );
      
      // Return the result to the caller
      if (mounted && result == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Join a Room',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Room Code',
                hintText: 'Enter 6-digit room code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter room code';
                }
                if (value.length != 6 || int.tryParse(value) == null) {
                  return 'Please enter a valid 6-digit code';
                }
                return null;
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyRoomCode,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: LoadingIndicator(
                            size: 20,
                            showMessage: false,
                            color: Colors.white,
                          ),
                        )
                      : Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 