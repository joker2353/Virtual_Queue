import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.user != null) {
      // Redirect to HomePage if already signed in
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      });
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Virtual Queue - Login')),
      body: Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.login),
          label: Text('Sign in with Google'),
          onPressed: () async {
            await auth.signInWithGoogle();
          },
        ),
      ),
    );
  }
}
