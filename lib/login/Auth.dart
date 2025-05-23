import 'package:app/home%20page/home_page.dart';
import 'package:app/login/login_or_register.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Auth extends StatelessWidget {
  const Auth({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
         if(snapshot.hasData){
          return HomePage();
         }
         else{
          return LoginOrRegister();
         }
        },
      ),




    );
  }
}
