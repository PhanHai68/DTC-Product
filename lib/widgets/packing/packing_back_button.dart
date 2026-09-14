import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Nút quay lại có đường lui an toàn khi người dùng mở trực tiếp một URL web.
class PackingBackButton extends StatelessWidget {
  final String fallbackLocation;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final String tooltip;

  const PackingBackButton({
    super.key,
    this.fallbackLocation = '/packing_menu',
    this.foregroundColor,
    this.backgroundColor,
    this.tooltip = 'Quay lại',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
        ),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(fallbackLocation);
          }
        },
      ),
    );
  }
}
