import 'package:flutter/material.dart';

class Components extends StatelessWidget {
  final String hintText; // Hint text for the TextField
  final TextEditingController controller; // Strongly typed controller
  final bool obscureText; // Whether to obscure the text

  const Components({
    super.key,
    required this.hintText,
    required this.controller,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20.0, // Added horizontal margin for spacing
      ), // Added margin for spacing
      padding: const EdgeInsets.all(
        8.0,
      ), // Added padding directly to the Container
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText, // Use the hintText parameter
          hintStyle: const TextStyle(color: Color.fromARGB(255, 133, 130, 130)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 128, 126, 126),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
