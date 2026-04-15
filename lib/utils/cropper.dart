import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';

class CropPage extends StatefulWidget {
  final File imageFile;

  const CropPage({super.key, required this.imageFile});

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  final controller = CropController(
    aspectRatio: 1.0, // you can change or remove this if you want free crop
  );

  Future<void> _saveCrop() async {
    final cropped = await controller.croppedBitmap();

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final rect = Rect.fromLTWH(
      0,
      0,
      cropped.width.toDouble(),
      cropped.height.toDouble(),
    );

    // ✅ No circular clipping anymore
    canvas.drawImageRect(
      cropped,
      rect,
      rect,
      Paint(),
    );

    final finalImage = await recorder.endRecording().toImage(
          cropped.width,
          cropped.height,
        );

    final bytes = await finalImage.toByteData(format: ImageByteFormat.png);

    if (bytes == null) return;

    final file = File(
      '${widget.imageFile.parent.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(bytes.buffer.asUint8List());

    if (mounted) {
      Navigator.pop(context, file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crop Photo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCrop,
          ),
        ],
      ),

      // ✅ Removed ClipOval (no circular UI anymore)
      body: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: CropImage(
            controller: controller,
            image: Image.file(widget.imageFile),
            alwaysShowThirdLines: true,
          ),
        ),
      ),
    );
  }
}
