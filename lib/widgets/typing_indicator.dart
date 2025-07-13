import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Lottie.asset(
          'assets/animations/loading.json',
          width: 60,
          height: 40,
        ),
      ),
    );
  }
}