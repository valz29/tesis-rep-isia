import 'package:flutter/material.dart';

class RetinazoLogo extends StatelessWidget {
  final double size;
  const RetinazoLogo({super.key, this.size = 250});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logo de Retinazo',
    image: true,
    child: Image.asset(
      'assets/branding/retinazo-eye.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}
