import 'dart:io';

import 'package:flutter/widgets.dart';

import 'thumbnail_image_provider.dart';

bool storedImageCanDisplay(String? path) =>
    path != null && path.isNotEmpty && File(path).existsSync();

class StoredImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const StoredImage({super.key, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Image(
      image: thumbnailImageProvider(
        FileImage(File(path)),
        constraints: constraints,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        fit: fit,
      ),
      fit: fit,
    ),
  );
}
