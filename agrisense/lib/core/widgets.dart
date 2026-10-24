import 'package:flutter/material.dart';
import '../data/models.dart';
import 'theme.dart';

String dateLabel(DateTime time) =>
    '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.subtitle, {super.key, this.trailing});
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: muted)),
          ],
        );
        if (trailing == null) return titleBlock;
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 16), trailing!],
          );
        }
        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 24),
            trailing!,
          ],
        );
      },
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({required this.child, super.key, this.padding});
  final Widget child;
  final double? padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(
        padding ?? (MediaQuery.sizeOf(context).width < 600 ? 16 : 22),
      ),
      child: child,
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = accent});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.eco_outlined,
    this.action,
  });
  final String title, description;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(icon, size: 46, color: accent),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          ?action,
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class CropPicker extends StatelessWidget {
  const CropPicker({required this.value, required this.onChanged, super.key});
  final Crop value;
  final ValueChanged<Crop> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final crop in Crop.values)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: crop == Crop.values.last ? 0 : 8),
            child: Semantics(
              button: true,
              selected: value == crop,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  backgroundColor: value == crop
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  side: BorderSide(
                    color: value == crop
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                onPressed: () {
                  if (crop != value) onChanged(crop);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(width: 56, height: 32),
                        ExcludeSemantics(
                          child: Text(switch (crop) {
                            Crop.tomato => '🍅',
                            Crop.chili => '🌶️',
                            Crop.eggplant => '🍆',
                          }, style: const TextStyle(fontSize: 24)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(crop.label, maxLines: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: SafeArea(
          top: false,
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.copyWith(
                headlineLarge: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 28
                          : 36,
                    ),
                headlineMedium: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 24
                          : 28,
                    ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({required this.children, super.key, this.minWidth = 220});
  final List<Widget> children;
  final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          (constraints.maxWidth /
                  (minWidth *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5)))
              .floor()
              .clamp(1, children.length);
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
