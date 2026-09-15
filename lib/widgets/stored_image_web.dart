import 'package:flutter/widgets.dart';

bool storedImageCanDisplay(String? path) =>
    path != null &&
    path.isNotEmpty &&
    (path.startsWith('data:image/') || path.startsWith('blob:'));

class StoredImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const StoredImage({super.key, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => Image.network(path, fit: fit);
}
