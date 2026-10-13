import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../auth/auth_models.dart';
import '../auth/auth_repository.dart';
import '../form_validation.dart';
import '../navigation/app_drawer.dart';
import '../navigation/scroll_aware_app_bar.dart';
import 'booking_otp_drawer.dart';
import '../queue/queue_models.dart';
import 'booking_repository.dart';
import 'service_selection.dart';
import 'quantity_limits.dart';

/// A focused native booking flow. Prices and availability remain server-owned.
class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    required this.repository,
    required this.vendor,
    required this.location,
    required this.services,
    required this.selected,
    this.customer,
  });
  final BookingRepository repository;
  final VendorSummary vendor;
  final VendorLocation location;
  final List<BookingService> services;
  final Set<String> selected;
  final AuthUser? customer;
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with FormValidationMixin {
  late final TextEditingController _name, _email, _phone;
  final _notes = TextEditingController();
  late Set<String> _selected;
  final _quantities = <String, int>{};
  var _date = DateTime.now();
  var _mode = 'parallel';
  List<Map<String, dynamic>> _slots = [];
  String? _startAt, _error;
  bool _busy = false, _loadingSlots = false;
  int _slotRequest = 0;
  BuildContext? _drawerHostContext;

  int _serviceRevision = 0;

  BookingQuantityBounds? get _sharedBounds =>
      sharedQuantityBounds(_services, _mode);
  bool get _invalidLimits =>
      _services.any((service) => !quantityBounds(service).isValid);

  bool _reconcileQuantities() {
    final next = reconcileBookingQuantities(
      widget.services,
      _selected,
      _mode,
      _quantities,
    );
    final changed =
        next.length != _quantities.length ||
        next.entries.any((entry) => _quantities[entry.key] != entry.value);
    _quantities
      ..clear()
      ..addAll(next);
    return changed;
  }

  void _changeQuantity(BookingService service, int quantity) {
    if (_busy || !_selected.contains(service.slug)) return;
    final bounds = _sharedBounds ?? quantityBounds(service);
    if (!bounds.isValid) return;
    setState(() {
      final value = bounds.clamp(quantity);
      if (_sharedBounds != null) {
        for (final item in _services) {
          _quantities[item.slug] = value;
        }
      } else {
        _quantities[service.slug] = value;
      }
      _reconcileQuantities();
    });
    _loadSlots();
  }

  @override
  void didUpdateWidget(covariant BookingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services.length != widget.services.length ||
        widget.services.any(
          (service) => !oldWidget.services.any(
            (old) =>
                old.slug == service.slug &&
                old.allowQuantity == service.allowQuantity &&
                old.quantityMin == service.quantityMin &&
                old.quantityMax == service.quantityMax &&
                old.durationMinutes == service.durationMinutes &&
                old.priceAmountCents == service.priceAmountCents,
          ),
        )) {
      _serviceRevision++;
      _selected.removeWhere(
        (slug) => !widget.services.any((s) => s.slug == slug),
      );
      _reconcileQuantities();
      _loadSlots();
    }
  }

  void _changeMode(String mode) {
    if (_busy) return;
    setState(() {
      _mode = mode;
      _reconcileQuantities();
    });
    _loadSlots();
  }

  @override
  bool get formBusy => _busy;
  String get _base =>
      '/api/public/vendors/${Uri.encodeComponent(widget.vendor.slug)}';
  String get _dateKey =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
  List<BookingService> get _services => widget.services
      .where((service) => _selected.contains(service.slug))
      .toList();
  List<Map<String, dynamic>> get _items => _services
      .map(
        (service) => {
          'serviceSlug': service.slug,
          'bookingQuantity': _quantities[service.slug] ?? 1,
        },
      )
      .toList();
  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
    _name = TextEditingController(text: widget.customer?.customerName ?? '');
    _email = TextEditingController(text: widget.customer?.email ?? '');
    _phone = TextEditingController(text: widget.customer?.phone ?? '');
    _reconcileQuantities();
    _loadSlots();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSlots() async {
    _reconcileQuantities();
    final request = ++_slotRequest;
    setState(() {
      _startAt = null;
      _slots = [];
      _loadingSlots = _services.isNotEmpty && !_invalidLimits;
      _error = _invalidLimits
          ? 'These service unit limits do not fit a 24-hour visit. Please choose another service or contact the vendor.'
          : null;
    });
    if (_services.isEmpty || _invalidLimits) return;
    try {
      final response = _services.length > 1
          ? await widget.repository.api.post(
              '$_base/locations/${Uri.encodeComponent(widget.location.slug!)}/composed-slots',
              {'date': _dateKey, 'executionMode': _mode, 'items': _items},
            )
          : await widget.repository.api.get(
              '$_base/locations/${Uri.encodeComponent(widget.location.slug!)}/services/${Uri.encodeComponent(_services.single.slug)}/slots',
              query: {
                'date': _dateKey,
                'bookingQuantity': '${_quantities[_services.single.slug] ?? 1}',
              },
            );
      if (mounted && request == _slotRequest) {
        setState(
          () => _slots = (response['slots'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList(),
        );
      }
    } catch (e) {
      if (mounted && request == _slotRequest) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not load available times. Please try again.',
        );
      }
    } finally {
      if (mounted && request == _slotRequest) {
        setState(() => _loadingSlots = false);
      }
    }
  }

  Map<String, dynamic> _payload() => {
    'tenantSlug': widget.vendor.slug,
    'locationSlug': widget.location.slug,
    'serviceSlug': _services.first.slug,
    'scheduledStartAt': _startAt,
    'bookingQuantity': _quantities[_services.first.slug] ?? 1,
    'executionMode': _mode,
    'bundleItems': _items,
    'customerName': _name.text.trim(),
    'customerEmail': _email.text.trim(),
    'customerPhone': _phone.text.trim(),
    'notes': _notes.text.trim(),
  };
  Future<void> _submit() async {
    if (_busy || _startAt == null || _services.isEmpty) return;
    if (_reconcileQuantities() || _invalidLimits) {
      await _loadSlots();
      if (mounted && !_invalidLimits) {
        setState(
          () => _error =
              'Service limits changed. Please choose an available time again.',
        );
      }
      return;
    }
    if (!validateForm({
      _name: requiredField(_name.text, 'Name'),
      _email: emailField(_email.text),
    })) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = _payload();
      final revision = _serviceRevision;
      final response = await widget.repository.api.post('$_base/booking-otp', {
        ...payload,
        'channel': 'email',
      });
      if (!mounted) return;
      final booking = await openAppDrawer<CustomerBooking>(
        context: _drawerHostContext!,
        position: OverlayPosition.bottom,
        useSafeArea: false,
        draggable: false,
        barrierDismissible: false,
        builder: (_) => BookingOtpDrawer(
          repository: widget.repository,
          base: _base,
          challenge: response,
          payload: payload,
          isPayloadCurrent: () => mounted && revision == _serviceRevision,
        ),
      ).future;
      if (!mounted) return;
      if (booking != null) {
        Navigator.of(context).pop(booking);
      } else {
        await _loadSlots();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not start verification. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? type,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label).bold(),
      const SizedBox(height: 6),
      ValidatedField(
        validation: formValidation,
        controller: controller,
        child: KeyboardAwareInput(
          child: TextField(
            controller: controller,
            enabled: !_busy,
            keyboardType: type,
            scrollPadding: inputScrollPadding,
          ),
        ),
      ),
      const SizedBox(height: 14),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final total = _services.fold<int>(
      0,
      (sum, service) =>
          sum + service.priceAmountCents * (_quantities[service.slug] ?? 1),
    );
    return PopScope(
      canPop: !_busy,
      child: ScrollAwareScaffold(
        key: const Key('booking-form-page'),
        resizeToAvoidBottomInset: true,
        headers: [
          ScrollAwareAppBar(
            title: const Text('Plan your visit'),
            leading: [
              GetPrioBackButton(
                onPressed: () {
                  if (!_busy) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
        child: Builder(
          builder: (drawerContext) {
            _drawerHostContext = drawerContext;
            return SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ScrollAwareHeaderSpace(),
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Text(
                              '${widget.vendor.name} · ${widget.location.name}',
                            ),
                          ),
                          ServiceSelection(
                            services: widget.services,
                            selected: _selected,
                            enabled: !_busy,
                            quantities: _quantities,
                            onQuantityChanged: _changeQuantity,
                            bounds: {
                              for (final service in _services)
                                service.slug:
                                    _sharedBounds ?? quantityBounds(service),
                            },
                            onToggle: (service) {
                              setState(() {
                                if (!_selected.remove(service.slug)) {
                                  _selected.add(service.slug);
                                }
                                _reconcileQuantities();
                              });
                              _loadSlots();
                            },
                          ),
                          if (_services.length > 1)
                            Container(
                              key: const Key('booking-service-timing'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: GetPrioTheme.colors(context).paperAccent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: GetPrioTheme.colors(context).line,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'How would you like your services?',
                                  ).bold(),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Choose how your services are scheduled. This changes the available times and the length of your visit.',
                                  ),
                                  const SizedBox(height: 12),
                                  _BookingTimingOption(
                                    title: 'Together',
                                    description: 'Services start at the same time. Your visit follows the longest service.',
                                    icon: LucideIcons.layers,
                                    selected: _mode == 'parallel',
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            _changeMode('parallel');
                                          },
                                  ),
                                  const SizedBox(height: 10),
                                  _BookingTimingOption(
                                    title: 'One after another',
                                    description: 'Services happen one at a time, in the order listed above. Your visit includes the time for each service.',
                                    icon: LucideIcons.listOrdered,
                                    selected: _mode == 'sequential',
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            _changeMode('sequential');
                                          },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          const Text('Date').bold(),
                          const SizedBox(height: 8),
                          DatePicker(
                            value: _date,
                            stateBuilder: (date) {
                              final now = DateTime.now();
                              return date.isBefore(
                                    DateTime(now.year, now.month, now.day),
                                  )
                                  ? DateState.disabled
                                  : DateState.enabled;
                            },
                            enabled: !_busy,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _date = value);
                                _loadSlots();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text('Available times').bold(),
                          const SizedBox(height: 8),
                          if (_loadingSlots)
                            const Center(child: CircularProgressIndicator())
                          else if (_services.isNotEmpty && _slots.isEmpty)
                            const Text('No available times for this date.')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final slot in _slots)
                                  Button(
                                    style: _startAt == '${slot['startAt']}'
                                        ? const ButtonStyle.primary()
                                        : const ButtonStyle.outline(),
                                    onPressed:
                                        _busy || slot['isAvailable'] != true
                                        ? null
                                        : () => setState(
                                            () =>
                                                _startAt = '${slot['startAt']}',
                                          ),
                                    child: Text(_time('${slot['startAt']}')),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 20),
                          _field('Name', _name),
                          _field(
                            'Email',
                            _email,
                            type: TextInputType.emailAddress,
                          ),
                          _field('Phone', _phone, type: TextInputType.phone),
                          _field('Notes (optional)', _notes),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: GetPrioTheme.destructive,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: GetPrioTheme.colors(context).paper,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${_services.length} services · ₱${(total / 100).toStringAsFixed(2)}',
                        ).bold(),
                        const SizedBox(height: 6),
                        const Text(
                          'Your request is subject to vendor confirmation. Payment is reviewed manually.',
                        ),
                        const SizedBox(height: 12),
                        GetPrioActionButton.primary(
                          onPressed:
                              _busy ||
                                  _loadingSlots ||
                                  _startAt == null ||
                                  _services.isEmpty ||
                                  _invalidLimits
                              ? null
                              : _submit,
                          child: Text(
                            _busy
                                ? 'Please wait...'
                                : 'Verify email to continue',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _time(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    return date == null
        ? value
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Full-row choices keep scheduling guidance visible before choosing a time.
class _BookingTimingOption extends StatelessWidget {
  const _BookingTimingOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });
  final String title, description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = GetPrioTheme.colors(context);
    return Semantics(
      selected: selected,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? GetPrioTheme.primary.withValues(alpha: .12)
              : colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? GetPrioTheme.primary : colors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Button.ghost(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? GetPrioTheme.primary : colors.mutedInk,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: colors.mutedInk,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 20,
                  color: selected ? GetPrioTheme.primary : colors.mutedInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
