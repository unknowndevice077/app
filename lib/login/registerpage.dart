import 'package:app/component/components.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app/component/singin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onTap;  // ✅ Add this parameter
  const RegisterPage({super.key, required this.onTap});  // ✅ Add required onTap

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // ✅ Add dispose method to prevent memory leaks
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void signUserUp() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false, // ✅ Prevent dismissing by tapping outside
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // ✅ Check password match BEFORE creating account
      if (passwordController.text != confirmPasswordController.text) {
        // Close loading dialog first
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        showError('Passwords do not match');
        return; // ✅ Exit early if passwords don't match
      }

      // Create user account
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      
      // Create user document in Firestore
      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': user.uid,
        }, SetOptions(merge: true));
      }

      // ✅ Close loading dialog on SUCCESS
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // ✅ Optional: Show success message or navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      // ✅ Close loading dialog on ERROR
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Handle specific Firebase Auth errors
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'The account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'Registration failed. Please try again.';
      }
      
      showError(errorMessage);
      
    } catch (e) {
      // ✅ Close loading dialog on ANY OTHER ERROR
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      showError('An unexpected error occurred. Please try again.');
    }
  }

  void showError(String message) {
    if (!mounted) return; // ✅ Check mounted before showing dialog
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the error dialog
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
                  SizedBox(height: screenHeight * 0.06),
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
                  Components(
                    hintText: 'Confirm Password',
                    controller: confirmPasswordController,
                    obscureText: true,
                  ),
                  if (passwordController.text != confirmPasswordController.text)
                    const Text(
                      'Passwords do not match',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  SizedBox(height: screenHeight * 0.03),
                  Button(
                    text: 'Sign Up',
                    onTap: signUserUp,
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
                  // Add your social login buttons here if needed
                  SizedBox(height: screenHeight * 0.12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: isSmall ? 13 : 15,
                          fontWeight: FontWeight.w400,
                          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: widget.onTap,  // ✅ Use the onTap parameter
                        child: Text(
                          'Login Here',
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
