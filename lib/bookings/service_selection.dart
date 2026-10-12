import '../navigation/app_drawer.dart';

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
    this.quantities = const {},
    this.onQuantityChanged,
  });
  final List<BookingService> services;
  final Set<String> selected;
  final ValueChanged<BookingService> onToggle;
  final bool enabled;
  final Map<String, int> quantities;
  final void Function(BookingService, int)? onQuantityChanged;
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
                  : GetPrioTheme.colors(context).card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected.contains(service.slug)
                    ? GetPrioTheme.primary
                    : GetPrioTheme.colors(context).line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                            style: const ButtonStyle.ghost(
                              density: ButtonDensity.compact,
                            ),
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
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Center(
                                    child: Icon(LucideIcons.image, size: 32),
                                  ),
                                ),
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
                          onPressed: () => openAppDrawer<void>(
                            context: context,
                            position: OverlayPosition.bottom,
                            expands: false,
                            builder: (sheetContext) => SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  GetPrioTheme.bottomSheetTopPadding,
                                  20,
                                  20,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AppDrawerTitle(service.name),
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
                if (service.allowQuantity && onQuantityChanged != null)
                  Padding(
                    padding: EdgeInsets.only(
                      top: 8,
                      left: service.imageUrl.isEmpty ? 0 : 64,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            service.quantityLabel.isEmpty
                                ? 'Units'
                                : '${service.quantityLabel[0].toUpperCase()}${service.quantityLabel.substring(1)}',
                            style: Theme.of(context).typography.small,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 150,
                          child: _ServiceUnitStepper(
                            key: ValueKey('service-units-${service.slug}'),
                            service: service,
                            quantity: quantities[service.slug] ?? 1,
                            enabled: enabled && selected.contains(service.slug),
                            onChanged: (quantity) =>
                                onQuantityChanged!(service, quantity),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _ServiceUnitStepper extends StatefulWidget {
  const _ServiceUnitStepper({
    super.key,
    required this.service,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });
  final BookingService service;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  State<_ServiceUnitStepper> createState() => _ServiceUnitStepperState();
}

class _ServiceUnitStepperState extends State<_ServiceUnitStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.quantity}',
  );

  @override
  void didUpdateWidget(covariant _ServiceUnitStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != '${widget.quantity}') {
      _controller.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: !widget.enabled,
    child: TextField(
      key: ValueKey('service-units-value-${widget.service.slug}'),
      controller: _controller,
      enabled: widget.enabled,
      readOnly: true,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w700),
      features: [
        InputFeature.decrementButton(
          min: 1,
          position: InputFeaturePosition.leading,
          icon: Icon(
            LucideIcons.minus,
            key: ValueKey('service-units-minus-${widget.service.slug}'),
            size: 14,
            semanticLabel: 'Decrease ${widget.service.name} units',
          ),
        ),
        InputFeature.incrementButton(
          min: 1,
          icon: Icon(
            LucideIcons.plus,
            key: ValueKey('service-units-plus-${widget.service.slug}'),
            size: 14,
            semanticLabel: 'Increase ${widget.service.name} units',
          ),
        ),
      ],
      onChanged: (text) {
        final quantity = int.tryParse(text);
        if (widget.enabled &&
            quantity != null &&
            quantity >= 1 &&
            quantity != widget.quantity) {
          widget.onChanged(quantity);
        }
      },
    ),
  );
}
