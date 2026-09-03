/// Banners de estado para los flujos de autenticación.
import 'package:flutter/material.dart';

/// Banner «Tu sesión ha expirado» (RF-01.6) y variantes informativas.
class FlowBanner extends StatelessWidget {
  const FlowBanner({
    super.key,
    required this.message,
    this.kind = FlowBannerKind.info,
    this.onDismiss,
  });

  final String message;
  final FlowBannerKind kind;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      FlowBannerKind.warning => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
          Icons.warning_amber_rounded,
        ),
      FlowBannerKind.success => (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
          Icons.check_circle_outline_rounded,
        ),
      FlowBannerKind.info => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface,
          Icons.info_outline_rounded,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: fg,
              icon: const Icon(Icons.close_rounded),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

enum FlowBannerKind { info, warning, success }
