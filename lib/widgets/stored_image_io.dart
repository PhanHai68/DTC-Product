import 'dart:io';

import 'package:flutter/widgets.dart';

bool storedImageCanDisplay(String? path) =>
    path != null && path.isNotEmpty && File(path).existsSync();

class StoredImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const StoredImage({super.key, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => Image.file(File(path), fit: fit);
}
