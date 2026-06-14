import 'package:flutter/material.dart';

import 'call_mode.dart';

/// Compact selector for call mode. Drop in at the top of any screen
/// where call-time TTS playback matters.
class CallModeBar extends StatelessWidget {
  const CallModeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CallModeController.instance;
    return ValueListenableBuilder<CallMode>(
      valueListenable: controller.notifier,
      builder: (context, mode, _) {
        return Material(
          color: _bgColor(context, mode),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      mode == CallMode.off
                          ? Icons.phone_disabled
                          : Icons.phone_in_talk,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '통화 모드',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<CallMode>(
                  segments: CallMode.values
                      .map(
                        (m) => ButtonSegment(value: m, label: Text(m.label)),
                      )
                      .toList(),
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      controller.set(s.first),
                ),
                const SizedBox(height: 6),
                Text(
                  mode.hint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _bgColor(BuildContext context, CallMode mode) {
    final cs = Theme.of(context).colorScheme;
    return switch (mode) {
      CallMode.off => cs.surfaceContainerLow,
      CallMode.private => cs.tertiaryContainer,
      CallMode.public => cs.secondaryContainer,
    };
  }
}
