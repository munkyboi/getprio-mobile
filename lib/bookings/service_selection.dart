import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../navigation/swipe_back_page_route.dart';
import 'booking_repository.dart';
import 'image_viewer.dart';

class ServiceSelection extends StatelessWidget {
  const ServiceSelection({
    super.key,
    required this.services,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });
  final List<BookingService> services;
  final Set<String> selected;
  final ValueChanged<BookingService> onToggle;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final service in services)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            key: ValueKey('service-row-${service.slug}'),
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            decoration: BoxDecoration(
              color: selected.contains(service.slug)
                  ? GetPrioTheme.primary.withValues(alpha: .08)
                  : GetPrioTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected.contains(service.slug)
                    ? GetPrioTheme.primary
                    : GetPrioTheme.line,
              ),
            ),
            child: Row(
              children: [
                if (service.imageUrl.isNotEmpty) ...[
                  Semantics(
                    label: 'View image of ${service.name}',
                    button: true,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Button(
                        key: ValueKey('service-thumbnail-${service.slug}'),
                        style: const ButtonStyle.ghost(),
                        onPressed: () => Navigator.of(context).push(
                          SwipeBackPageRoute<void>(
                            builder: (_) => BookingImageViewer(
                              imageUrl: service.imageUrl,
                              title: service.name,
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            service.imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(LucideIcons.image, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name).bold(),
                      const SizedBox(height: 4),
                      Text(
                        '${service.priceDisplay} · ${service.durationMinutes} min',
                        style: Theme.of(context).typography.small,
                      ),
                    ],
                  ),
                ),
                if (service.description.trim().isNotEmpty)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton.ghost(
                      key: ValueKey('service-info-${service.slug}'),
                      icon: const Icon(LucideIcons.info, size: 18),
                      onPressed: () => openDrawerOverlay<void>(
                        context: context,
                        position: OverlayPosition.bottom,
                        expands: false,
                        builder: (sheetContext) => SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(service.name).h3()),
                                    IconButton.ghost(
                                      icon: const Icon(LucideIcons.x),
                                      onPressed: () =>
                                          closeDrawer(sheetContext),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Text(service.description),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Semantics(
                  label:
                      '${selected.contains(service.slug) ? 'Remove' : 'Add'} ${service.name}',
                  selected: selected.contains(service.slug),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton.ghost(
                      key: ValueKey('service-toggle-${service.slug}'),
                      icon: Icon(
                        selected.contains(service.slug)
                            ? LucideIcons.check
                            : LucideIcons.plus,
                        size: 20,
                        color: GetPrioTheme.primary,
                      ),
                      onPressed: enabled ? () => onToggle(service) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
