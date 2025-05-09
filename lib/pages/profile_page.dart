import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Profile')),
        body: Center(child: Text('Not signed in.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Center(
            child: CircleAvatar(
              radius: 56,
              backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child:
                  user.photoURL == null ? Icon(Icons.person, size: 56) : null,
            ),
          ),
          SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Divider(height: 24),
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.deepPurple),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.displayName ?? '',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.deepPurple),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.email ?? '',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(Icons.logout),
            label: Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () async {
              await auth.signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
