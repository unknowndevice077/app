import 'package:app/component/components.dart';
import 'package:app/component/login_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app/component/singin.dart';
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
    Navigator.of(context, rootNavigator: true).pop();
    } on FirebaseAuthException {
      Navigator.of(context, rootNavigator: true).pop(); // Close the loading dialog
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 228, 225, 225),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //TITLE
                const SizedBox(height: 50),
                const Text(
                  'STUDIA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ),

                //EMAIL AND PASSWORD
                const SizedBox(height: 70),
                Components(
                  hintText: 'Email',
                  controller: emailController,
                  obscureText: false,
                ),
                const SizedBox(height: 20),
                Components(
                  hintText: 'Password',
                  controller: passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),
                Button(
                  onTap: SignUserIn,
                  text: 'Sign In',
                ),
                const SizedBox(height: 50),
                Text(
                  'or continue with',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Methods(imagePath: 'lib/images/Finn The Human.jpg'),
                    const SizedBox(width: 20),
                    Methods(imagePath: 'lib/images/download.jpg'),
                  ],
                ),
                const SizedBox(height: 120),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Want to join us?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
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
                          fontSize: 15,
                          color: const Color.fromARGB(255, 1, 90, 255).withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
