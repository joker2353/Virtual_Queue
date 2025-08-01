import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/saved_prescription.dart';
import '../widgets/loading_indicator.dart';
import 'prescription_preview_page.dart';

class SavedPrescriptionsPage extends StatefulWidget {
  final String roomId;
  final String customerName;
  final String customerContact;

  const SavedPrescriptionsPage({
    super.key,
    required this.roomId,
    required this.customerName,
    required this.customerContact,
  });

  @override
  _SavedPrescriptionsPageState createState() => _SavedPrescriptionsPageState();
}

class _SavedPrescriptionsPageState extends State<SavedPrescriptionsPage> {
  List<SavedPrescription> _savedPrescriptions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedPrescriptions();
  }

  Future<void> _loadSavedPrescriptions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

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

      print('DEBUG: Loading saved prescriptions for user: $userId');

      final firestoreInstance = firestore.FirebaseFirestore.instance;

      // Simple query without complex ordering to avoid index requirements
      final querySnapshot = await firestoreInstance
          .collection('saved_prescriptions')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(Duration(seconds: 10));

      final List<SavedPrescription> prescriptions = [];
      for (final doc in querySnapshot.docs) {
        prescriptions.add(SavedPrescription.fromMap(doc.id, doc.data()));
      }

      // Sort by creation date (newest first) in Dart code
      prescriptions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('DEBUG: Loaded ${prescriptions.length} saved prescriptions');

      setState(() {
        _savedPrescriptions = prescriptions;
        _isLoading = false;
      });
    } catch (e) {
      String errorMessage = 'Error loading saved prescriptions';

      if (e.toString().contains('timeout')) {
        errorMessage =
            'Request timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your authentication.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Error loading saved prescriptions: $e';
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePrescription(SavedPrescription prescription) async {
    try {
      final firestoreInstance = firestore.FirebaseFirestore.instance;
      await firestoreInstance
          .collection('saved_prescriptions')
          .doc(prescription.id)
          .delete();

      setState(() {
        _savedPrescriptions.removeWhere((p) => p.id == prescription.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription "${prescription.name}" deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting prescription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _usePrescription(SavedPrescription prescription) async {
    try {
      // Update usage count and last used
      final firestoreInstance = firestore.FirebaseFirestore.instance;
      await firestoreInstance
          .collection('saved_prescriptions')
          .doc(prescription.id)
          .update({
            'usageCount': prescription.usageCount + 1,
            'lastUsed': firestore.Timestamp.now(),
          });

      // Navigate to prescription preview with saved data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PrescriptionPreviewPage(
                imagePaths: prescription.imageUrls,
                roomId: widget.roomId,
                customerName: widget.customerName,
                customerContact: widget.customerContact,
                savedPrescription: prescription,
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error using prescription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Prescriptions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadSavedPrescriptions,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading saved prescriptions...',
              style: TextStyle(color: Colors.teal.shade700, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadSavedPrescriptions,
                  child: Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_savedPrescriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.teal.shade300),
            SizedBox(height: 16),
            Text(
              'No Saved Prescriptions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Save prescriptions to reuse them later',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _savedPrescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _savedPrescriptions[index];
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  Widget _buildPrescriptionCard(SavedPrescription prescription) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medical_services,
                      color: Colors.teal.shade700,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prescription.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${prescription.imageCount} images${prescription.hasAudio ? ' • Audio included' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'use') {
                        _usePrescription(prescription);
                      } else if (value == 'delete') {
                        _showDeleteDialog(prescription);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'use',
                            child: Row(
                              children: [
                                Icon(Icons.send, size: 16),
                                SizedBox(width: 8),
                                Text('Use Prescription'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                    child: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Created: ${_formatDate(prescription.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Spacer(),
                  if (prescription.lastUsed != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Last used: ${_formatDate(prescription.lastUsed!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.repeat, size: 14, color: Colors.grey.shade600),
                  SizedBox(width: 4),
                  Text(
                    'Used ${prescription.usageCount} times',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _usePrescription(prescription),
                    icon: Icon(Icons.send, size: 16),
                    label: Text('Use'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(SavedPrescription prescription) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Prescription'),
            content: Text(
              'Are you sure you want to delete "${prescription.name}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deletePrescription(prescription);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
