import 'package:app/login/registerpage.dart';
import 'package:flutter/material.dart';
import 'package:app/login/login_screen.dart';

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  bool showLoginScreen = true;

void togglePages() {
    setState(() {
      showLoginScreen = !showLoginScreen;
    });
  }


  @override
  Widget build(BuildContext context) {
    if(showLoginScreen) {
      return LoginScreen(
        onTap: togglePages,
      );
    } else {
      return Registerpage(
        OnTap: togglePages,
      );

    }
  }
}
