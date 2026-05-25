import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height:72,
          width: 72,
          child: Image.asset(
            "assets/images/logo.png",
            fit: BoxFit.cover
          )
        ),
        // SizedBox(width:8),
        Text(
          "WHISPA",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            
          ),
        )
      ],
      );
  }
}