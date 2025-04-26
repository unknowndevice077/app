import 'package:flutter/material.dart';


class Methods extends StatelessWidget {
  final String imagePath;
  const Methods({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color.fromARGB(255, 197, 194, 194),
      ),
      child: Image.asset(
        imagePath,
        height: 60,
        width: 60,
      ),

    );
  }
}
