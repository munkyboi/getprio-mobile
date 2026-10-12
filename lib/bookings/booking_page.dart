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
    final request = ++_slotRequest;
    setState(() {
      _startAt = null;
      _slots = [];
      _loadingSlots = _services.isNotEmpty;
      _error = null;
    });
    if (_services.isEmpty) return;
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
      child: Scaffold(
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Text(
                      '${widget.vendor.name} · ${widget.location.name}',
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ServiceSelection(
                            services: widget.services,
                            selected: _selected,
                            enabled: !_busy,
                            onToggle: (service) {
                              setState(() {
                                if (!_selected.remove(service.slug)) {
                                  _selected.add(service.slug);
                                }
                              });
                              _loadSlots();
                            },
                          ),
                          for (final service in _services.where(
                            (service) => service.allowQuantity,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${service.name} · ${service.quantityLabel}',
                                    ),
                                  ),
                                  IconButton.outline(
                                    icon: const Icon(LucideIcons.minus),
                                    onPressed:
                                        _busy ||
                                            (_quantities[service.slug] ?? 1) <=
                                                1
                                        ? null
                                        : () {
                                            setState(
                                              () => _quantities[service.slug] =
                                                  (_quantities[service.slug] ??
                                                      1) -
                                                  1,
                                            );
                                            _loadSlots();
                                          },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '${_quantities[service.slug] ?? 1}',
                                    ),
                                  ),
                                  IconButton.outline(
                                    icon: const Icon(LucideIcons.plus),
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            setState(
                                              () => _quantities[service.slug] =
                                                  (_quantities[service.slug] ??
                                                      1) +
                                                  1,
                                            );
                                            _loadSlots();
                                          },
                                  ),
                                ],
                              ),
                            ),
                          if (_services.length > 1)
                            Row(
                              children: [
                                Expanded(
                                  child: Button(
                                    style: _mode == 'parallel'
                                        ? const ButtonStyle.primary()
                                        : const ButtonStyle.outline(),
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            setState(() => _mode = 'parallel');
                                            _loadSlots();
                                          },
                                    child: const Text('Together'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Button(
                                    style: _mode == 'sequential'
                                        ? const ButtonStyle.primary()
                                        : const ButtonStyle.outline(),
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            setState(
                                              () => _mode = 'sequential',
                                            );
                                            _loadSlots();
                                          },
                                    child: const Text('One after another'),
                                  ),
                                ),
                              ],
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
                                  _services.isEmpty
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
