import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';

class JoinRoomDetailsDialog extends StatefulWidget {
  final String roomCode;
  final String roomName;
  
  const JoinRoomDetailsDialog({
    super.key,
    required this.roomCode,
    required this.roomName,
  });

  @override
  _JoinRoomDetailsDialogState createState() => _JoinRoomDetailsDialogState();
}

class _JoinRoomDetailsDialogState extends State<JoinRoomDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _contact = '';
  String _address = '';
  bool _isLoading = false;
  String? _error;

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _formKey.currentState!.save();
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      
      await roomProvider.joinRoom(
        roomCode: widget.roomCode,
        formData: {
          'name': _name,
          'contact': _contact,
          'address': _address,
        },
      );
      
      Navigator.of(context).pop(true); // Success
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Join ${widget.roomName}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Please provide your information to join the room',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              _buildFormField(
                label: 'Name',
                hint: 'Enter your name',
                icon: Icons.person,
                onSaved: (value) => _name = value ?? '',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildFormField(
                label: 'Contact Number',
                hint: 'Enter with country code (e.g., +1234567890)',
                icon: Icons.phone,
                onSaved: (value) => _contact = value ?? '',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your contact number';
                  }
                  // Basic check for country code
                  if (!value.startsWith('+')) {
                    return 'Include country code (e.g., +1)';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildFormField(
                label: 'Address',
                hint: 'Enter your address',
                icon: Icons.home,
                onSaved: (value) => _address = value ?? '',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your address';
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
                    onPressed: _isLoading ? null : _joinRoom,
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
                        : Text('Join'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: Icon(icon),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
} 