import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import 'join_room_details_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:developer' as developer;

class JoinRoomCodeDialog extends StatefulWidget {
  const JoinRoomCodeDialog({super.key});

  @override
  _JoinRoomCodeDialogState createState() => _JoinRoomCodeDialogState();
}

class _JoinRoomCodeDialogState extends State<JoinRoomCodeDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();
  
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
    _codeController.dispose();
    _scannerController.dispose();
    _animationController.dispose();
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

  void _toggleQRScanner() {
    setState(() {
      _isScanning = !_isScanning;
    });
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
                            Colors.blue.shade600,
                            Colors.blue.shade800,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _isScanning ? Icons.qr_code_scanner : Icons.login,
                            color: Colors.white,
                            size: 56,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Join a Room',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            _isScanning 
                              ? 'Scan QR code to join' 
                              : 'Enter the room code to join the queue',
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isScanning)
                                  _buildScannerSection()
                                else
                                  _buildManualEntrySection(),
                                  
                                if (_error != null && !_isScanning)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
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
                                
                                if (!_isScanning)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24.0),
                                    child: Row(
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
                                            onPressed: _isLoading ? null : _verifyRoomCode,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue.shade600,
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
                                                    'Continue',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
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
  
  Widget _buildScannerSection() {
    return Container(
      height: 320,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            final code = barcode.rawValue!;
                            developer.log('Barcode found! $code');
                            _scannerController.stop();
                            setState(() {
                              _codeController.text = code;
                              _isScanning = false;
                            });
                          }
                        }
                      },
                    ),
                  ),
                  
                  // Scan frame overlay
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _toggleQRScanner,
            icon: Icon(Icons.keyboard),
            label: Text('Enter Code Manually'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildManualEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room Code',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _codeController,
          decoration: InputDecoration(
            hintText: 'Enter 6-digit room code',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: Icon(Icons.numbers, color: Colors.blue.shade600),
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
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 2, // Spacing between characters
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
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
        SizedBox(height: 20),
        Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _toggleQRScanner,
            icon: Icon(Icons.qr_code_scanner),
            label: Text('Scan QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.grey.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          ),
        ),
        SizedBox(height: 16),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'Enter the 6-digit code provided by the room creator or scan the QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 