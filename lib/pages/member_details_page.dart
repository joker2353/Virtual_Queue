import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/room.dart';
import '../models/membership.dart';
import '../models/user_room.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';

class MemberDetailsPage extends StatefulWidget {
  final String roomId;

  const MemberDetailsPage({required this.roomId, super.key});

  @override
  _MemberDetailsPageState createState() => _MemberDetailsPageState();
}

class _MemberDetailsPageState extends State<MemberDetailsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  Room? _room;
  Membership? _membership;
  UserRoom? _userRoom;
  String? _error;
  DateTime? _waitingSince;
  
  // For countdown timer
  Timer? _countdownTimer;
  String _timeLeft = '00:00';
  int _estimatedMinutes = 0;
  
  // For animation controller
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  
  // Stream subscriptions for real-time updates
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<DocumentSnapshot>? _membershipSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    
    _colorAnimation = ColorTween(
      begin: Colors.orange.shade600,
      end: Colors.green.shade600,
    ).animate(_animationController);
    
    _animationController.repeat(reverse: true);
    
    _setupRealtimeUpdates();
  }
  
  @override
  void dispose() {
    // Cancel subscriptions when the page is disposed
    _roomSubscription?.cancel();
    _membershipSubscription?.cancel();
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  
  void _setupRealtimeUpdates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception('User not signed in');
      }
      
      // Get room stream
      final roomRef = firestore.collection('rooms').doc(widget.roomId);
      _roomSubscription = roomRef.snapshots().listen(
        (roomSnapshot) {
          if (!roomSnapshot.exists) {
            setState(() {
              _error = 'Room not found';
              _isLoading = false;
            });
            return;
          }
          
          setState(() {
            _room = Room.fromMap(widget.roomId, roomSnapshot.data()!);
            _error = null;
            _isLoading = false;
            
            // Update the UserRoom with latest room details
            if (_userRoom != null && _room != null) {
              _userRoom = _userRoom!.copyWith(
                currentPosition: _room!.currentPosition,
                memberCount: _room!.memberCount,
              );
              
              // Update countdown timer when room details change
              _startCountdownTimer();
            }
          });
        },
        onError: (error) {
          setState(() {
            _error = 'Failed to load room: $error';
            _isLoading = false;
          });
        }
      );
      
      // Get membership stream
      final membershipId = '${widget.roomId}_${user.uid}';
      final membershipRef = firestore.collection('memberships').doc(membershipId);
      _membershipSubscription = membershipRef.snapshots().listen(
        (membershipSnapshot) {
          if (!membershipSnapshot.exists) {
            setState(() {
              _error = 'You are not a member of this room';
              _isLoading = false;
            });
            return;
          }
          
          setState(() {
            _membership = Membership.fromMap(membershipId, membershipSnapshot.data()!);
            
            // Calculate waiting time
            if (_membership!.timestamps.approved != null) {
              _waitingSince = _membership!.timestamps.approved;
            }
            
            // Create/update UserRoom with latest data
            if (_room != null) {
              _userRoom = UserRoom(
                roomId: widget.roomId,
                name: _room!.name,
                type: 'joined',
                status: _membership!.status,
                position: _membership!.position,
                currentPosition: _room!.currentPosition,
                memberCount: _room!.memberCount,
                joinedAt: _membership!.timestamps.approved ?? _membership!.timestamps.requested,
              );
              
              // Start countdown timer when membership details are loaded
              _startCountdownTimer();
            }
            
            _error = null;
            _isLoading = false;
          });
        },
        onError: (error) {
          setState(() {
            _error = 'Failed to load membership: $error';
            _isLoading = false;
          });
        }
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _startCountdownTimer() {
    // Cancel existing timer if running
    _countdownTimer?.cancel();
    
    if (_userRoom == null || _room == null) return;
    
    final isUserTurn = _userRoom!.isCurrentlyServed;
    
    if (isUserTurn) {
      setState(() {
        _timeLeft = "It's your turn!";
        _estimatedMinutes = 0;
      });
      return;
    }
    
    // Calculate estimated minutes based on position and average service time
    // Using a fixed average service time of 3 minutes per person
    const int averageServiceTime = 3;
    
    _estimatedMinutes = _userRoom!.waitingCount * averageServiceTime;
    
    // Initialize the countdown
    _updateCountdown();
    
    // Start a timer to update the countdown every minute
    _countdownTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (_estimatedMinutes <= 0) {
        timer.cancel();
      } else {
        _estimatedMinutes--;
        _updateCountdown();
      }
    });
  }
  
  void _updateCountdown() {
    if (_estimatedMinutes <= 0) {
      setState(() {
        _timeLeft = "Any moment now!";
      });
      return;
    }
    
    int hours = _estimatedMinutes ~/ 60;
    int minutes = _estimatedMinutes % 60;
    
    setState(() {
      if (hours > 0) {
        _timeLeft = "${hours}h ${minutes}m";
      } else {
        _timeLeft = "${minutes}m";
      }
    });
  }
  
  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave Room'),
        content: Text('Are you sure you want to leave this room? You will lose your position in the queue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text('Leave Room'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      await roomProvider.leaveRoom(widget.roomId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have left the room'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.deepPurple,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Queue Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.deepPurple.shade50],
            stops: [0.0, 0.3],
          ),
        ),
        child: _isLoading && _room == null
            ? Center(
                child: LoadingIndicator(
                  message: 'Loading queue details...',
                  primaryColor: Colors.white,
                  backgroundColor: Colors.deepPurple.shade300,
                  icon: Icons.queue,
                ),
              )
            : _error != null
                ? _buildErrorView()
                : _buildDetailsView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 70, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: _setupRealtimeUpdates,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsView() {
    if (_room == null || _membership == null || _userRoom == null) {
      return Center(
        child: LoadingIndicator(
          message: 'Loading room details...',
          primaryColor: Colors.deepPurple.shade300,
          backgroundColor: Colors.white,
          icon: Icons.people,
        ),
      );
    }
    
    final room = _room!;
    final membership = _membership!;
    final userRoom = _userRoom!;
    
    // Calculate time details
    String waitingTime = 'N/A';
    if (_waitingSince != null) {
      final duration = DateTime.now().difference(_waitingSince!);
      if (duration.inDays > 0) {
        waitingTime = '${duration.inDays} days, ${duration.inHours.remainder(24)} hours';
      } else if (duration.inHours > 0) {
        waitingTime = '${duration.inHours} hours, ${duration.inMinutes.remainder(60)} minutes';
      } else {
        waitingTime = '${duration.inMinutes} minutes';
      }
    }
    
    // Calculate position details
    final waitingCount = userRoom.waitingCount;
    final isBeingServed = userRoom.isCurrentlyServed;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      physics: BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRoomHeader(room),
          SizedBox(height: 20),
          _buildStatusCard(userRoom, isBeingServed),
          SizedBox(height: 20),
          _buildProgressCard(waitingTime, userRoom),
          SizedBox(height: 20),
          _buildNoticeBoard(room),
          SizedBox(height: 20),
          _buildActionButtons(),
          SizedBox(height: 20), // Extra padding at bottom
        ],
      ),
    );
  }
  
  Widget _buildRoomHeader(Room room) {
    return Card(
      elevation: 6,
      shadowColor: Colors.deepPurple.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.deepPurple.shade50],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.meeting_room,
                  color: Colors.deepPurple,
                  size: 36,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.deepPurple.shade400),
                        SizedBox(width: 4),
                        Text(
                          'Capacity: ${room.capacity} members',
                          style: TextStyle(
                            color: Colors.deepPurple.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusCard(UserRoom userRoom, bool isBeingServed) {
    return Card(
      elevation: 6,
      shadowColor: Colors.deepPurple.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.white, Colors.deepPurple.shade50],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Your Queue Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusItem(
                    'Your Position',
                    '#${userRoom.position}',
                    Icons.person_pin,
                    Colors.blue.shade600,
                  ),
                  _buildStatusItem(
                    'Current Serving',
                    '#${userRoom.currentPosition}',
                    Icons.call_missed_outgoing,
                    Colors.green.shade600,
                  ),
                  _buildStatusItem(
                    'People Ahead',
                    userRoom.waitingCount.toString(),
                    Icons.people,
                    Colors.orange.shade600,
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                decoration: BoxDecoration(
                  color: isBeingServed ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBeingServed ? Colors.green.shade300 : Colors.orange.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isBeingServed ? Colors.green : Colors.orange).withOpacity(0.1),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isBeingServed ? Icons.check_circle : Icons.access_time,
                      color: isBeingServed ? Colors.green.shade700 : Colors.orange.shade700,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isBeingServed
                            ? 'It\'s your turn now! 🎉'
                            : userRoom.waitingCount > 0
                                ? 'Please wait, there are ${userRoom.waitingCount} people ahead of you'
                                : 'Almost your turn, get ready!',
                        style: TextStyle(
                          color: isBeingServed ? Colors.green.shade800 : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String waitingTime, UserRoom userRoom) {
    // Calculate progress value (0.0 to 1.0)
    double progressValue = 0.0;
    bool isUserTurn = userRoom.isCurrentlyServed;
    
    // If user has position greater than 0 (not creator) and there's a current position
    if (userRoom.position > 0 && userRoom.currentPosition > 0) {
      // If it's user's turn, set progress to 1.0
      if (isUserTurn) {
        progressValue = 1.0;
      } else if (userRoom.position > userRoom.currentPosition) {
        // Calculate how close user is to being served
        int totalPeopleInQueue = userRoom.memberCount - 1; // Excluding creator
        int peopleAlreadyServed = userRoom.currentPosition;
        
        // Prevent division by zero
        if (totalPeopleInQueue > 0) {
          progressValue = peopleAlreadyServed / totalPeopleInQueue;
        }
      }
    }
    
    // Clamp value between 0 and 1
    progressValue = progressValue.clamp(0.0, 1.0);
    
    // Define colors based on progress
    Color progressColor = isUserTurn ? Colors.green.shade600 : Colors.deepPurple.shade600;
    Color bgColor = isUserTurn ? Colors.green.shade50 : Colors.deepPurple.shade50;
    
    return Card(
      elevation: 6,
      shadowColor: isUserTurn ? Colors.green.withOpacity(0.3) : Colors.deepPurple.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, bgColor],
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  isUserTurn ? Icons.check_circle : Icons.timelapse, 
                  color: progressColor,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Queue Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bgColor,
                      boxShadow: [
                        BoxShadow(
                          color: progressColor.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 160,
                      width: 160,
                      child: CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 15,
                        backgroundColor: Colors.white.withOpacity(0.8),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                  ),
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '#${userRoom.position}',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                        Text(
                          isUserTurn ? 'Your Turn!' : 'Your Position',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 25),
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: isUserTurn ? Colors.green.shade100 : Colors.deepPurple.shade100,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: progressColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUserTurn 
                      ? Icons.check_circle_outline 
                      : Icons.timer,
                    color: progressColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    isUserTurn 
                      ? 'It\'s your turn now!'
                      : 'Time left: $_timeLeft',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (!isUserTurn) ...[
              SizedBox(height: 20),
              AnimatedBuilder(
                animation: _colorAnimation,
                builder: (context, child) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _colorAnimation.value ?? progressColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_active, 
                          color: _colorAnimation.value,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'We\'ll notify you when it\'s almost your turn',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeBoard(Room room) {
    return Card(
      elevation: 6,
      shadowColor: Colors.amber.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.amber.shade50],
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.announcement, color: Colors.amber[700], size: 24),
                SizedBox(width: 10),
                Text(
                  'Notice Board',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber[700],
                    size: 22,
                  ),
                  SizedBox(height: 10),
                  Text(
                    room.notice.isNotEmpty
                        ? room.notice
                        : 'No notice available',
                    style: TextStyle(
                      color: Colors.amber[900],
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      elevation: 6,
      shadowColor: Colors.red.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.red.shade50],
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.red.shade700, size: 24),
                SizedBox(width: 10),
                Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: Icon(Icons.exit_to_app, size: 22),
                label: Text(
                  'Leave Queue',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  minimumSize: Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _leaveRoom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
