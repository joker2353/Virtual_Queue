import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/saved_prescription.dart';

class SavePrescriptionDialog extends StatefulWidget {
  final List<String> imageUrls;
  final String? audioUrl;

  const SavePrescriptionDialog({
    super.key,
    required this.imageUrls,
    this.audioUrl,
  });

  @override
  _SavePrescriptionDialogState createState() => _SavePrescriptionDialogState();
}

class _SavePrescriptionDialogState extends State<SavePrescriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        // Try to get user from cache or wait for authentication
        await Future.delayed(Duration(milliseconds: 500));
        final refreshedUser = authProvider.user;
        if (refreshedUser == null) {
          throw Exception('User not authenticated. Please log in again.');
        }
      }

      final userId = user?.uid ?? authProvider.user?.uid;
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not available. Please log in again.');
      }

      print('DEBUG: Saving prescription for user: $userId');

      final firestoreInstance = firestore.FirebaseFirestore.instance;

      // Add a small delay to show loading state
      await Future.delayed(Duration(milliseconds: 300));

      // Check if name already exists
      final existingQuery =
          await firestoreInstance
              .collection('saved_prescriptions')
              .where('userId', isEqualTo: userId)
              .where('name', isEqualTo: _nameController.text.trim())
              .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('A prescription with this name already exists');
      }

      // Create saved prescription
      final savedPrescription = SavedPrescription(
        id: '', // Will be set by Firestore
        userId: userId,
        name: _nameController.text.trim(),
        imageUrls: widget.imageUrls,
        audioUrl: widget.audioUrl,
        createdAt: DateTime.now(),
      );

      await firestoreInstance
          .collection('saved_prescriptions')
          .add(savedPrescription.toMap());

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prescription "${_nameController.text.trim()}" saved successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String errorMessage = 'Error saving prescription';
      if (e.toString().contains('not authenticated')) {
        errorMessage =
            'Authentication error. Please try again or log in again.';
      } else {
        errorMessage = 'Error saving prescription: $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.save, color: Colors.teal, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Save Prescription',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Give your prescription a name so you can reuse it later:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Prescription Name *',
                  hintText: 'e.g., Monthly Medicine, Blood Pressure',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.medical_services),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Please enter a name';
                  }
                  if (value!.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.teal.shade700,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will save ${widget.imageUrls.length} images${widget.audioUrl != null ? ' and audio recording' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePrescription,
                    child:
                        _isSaving
                            ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
