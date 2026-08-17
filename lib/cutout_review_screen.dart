import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'checkerboard.dart';
import 'touchup_screen.dart';

class CutoutReviewScreen extends StatelessWidget {
  final img.Image cutout;
  final void Function(img.Image finalCutout) onConfirmed;

  const CutoutReviewScreen({super.key, required this.cutout, required this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    final previewBytes = Uint8List.fromList(img.encodePng(cutout));
    return Scaffold(
      appBar: AppBar(title: const Text('Check the Cutout')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Does this look clean, or is some background still showing? Pinch to zoom, drag to pan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: Checkerboard(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 6,
                  child: Center(
                    child: Image.memory(previewBytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TouchUpScreen(
                            cutout: cutout,
                            onDone: onConfirmed,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.brush),
                    label: const Text('Fix It'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onConfirmed(cutout),
                    icon: const Icon(Icons.check),
                    label: const Text('Looks Good'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
