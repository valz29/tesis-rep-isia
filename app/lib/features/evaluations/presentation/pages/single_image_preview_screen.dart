import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

class SingleImagePreviewScreen extends StatelessWidget {
  final Uint8List imagen;
  final int numero;
  const SingleImagePreviewScreen({
    super.key,
    required this.imagen,
    required this.numero,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Vista previa · Imagen $numero de 3')),
    body: PageBody(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.memory(imagen, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '¿La imagen se ve correctamente?',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Volver a tomar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Usar imagen'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
