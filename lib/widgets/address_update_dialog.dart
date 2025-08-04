import 'package:flutter/material.dart';

class AddressUpdateDialog extends StatefulWidget {
  final String? currentAddress;
  final Function(String) onAddressUpdated;

  const AddressUpdateDialog({
    Key? key,
    this.currentAddress,
    required this.onAddressUpdated,
  }) : super(key: key);

  @override
  State<AddressUpdateDialog> createState() => _AddressUpdateDialogState();
}

class _AddressUpdateDialogState extends State<AddressUpdateDialog> {
  late TextEditingController _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentAddress ?? '');
    _controller.addListener(_validateAddress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAddress() {
    final address = _controller.text.trim();
    setState(() {
      _isValid = address.isNotEmpty;
    });
  }

  void _updateAddress() {
    final address = _controller.text.trim();
    if (_isValid) {
      widget.onAddressUpdated(address);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_location, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Update Delivery Address'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please provide your complete delivery address:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter your complete delivery address...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: Icon(Icons.home, color: Colors.grey[600]),
            ),
            onChanged: (value) => _validateAddress(),
          ),
          if (!_isValid)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Please enter a valid delivery address',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Include area, road, and any landmarks for better delivery',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid ? _updateAddress : null,
          child: Text('Update Address'),
        ),
      ],
    );
  }
}
