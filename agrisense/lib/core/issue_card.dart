import 'package:flutter/material.dart';
import 'app_issue.dart';
import 'widgets.dart';
import '../features/help/help_screen.dart';

class IssueCard extends StatelessWidget {
  const IssueCard({
    super.key,
    required this.issue,
    this.onRetry,
    this.onSettings,
    this.retryLabel = 'Retry',
  });
  final AppIssue issue;
  final VoidCallback? onRetry, onSettings;
  final String retryLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(issue.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(issue.recovery),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (onRetry != null)
                OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
              if (onSettings != null)
                TextButton(
                  onPressed: onSettings,
                  child: const Text('Open device settings'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HelpScreen(issue: issue),
                  ),
                ),
                child: const Text('Get help'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
