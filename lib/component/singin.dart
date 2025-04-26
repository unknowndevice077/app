import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String text;
  final Function()? onTap;
  const Button({
    super.key,
    required this.onTap,
    required this.text,
  });
  

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        margin: EdgeInsets.symmetric(
          horizontal: 30.0,
        ),//size
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(20),
        ),
        child:  Center(
        child: Text( 
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
        ),
      
        
        )
      ),
    );
  }
}
