import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'dart:io';
import '../models/prescription_order.dart';

class PrescriptionPreviewPage extends StatefulWidget {
  final List<String> imagePaths;
  final String roomId;
  final String customerName;
  final String customerContact;

  const PrescriptionPreviewPage({
    super.key,
    required this.imagePaths,
    required this.roomId,
    required this.customerName,
    required this.customerContact,
  });

  @override
  _PrescriptionPreviewPageState createState() =>
      _PrescriptionPreviewPageState();
}

class _PrescriptionPreviewPageState extends State<PrescriptionPreviewPage> {
  PageController _pageController = PageController();
  int _currentIndex = 0;

  // Audio recording
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;
  bool _hasRecording = false;

  // Upload state
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  Future<void> _initializeAudio() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review Prescription'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isUploading ? null : _submitPrescription,
            icon:
                _isUploading
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator for upload
          if (_isUploading)
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Uploading prescription... ${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(color: Colors.teal),
                  ),
                ],
              ),
            ),

          // Image counter
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Image ${_currentIndex + 1} of ${widget.imagePaths.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Swipe to navigate',
                    style: TextStyle(color: Colors.teal.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Audio recording section
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mic, color: Colors.blue.shade700),
                    SizedBox(width: 8),
                    Text(
                      'Voice Instructions (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    // Record button
                    ElevatedButton.icon(
                      onPressed:
                          _isRecording ? _stopRecording : _startRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isRecording ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Stop Recording' : 'Record'),
                    ),

                    SizedBox(width: 12),

                    // Play button (if recording exists)
                    if (_hasRecording && !_isRecording)
                      ElevatedButton.icon(
                        onPressed: _isPlaying ? _stopPlaying : _playRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Pause' : 'Play'),
                      ),

                    // Delete recording button
                    if (_hasRecording && !_isRecording)
                      IconButton(
                        onPressed: _deleteRecording,
                        icon: Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete recording',
                      ),
                  ],
                ),

                if (_isRecording)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.red,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Recording...',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                if (_hasRecording && !_isRecording)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Recording saved',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Image preview with zoom
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.imagePaths.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.file(
                        File(widget.imagePaths[index]),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Navigation dots
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imagePaths.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentIndex == index
                            ? Colors.teal
                            : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),

          // Submit button
          Container(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _submitPrescription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon:
                    _isUploading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Icon(Icons.send),
                label: Text(
                  _isUploading ? 'Submitting...' : 'Submit Prescription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        _showPermissionDialog('Microphone');
        return;
      }

      final directory = await getTemporaryDirectory();
      _audioPath =
          '${directory.path}/prescription_audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder!.startRecorder(toFile: _audioPath, codec: Codec.aacADTS);

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting recording: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping recording: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _playRecording() async {
    if (_audioPath == null) return;

    // Check if file exists
    final audioFile = File(_audioPath!);
    print('Audio file path: $_audioPath');
    print('Audio file exists: ${await audioFile.exists()}');
    print('Audio file size: ${await audioFile.length()} bytes');

    if (!await audioFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio file not found'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Stop any currently playing audio
      if (_isPlaying) {
        await _player!.stopPlayer();
      }

      // Check if file has content
      final fileSize = await audioFile.length();
      if (fileSize < 100) {
        // Minimum file size for audio
        print('Recording file is too small or empty');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording file is too small or empty'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _isPlaying = true;
      });

      // Play the recording using FlutterSoundPlayer
      await _player!.startPlayer(
        fromURI: _audioPath!,
        whenFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
          print('Playback completed');
        },
      );

      print('Playback started');
    } catch (e) {
      setState(() {
        _isPlaying = false;
      });
      print('Error playing recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing recording: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopPlaying() async {
    try {
      await _player!.stopPlayer();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  void _deleteRecording() {
    setState(() {
      _hasRecording = false;
      _audioPath = null;
      _isPlaying = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording deleted'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPermissionDialog(String permissionType) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Permission Required'),
            content: Text(
              '$permissionType permission is required to record audio instructions. Please grant permission in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  Future<void> _submitPrescription() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      List<String> uploadedImageUrls = [];
      String? uploadedAudioUrl;

      // Upload images to Firebase Storage
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final imageFile = File(widget.imagePaths[i]);
        final fileName =
            'prescriptions/${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putFile(imageFile);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress =
              (i + snapshot.bytesTransferred / snapshot.totalBytes) /
              widget.imagePaths.length;
          setState(() {
            _uploadProgress =
                progress * 0.8; // Reserve 20% for audio and order creation
          });
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedImageUrls.add(downloadUrl);
      }

      // Upload audio if exists
      if (_hasRecording && _audioPath != null) {
        setState(() {
          _uploadProgress = 0.85;
        });

        final audioFile = File(_audioPath!);
        final audioFileName =
            'prescriptions/${widget.roomId}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

        final audioStorageRef = FirebaseStorage.instance.ref().child(
          audioFileName,
        );
        final audioUploadTask = audioStorageRef.putFile(audioFile);

        final audioSnapshot = await audioUploadTask;
        uploadedAudioUrl = await audioSnapshot.ref.getDownloadURL();
      }

      setState(() {
        _uploadProgress = 0.95;
      });

      // Create prescription order in Firestore
      final prescriptionOrder = PrescriptionOrder(
        id: '',
        roomId: widget.roomId,
        userId: '',
        customerName: widget.customerName,
        customerContact: widget.customerContact,
        prescriptionImageUrls: uploadedImageUrls,
        audioInstructionUrl: uploadedAudioUrl,
        totalAmount: 0.0, // Will be set by the shop owner
        status: 'pending',
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
      );

      final docRef = await firestore.FirebaseFirestore.instance
          .collection('prescription_orders')
          .add(prescriptionOrder.toMap());

      setState(() {
        _uploadProgress = 1.0;
      });

      print('Prescription order created with ID: ${docRef.id}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back to medical customer page
      Navigator.pop(context); // Pop preview page
      Navigator.pop(context); // Pop upload page
    } catch (e) {
      print('Error submitting prescription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting prescription: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }
}
