import 'package:flutter/material.dart';

import '../models/project.dart';
import 'project_progress.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.onTap});
  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.projectName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (project.machines.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Model: ${project.machines.first.model}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(status: project.status),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Meta(
                    icon: Icons.location_on_outlined,
                    text: project.location,
                  ),
                  _Meta(
                    icon: Icons.calendar_today_outlined,
                    text: _date(project.startDate),
                  ),
                  _Meta(
                    icon: Icons.precision_manufacturing_outlined,
                    text: '${project.machineCount} máy',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProjectProgress(value: project.progress),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProjectStatus.completed => Colors.green,
      ProjectStatus.paused => Colors.orange,
      ProjectStatus.waitingAcceptance => Colors.deepOrange,
      ProjectStatus.active => Theme.of(context).colorScheme.primary,
      ProjectStatus.preparing => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
