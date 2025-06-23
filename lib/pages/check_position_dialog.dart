import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import 'position_details_page.dart';

class CheckPositionDialog extends StatefulWidget {
  const CheckPositionDialog({super.key});

  @override
  State<CheckPositionDialog> createState() => _CheckPositionDialogState();
}

class _CheckPositionDialogState extends State<CheckPositionDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _showQRScanner = false;
  String _errorMessage = '';

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _roomCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleQRScanner() {
    setState(() {
      _showQRScanner = !_showQRScanner;
      _errorMessage = '';
    });
  }

  void _onQRCodeScanned(BarcodeCapture capture) {
    final String? code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      setState(() {
        _roomCodeController.text = code;
        _showQRScanner = false;
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _checkPosition() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);

      // Find member by room code and phone number
      final memberData = await roomProvider.findMemberByPhoneAndCode(
        roomCode: _roomCodeController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      if (memberData != null) {
        // Navigate to position details page
        Navigator.of(context).pop(); // Close dialog
        PositionDetailsPage.navigate(
          context,
          roomId: memberData['roomId'],
          memberId: memberData['memberId'],
          phoneNumber: _phoneController.text.trim(),
        );
      } else {
        setState(() {
          _errorMessage =
              'No queue member found with this room code and phone number. Please verify your details.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking position: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade50],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: _showQRScanner ? _buildQRScanner() : _buildForm(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.queue_rounded,
                  color: Colors.deepPurple.shade800,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check Position',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      'Enter your details to view queue status',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.grey[600]),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[50],
                  padding: EdgeInsets.all(8),
                ),
              ),
            ],
          ),

          SizedBox(height: 32),

          // Form
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Room Code Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _roomCodeController,
                    decoration: InputDecoration(
                      labelText: 'Room Code',
                      hintText: 'Enter 6-digit room code',
                      prefixIcon: Icon(
                        Icons.meeting_room,
                        color: Colors.deepPurple.shade600,
                      ),
                      suffixIcon: IconButton(
                        onPressed: _toggleQRScanner,
                        icon: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.deepPurple.shade600,
                        ),
                        tooltip: 'Scan QR Code',
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(6),
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter room code';
                      }
                      if (value.trim().length != 6) {
                        return 'Room code must be 6 characters';
                      }
                      return null;
                    },
                  ),
                ),

                SizedBox(height: 20),

                // Phone Number Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter your phone number',
                      prefixIcon: Icon(
                        Icons.phone,
                        color: Colors.deepPurple.shade600,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.trim().length < 10) {
                        return 'Phone number must be at least 10 digits';
                      }
                      return null;
                    },
                  ),
                ),

                if (_errorMessage.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 32),

                // Check Position Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _checkPosition,
                    icon:
                        _isLoading
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Icon(Icons.search, size: 20),
                    label: Text(
                      _isLoading ? 'Checking...' : 'Check My Position',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Help text
          Text(
            'Enter the room code and phone number you used when joining the queue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Container(
      height: 400,
      child: Column(
        children: [
          // Scanner Header
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                IconButton(
                  onPressed: _toggleQRScanner,
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.grey[700],
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[50],
                    padding: EdgeInsets.all(8),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey[700]),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[50],
                    padding: EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          // QR Scanner
          Expanded(
            child: Container(
              margin: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.deepPurple.shade300, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: MobileScanner(
                  onDetect: _onQRCodeScanned,
                  overlay: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.deepPurple.shade400,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Scanner instructions
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Position the QR code within the frame to scan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
