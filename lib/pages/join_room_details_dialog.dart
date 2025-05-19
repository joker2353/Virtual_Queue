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

class _JoinRoomDetailsDialogState extends State<JoinRoomDetailsDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _contact = '';
  String _address = '';
  bool _isLoading = false;
  String? _error;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<double>(
      begin: 30,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuad,
    ));
    
    // Start animations
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeInAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 25,
                    spreadRadius: 5,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.teal.shade400,
                            Colors.teal.shade700,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add,
                            color: Colors.white,
                            size: 56,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Join ${widget.roomName}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Please provide your information to join the queue',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputField(
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
                                SizedBox(height: 20),
                                _buildInputField(
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
                                SizedBox(height: 20),
                                _buildInputField(
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
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: TextStyle(color: Colors.red.shade800),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                
                                SizedBox(height: 30),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          side: BorderSide(color: Colors.grey.shade300),
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _joinRoom,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? LoadingIndicator(
                                                size: 24,
                                                message: null,
                                                primaryColor: Colors.white,
                                                backgroundColor: Colors.transparent,
                                              )
                                            : Text(
                                                'Join Queue',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: Icon(icon, color: Colors.teal),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          validator: validator,
          onSaved: onSaved,
        ),
      ],
    );
  }
} 