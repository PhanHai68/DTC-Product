import 'package:flutter/material.dart';

class ProjectProgress extends StatelessWidget {
  const ProjectProgress({
    super.key,
    required this.value,
    this.showLabel = true,
  });
  final double value;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tiến độ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${(normalized * 100).round()}%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
        ],
        LinearProgressIndicator(
          value: normalized,
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
        ),
      ],
    );
  }
}
