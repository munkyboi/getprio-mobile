import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_theme.dart';

/// Wraps a loading layout with one accessible announcement for assistive
/// technology while keeping decorative placeholder blocks out of the tree.
class GetPrioSkeleton extends StatelessWidget {
  const GetPrioSkeleton({
    super.key,
    required this.child,
    this.label = 'Loading content',
  });

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// A neutral placeholder block used to preserve the shape of incoming data.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.color,
  });

  final double height;
  final double? width;
  final BorderRadiusGeometry borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? GetPrioTheme.paperAccent.withValues(alpha: 0.58),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, required this.width, this.height = 14});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonBlock(
      width: width,
      height: height,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
    );
  }
}

/// Mirrors the queue timeline shown once a ticket has loaded.
class TicketQueueProgressSkeleton extends StatelessWidget {
  const TicketQueueProgressSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonLine(width: 132, height: 18),
        SizedBox(height: 12),
        _TicketProgressStepSkeleton(isLast: false),
        _TicketProgressStepSkeleton(isLast: true),
      ],
    );
  }
}

class _TicketProgressStepSkeleton extends StatelessWidget {
  const _TicketProgressStepSkeleton({required this.isLast});

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Column(
            children: [
              const SkeletonBlock(
                width: 10,
                height: 10,
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
              if (!isLast)
                const SkeletonBlock(
                  width: 2,
                  height: 34,
                  borderRadius: BorderRadius.zero,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: isLast ? 112 : 124, height: 14),
                const SizedBox(height: 6),
                SkeletonLine(width: isLast ? 164 : 144, height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Reserves the same full-width footprint as a ticket action button.
class TicketActionButtonSkeleton extends StatelessWidget {
  const TicketActionButtonSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: const SkeletonBlock(
        height: 48,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    );
  }
}

class HomeActiveTicketSkeleton extends StatelessWidget {
  const HomeActiveTicketSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('home-active-ticket-skeleton'),
      child: GetPrioSkeleton(
        label: 'Loading active ticket',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLine(width: 124, height: 20),
            const SizedBox(height: 16),
            const SkeletonBlock(width: double.infinity, height: 22),
            const SizedBox(height: 10),
            const SkeletonLine(width: 184),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: SkeletonBlock(height: 52)),
                const SizedBox(width: 12),
                const Expanded(child: SkeletonBlock(height: 52)),
              ],
            ),
            const SizedBox(height: 20),
            const TicketQueueProgressSkeleton(
              key: Key('home-active-ticket-progress-skeleton'),
            ),
            const SizedBox(height: 20),
            const TicketActionButtonSkeleton(
              key: Key('home-active-ticket-action-skeleton'),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorDirectorySkeleton extends StatelessWidget {
  const VendorDirectorySkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GetPrioSkeleton(
      label: 'Loading vendors',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SkeletonBlock(width: 64, height: 32),
              const SizedBox(width: 8),
              const SkeletonBlock(width: 88, height: 32),
              const SizedBox(width: 8),
              const SkeletonBlock(width: 74, height: 32),
            ],
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < itemCount; index++) ...[
            const _VendorDirectoryCardSkeleton(),
            if (index < itemCount - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _VendorDirectoryCardSkeleton extends StatelessWidget {
  const _VendorDirectoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBlock(width: 64, height: 64),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 152, height: 18),
                SizedBox(height: 10),
                SkeletonLine(width: 96),
                SizedBox(height: 12),
                SkeletonLine(width: 128),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBlock(width: 18, height: 18),
        ],
      ),
    );
  }
}

class VendorDetailsSkeleton extends StatelessWidget {
  const VendorDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GetPrioSkeleton(
      label: 'Loading vendor details',
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonBlock(height: 144),
            const SizedBox(height: 20),
            const SkeletonLine(width: 210, height: 22),
            const SizedBox(height: 12),
            const SkeletonLine(width: 130),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: SkeletonBlock(height: 48)),
                const SizedBox(width: 12),
                const Expanded(child: SkeletonBlock(height: 48)),
              ],
            ),
            const SizedBox(height: 20),
            const SkeletonLine(width: 160, height: 18),
            const SizedBox(height: 12),
            const SkeletonBlock(height: 72),
          ],
        ),
      ),
    );
  }
}

class LiveQueueStatusSkeleton extends StatelessWidget {
  const LiveQueueStatusSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GetPrioSkeleton(
      label: 'Loading live queue status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLine(width: 136, height: 18),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: SkeletonBlock(height: 48)),
              const SizedBox(width: 12),
              const Expanded(child: SkeletonBlock(height: 48)),
            ],
          ),
        ],
      ),
    );
  }
}

class TicketsSkeleton extends StatelessWidget {
  const TicketsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GetPrioSkeleton(
      label: 'Loading tickets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 132, height: 20),
                SizedBox(height: 16),
                SkeletonLine(width: 180, height: 24),
                SizedBox(height: 10),
                SkeletonLine(width: 116),
                SizedBox(height: 16),
                TicketQueueProgressSkeleton(
                  key: Key('tickets-active-ticket-progress-skeleton'),
                ),
                SizedBox(height: 20),
                TicketActionButtonSkeleton(
                  key: Key('tickets-active-ticket-action-skeleton'),
                ),
              ],
            ),
          ),
          for (var index = 0; index < 3; index++) ...[
            _TicketHistorySkeleton(
              key: ValueKey('tickets-history-skeleton-$index'),
            ),
            if (index < 2) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TicketHistorySkeleton extends StatelessWidget {
  const _TicketHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(width: 160, height: 18),
          SizedBox(height: 14),
          SkeletonLine(width: 212),
          SizedBox(height: 10),
          SkeletonLine(width: 144),
        ],
      ),
    );
  }
}
