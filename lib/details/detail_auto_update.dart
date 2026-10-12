import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Pausing is latched: only a successful manual refresh resumes updates.
class DetailAutoUpdate extends ChangeNotifier {
  DetailAutoUpdate() {
    touch();
  }
  Timer? _idle;
  bool paused = false;
  void touch() {
    if (paused) return;
    _idle?.cancel();
    _idle = Timer(const Duration(minutes: 5), () {
      paused = true;
      notifyListeners();
    });
  }

  void resume() {
    paused = false;
    touch();
    notifyListeners();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }
}

class DetailActivityBoundary extends StatelessWidget {
  const DetailActivityBoundary({
    super.key,
    required this.activity,
    required this.child,
  });
  final DetailAutoUpdate activity;
  final Widget child;
  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => activity.touch(),
    onPointerMove: (_) => activity.touch(),
    onPointerSignal: (_) => activity.touch(),
    child: child,
  );
}

class DetailAutoUpdateNotice extends StatelessWidget {
  const DetailAutoUpdateNotice({super.key, required this.onRefresh});
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('detail-auto-update-paused'),
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.muted,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Auto updates paused after 5 minutes of inactivity. Refresh to resume updates.',
        ),
        const SizedBox(height: 8),
        OutlineButton(
          onPressed: onRefresh,
          child: const Text('Refresh and resume'),
        ),
      ],
    ),
  );
}
