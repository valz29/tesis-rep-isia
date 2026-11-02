import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageViewerScreen extends StatelessWidget {
  final Uint8List imagen;
  final String titulo;
  const ImageViewerScreen({
    super.key,
    required this.imagen,
    required this.titulo,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.memory(
          imagen,
          errorBuilder: (_, error, stack) =>
              const Text('No se pudo mostrar la imagen.'),
        ),
      ),
    ),
  );
}
