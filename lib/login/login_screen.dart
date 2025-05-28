import 'package:app/component/components.dart';
import 'package:app/component/login_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app/component/singin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  final Function()? onTap;
  const LoginScreen({super.key, required this.onTap});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();


  void SignUserIn() async {
    showDialog(
      context: context,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    } on FirebaseAuthException {
      if (!mounted) return; // <-- Add this line
      Navigator.of(context).pop(); // Close the loading dialog
      showError ('The email or password is incorrect. Please try again.');
    }
  }

  
  void showError(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenWidth < 400;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 228, 225, 225),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth < 500 ? screenWidth * 0.95 : 400,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // TITLE
                  SizedBox(height: screenHeight * 0.06),
                  Text(
                    'STUDIA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: isSmall ? 24 : 30,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),

                  // EMAIL AND PASSWORD
                  SizedBox(height: screenHeight * 0.09),
                  Components(
                    hintText: 'Email',
                    controller: emailController,
                    obscureText: false,
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Components(
                    hintText: 'Password',
                    controller: passwordController,
                    obscureText: true,
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: isSmall ? 13 : 15,
                      fontWeight: FontWeight.w400,
                      color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Button(
                    onTap: SignUserIn,
                    text: 'Sign In',
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  Text(
                    'or continue with',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: isSmall ? 13 : 15,
                      fontWeight: FontWeight.w400,
                      color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Methods(imagePath: 'assets/images/Finn The Human.jpg'),
                      SizedBox(width: screenWidth * 0.05),
                      Methods(imagePath: 'assets/images/download.jpg'),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Want to join us?',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: isSmall ? 13 : 15,
                          fontWeight: FontWeight.w400,
                          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: widget.onTap,
                        child: Text(
                          'Register Here',
                          style: TextStyle(
                            fontSize: isSmall ? 13 : 15,
                            color: const Color.fromARGB(255, 1, 90, 255).withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
