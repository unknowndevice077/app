import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _passwordsMatch => passwordController.text == confirmPasswordController.text;
  bool get _isPasswordStrong => passwordController.text.length >= 6;

  void signUserUp() async {
    if (!mounted) return;

    // Check internet connectivity first
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      setState(() {
        _errorMessage = 'No internet connection. Please check your network and try again.';
      });
      return;
    }

    // Validate inputs
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        confirmPasswordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (!_passwordsMatch) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (!_isPasswordStrong) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    // Email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Starting registration process...');
      print('📧 Email: ${emailController.text.trim()}');
      
      // Step 1: Create Firebase Auth user
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      print('✅ Firebase Auth user created successfully');
      print('👤 User ID: ${userCredential.user?.uid}');

      final user = userCredential.user;
      if (user != null) {
        print('🔄 Creating Firestore user document...');
        
        // Step 2: Create Firestore user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': user.uid,
          'displayName': user.email?.split('@')[0] ?? 'User',
          'profileSetup': false, // Add this for onboarding
        });

        print('✅ Firestore user document created successfully');

        // Step 3: Send email verification (optional)
        if (!user.emailVerified) {
          try {
            await user.sendEmailVerification();
            print('📧 Email verification sent');
          } catch (e) {
            print('⚠️ Could not send email verification: $e');
            // Don't fail registration if email verification fails
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Account created successfully! Welcome aboard!',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );

          print('🎉 Registration completed successfully!');
        }
      }

    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use a stronger password.';
          break;
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Try signing in instead.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email registration is not enabled. Please contact support.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please wait a moment and try again.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message ?? e.code}';
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } on FirebaseException catch (e) {
      print('❌ FirebaseException: ${e.code} - ${e.message}');
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Database error: ${e.message ?? 'Please try again'}';
        });
      }
    } catch (e) {
      print('❌ Unknown error: $e');
      
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _checkInternetConnection() async {
    // Implement your internet connection check logic here
    // For example, using the connectivity_plus package
    return true; // Return true if connected, false otherwise
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    final isVerySmallScreen = size.height < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 24.0 : 32.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height - MediaQuery.of(context).padding.top,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isVerySmallScreen ? 16 : 24),
                    
                    // ✅ Responsive Header
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: isVerySmallScreen ? 50 : 60,
                              height: isVerySmallScreen ? 50 : 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.school_outlined,
                                color: Colors.white,
                                size: isVerySmallScreen ? 24 : 28,
                              ),
                            ),
                            SizedBox(height: isVerySmallScreen ? 20 : 32),
                            Text(
                              'Create account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 28 : 32,
                                fontWeight: FontWeight.w300,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: isVerySmallScreen ? 4 : 8),
                            Text(
                              'Join us today',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 14 : 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isVerySmallScreen ? 24 : 32),
                    
                    // ✅ Responsive Form
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Error Message
                          if (_errorMessage != null)
                            Container(
                              padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                              margin: EdgeInsets.only(
                                bottom: isVerySmallScreen ? 16 : 24,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: isVerySmallScreen ? 13 : 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          
                          // Email Field
                          _MinimalTextField(
                            controller: emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            isCompact: isVerySmallScreen,
                          ),
                          
                          SizedBox(height: isVerySmallScreen ? 16 : 20),
                          
                          // Password Field
                          _MinimalTextField(
                            controller: passwordController,
                            label: 'Password (min 6 characters)',
                            obscureText: _obscurePassword,
                            isCompact: isVerySmallScreen,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          
                          // Password Strength Indicator
                          if (passwordController.text.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: isVerySmallScreen ? 6 : 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _isPasswordStrong ? Colors.green.shade600 : Colors.red.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _isPasswordStrong ? 'Strong password' : 'Weak password',
                                      style: TextStyle(
                                        fontSize: isVerySmallScreen ? 11 : 12,
                                        color: _isPasswordStrong ? Colors.green.shade600 : Colors.red.shade600,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          SizedBox(height: isVerySmallScreen ? 16 : 20),
                          
                          // Confirm Password Field
                          _MinimalTextField(
                            controller: confirmPasswordController,
                            label: 'Confirm password',
                            obscureText: _obscureConfirmPassword,
                            isCompact: isVerySmallScreen,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          
                          // Password Match Indicator
                          if (confirmPasswordController.text.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: isVerySmallScreen ? 6 : 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _passwordsMatch ? Colors.green.shade600 : Colors.red.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _passwordsMatch ? 'Passwords match' : 'Passwords do not match',
                                      style: TextStyle(
                                        fontSize: isVerySmallScreen ? 11 : 12,
                                        color: _passwordsMatch ? Colors.green.shade600 : Colors.red.shade600,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          SizedBox(height: isVerySmallScreen ? 24 : 32),
                          
                          // Create Account Button
                          _MinimalButton(
                            onPressed: _isLoading ? null : signUserUp,
                            isLoading: _isLoading,
                            text: 'Create Account',
                            isCompact: isVerySmallScreen,
                          ),
                          
                          SizedBox(height: isVerySmallScreen ? 16 : 24),
                          
                          // Terms Text
                          Text(
                            'By creating an account, you agree to our Terms of Service and Privacy Policy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 11 : 12,
                              color: Colors.grey.shade500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // ✅ Login Link
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: isVerySmallScreen ? 16 : 32,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: isVerySmallScreen ? 13 : 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: widget.onTap,
                                child: Text(
                                  'Sign in',
                                  style: TextStyle(
                                    color: Colors.grey.shade900,
                                    fontSize: isVerySmallScreen ? 13 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ Minimalist Text Field Component (same as login)
class _MinimalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool isCompact;

  const _MinimalTextField({
    required this.controller,
    required this.label,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(isCompact ? 12 : 16),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ Minimalist Button Component (same as login)
class _MinimalButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;
  final bool isCompact;

  const _MinimalButton({
    required this.onPressed,
    required this.isLoading,
    required this.text,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isCompact ? 48 : 56,
      decoration: BoxDecoration(
        color: onPressed != null ? Colors.grey.shade900 : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
