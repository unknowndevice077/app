import 'package:app/login/login_screen.dart';
import 'package:app/login/registerpage.dart';
import 'package:flutter/material.dart';

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  // Initially show login page
  bool showLoginPage = true;

  // Toggle between login and register page
  void togglePages() {
    print('🔄 Toggling pages. Current: ${showLoginPage ? "Login" : "Register"}, Switching to: ${showLoginPage ? "Register" : "Login"}'); // Debug
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('📱 Building LoginOrRegister. Showing: ${showLoginPage ? "Login" : "Register"}'); // Debug
    
    if (showLoginPage) {
      return LoginScreen(
        onTap: togglePages,
      );
    } else {
      return RegisterPage(
        onTap: togglePages,
      );
    }
  }
}
