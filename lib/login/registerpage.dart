import 'package:app/component/components.dart';
import 'package:app/component/login_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app/component/singin.dart';

class Registerpage extends StatefulWidget {
  final Function()? OnTap;
  const Registerpage({super.key, required this.OnTap});

  @override
  State<Registerpage> createState() => _RegisterpageState();
}

class _RegisterpageState extends State<Registerpage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void signUserUp() async {
    showDialog(
      context: context,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
    try {
    
        if(passwordController.text == confirmPasswordController.text) {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
            
          );
        }else{
          showError('Passwords do not match');
        }
      Navigator.of(context, rootNavigator: true).pop(); // Close the loading dialog
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
                const SizedBox(height: 70),
                Components(
                  hintText: 'Email',
                  controller: emailController,
                  obscureText: false,
                ),


                //Password 
                const SizedBox(height: 5),
                Components(
                  hintText: 'Password',
                  controller: passwordController,
                  obscureText: true,
                ),

                    //Password 
                const SizedBox(height: 5),
                Components(
                  hintText: 'Confirm Password',
                  controller: confirmPasswordController,
                  obscureText: true,
                ),
                if(passwordController.text != confirmPasswordController.text)
                  const Text(
                    'Passwords do not match',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),


                const SizedBox(height: 20),
                Button(
                  text: 'Sign Up',
                  onTap: signUserUp,
                  
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
                const SizedBox(height: 90),
              
              
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                     onTap: widget.OnTap,
                      child: Text(
                        'Login Here',
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
