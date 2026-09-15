import 'package:flutter/widgets.dart';

bool storedImageCanDisplay(String? path) => false;

class StoredImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const StoredImage({super.key, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
