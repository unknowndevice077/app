import 'package:app/homepage/home_page.dart';
import 'package:app/login/login_or_register.dart'; // ✅ Import this instead
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Auth extends StatelessWidget {
  const Auth({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            // User is logged in
            return const HomePage();
          } else {
            // User is not logged in - show login/register page
            return const LoginOrRegister(); // ✅ Use this instead of LoginScreen
          }
        },
      ),
    );
  }
}
