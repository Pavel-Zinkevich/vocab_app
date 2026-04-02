import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: Center(
        child: Text(
          'Profile coming soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
