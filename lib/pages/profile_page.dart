import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import 'dart:async';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  int _roomsJoined = 0;
  int _roomsCreated = 0;
  int _totalTimeInQueues = 0; // in minutes
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _loadUserStats();
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _loadUserStats() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // In a real app, this would load from Firestore or other storage
      // For this demo, we'll just use placeholder data
      await Future.delayed(Duration(milliseconds: 800));
      
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      roomProvider.refreshRooms();
      
      setState(() {
        _roomsJoined = roomProvider.activeRooms.length + roomProvider.pendingRooms.length;
        _roomsCreated = roomProvider.createdRooms.length;
        _totalTimeInQueues = _calculateTotalQueueTime(roomProvider);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  int _calculateTotalQueueTime(RoomProvider roomProvider) {
    // This is a placeholder - in a real app, you'd calculate this from actual time spent data
    // For this demo, we'll just use a simulated value based on joined rooms
    return _roomsJoined * 15; // Assume average 15 minutes per queue
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(child: Text('Not signed in.')),
      );
    }
    
    return Scaffold(
      body: Stack(
        children: [
          // Top gradient background
          Container(
            height: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.deepPurple.shade800,
                  Colors.deepPurple.shade600,
                ],
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                children: [
                  // App bar with back button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'My Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 48), // Balance the layout
                      ],
                    ),
                  ),
                  
                  // Profile avatar and info
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildProfileHeader(user),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // User stats
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildStatsSection(),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // User activity
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildActivitySection(),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Sign out button
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildSignOutButton(auth, context),
                  ),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileHeader(user) {
    return Container(
      padding: EdgeInsets.only(bottom: 25),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child:
                  user.photoURL == null ? Icon(Icons.person, size: 60, color: Colors.deepPurple) : null,
            ),
          ),
          SizedBox(height: 15),
          Text(
            user.displayName ?? 'User',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(height: 5),
          Text(
            user.email ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.deepPurple),
              SizedBox(width: 10),
              Text(
                'Your Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _isLoading 
              ? Container(
                  height: 150,
                  child: Center(
                    child: LoadingIndicator(
                      message: 'Loading your stats...',
                      size: 80,
                      primaryColor: Colors.deepPurple,
                      backgroundColor: Colors.white,
                      icon: Icons.analytics,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.join_inner,
                      label: 'Joined',
                      value: _roomsJoined.toString(),
                      color: Colors.blue,
                    ),
                    _buildStatItem(
                      icon: Icons.create_new_folder,
                      label: 'Created',
                      value: _roomsCreated.toString(),
                      color: Colors.green,
                    ),
                    _buildStatItem(
                      icon: Icons.timer,
                      label: 'Time Saved',
                      value: _formatTime(_totalTimeInQueues),
                      color: Colors.orange,
                    ),
                  ],
                ),
        ],
      ),
    );
  }
  
  Widget _buildElegantLoader() {
    return Container(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated dots loading indicator
            Container(
              height: 60,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 6),
                        height: 12 + (8 * value),
                        width: 12 + (8 * value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple.withOpacity(0.2 + (0.6 * value)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.2 * value),
                              blurRadius: 10 * value,
                              spreadRadius: 2 * value,
                            )
                          ]
                        ),
                      );
                    },
                    onEnd: () {
                      if (mounted && _isLoading) {
                        Future.delayed(Duration(milliseconds: 100 * index), () {
                          setState(() {
                            // Trigger rebuild to restart animation
                          });
                        });
                      }
                    },
                  );
                }),
              ),
            ),
            SizedBox(height: 20),
            // Animated text
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    "Loading your activity data...",
                    style: TextStyle(
                      color: Colors.deepPurple.shade300,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      int hours = minutes ~/ 60;
      return '$hours hr';
    }
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.shade100,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: color.shade700,
            size: 30,
          ),
        ),
        SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.shade700,
          ),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActivitySection() {
    // Sample activity data - in a real app, this would come from a database
    final activities = [
      {
        'title': 'Doctor\'s Office',
        'action': 'Joined queue',
        'time': '2 days ago',
        'icon': Icons.medical_services,
        'color': Colors.teal,
      },
      {
        'title': 'Government Office',
        'action': 'Created queue',
        'time': '1 week ago',
        'icon': Icons.account_balance,
        'color': Colors.indigo,
      },
      {
        'title': 'Tech Support',
        'action': 'Completed',
        'time': '2 weeks ago',
        'icon': Icons.support_agent,
        'color': Colors.blue,
      },
    ];
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.deepPurple),
              SizedBox(width: 10),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...activities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }
  
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: (activity['color'] as MaterialColor).shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              activity['icon'] as IconData,
              color: (activity['color'] as MaterialColor).shade700,
              size: 25,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  activity['action'] as String,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity['time'] as String,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSignOutButton(AuthProvider auth, BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(Icons.logout, size: 22),
        label: Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Sign Out'),
              content: Text('Are you sure you want to sign out?'),
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
                  child: Text('Sign Out'),
                ),
              ],
            ),
          );
          
          if (confirmed == true) {
            await auth.signOut();
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      ),
    );
  }
}
