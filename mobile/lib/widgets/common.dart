import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mazdek_ai/core/theme/app_theme.dart';

final _tryFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
String money(double value) => _tryFormatter.format(value);

class StatusBanner extends StatelessWidget {
  const StatusBanner({required this.text, this.icon = Icons.info_outline, this.warning = false, super.key});
  final String text;
  final IconData icon;
  final bool warning;
  @override Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: warning ? Colors.amber.withValues(alpha: .16) : AppTheme.orange.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [Icon(icon, size: 18, color: warning ? Colors.amber.shade800 : AppTheme.orange), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)))]),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, required this.message, this.icon = Icons.inbox_outlined, super.key});
  final String title, message;
  final IconData icon;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline))])));
}

class LoadingPane extends StatelessWidget {
  const LoadingPane({super.key});
  @override Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 44), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene'))])));
}
