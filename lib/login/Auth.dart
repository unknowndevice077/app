import 'package:app/homepage/home_page.dart';
import 'package:app/login/login_or_register.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/profile_picture_provider.dart';

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  @override
  void initState() {
    super.initState();
    // ✅ Load profile picture when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProfilePictureProvider>(context, listen: false)
          .loadProfilePicture();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Check if user is logged in
          if (snapshot.hasData && snapshot.data != null) {
            print('✅ [Auth] User logged in: ${snapshot.data!.email}');
            return const HomePage();
          } else {
            print('❌ [Auth] No user logged in');
            return const LoginOrRegister();
          }
        },
      ),
    );
  }

}
