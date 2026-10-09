import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../auth/auth_models.dart';
import '../auth/auth_repository.dart';
import '../form_validation.dart';
import '../otp_input.dart';
import '../queue/queue_models.dart';
import 'booking_repository.dart';
import 'service_selection.dart';

/// A focused native booking flow. Prices and availability remain server-owned.
class BookingSheet extends StatefulWidget {
  const BookingSheet({
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
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> with FormValidationMixin {
  late final TextEditingController _name, _email, _phone;
  final _notes = TextEditingController(), _code = TextEditingController();
  late Set<String> _selected;
  final _quantities = <String, int>{};
  var _date = DateTime.now();
  var _mode = 'parallel';
  List<Map<String, dynamic>> _slots = [];
  String? _startAt, _error;
  bool _busy = false, _loadingSlots = false;
  int _slotRequest = 0;
  Map<String, dynamic>? _otp;
  String? _verificationToken;
  Timer? _timer;
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
  int get _resendSeconds =>
      (DateTime.tryParse('${_otp?['resendAvailableAt']}')
              ?.difference(DateTime.now())
              .inSeconds ??
          -1) +
      1;
  bool get _expired =>
      DateTime.tryParse('${_otp?['expiresAt']}')?.isBefore(DateTime.now()) ??
      false;
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
    _timer?.cancel();
    for (final c in [_name, _email, _phone, _notes, _code]) {
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
    if (_busy || _startAt == null || _services.isEmpty || _expired) return;
    if (!validateForm({
      _name: requiredField(_name.text, 'Name'),
      _email: emailField(_email.text),
      if (_otp != null) _code: codeField(_code.text),
    })) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_otp == null) {
        final response = await widget.repository.api.post(
          '$_base/booking-otp',
          {..._payload(), 'channel': 'email'},
        );
        if (!mounted) return;
        setState(() => _otp = response);
        _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
        return;
      }
      final verified = _verificationToken != null
          ? null
          : await widget.repository.api.post('$_base/booking-otp/verify', {
              'otpId': _otp!['otpId'],
              'code': _code.text,
            });
      _verificationToken ??= verified?['bookingVerificationToken'] as String?;
      if (_verificationToken == null) {
        throw StateError('Verification did not return a booking token');
      }
      final response = await widget.repository.api.post(
        '/api/account/bookings',
        {..._payload(), 'bookingVerificationToken': _verificationToken},
      );
      if (mounted) {
        closeDrawer(
          context,
          CustomerBooking(response['booking'] as Map<String, dynamic>),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.statusCode == 409) {
          setState(() {
            _otp = null;
            _verificationToken = null;
            _code.clear();
          });
          await _loadSlots();
        }
        if (mounted) {
          setState(
            () => _error = e is ApiException
                ? e.message
                : 'Could not submit your booking. Please try again.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _otp == null || _resendSeconds > 0) return;
    setState(() => _busy = true);
    try {
      final response = await widget.repository.api.post(
        '$_base/booking-otp/${Uri.encodeComponent('${_otp!['otpId']}')}/resend',
        {},
      );
      if (mounted) {
        setState(() {
          _otp = response;
          _verificationToken = null;
          _code.clear();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not resend the code.',
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
            enabled: !_busy && _otp == null,
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
      canPop: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height:
                (MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom -
                        MediaQuery.paddingOf(context).vertical)
                    .clamp(0.0, MediaQuery.sizeOf(context).height * .88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan your visit',
                              style: Theme.of(context).typography.h2,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.vendor.name} · ${widget.location.name}',
                            ),
                          ],
                        ),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x),
                        onPressed: _busy
                            ? null
                            : () async {
                                final discard = await showGeneralDialog<bool>(
                                  context: context,
                                  pageBuilder: (dialogContext, _, _) => Center(
                                    child: AlertDialog(
                                      title: const Text(
                                        'Discard booking draft?',
                                      ),
                                      content: const Text(
                                        'Your selected schedule and entered details will be discarded.',
                                      ),
                                      actions: [
                                        OutlineButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                          child: const Text('Keep editing'),
                                        ),
                                        DestructiveButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(true),
                                          child: const Text('Discard'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (discard == true && context.mounted) {
                                  closeDrawer(context);
                                }
                              },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      20 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ServiceSelection(
                          services: widget.services,
                          selected: _selected,
                          enabled: !_busy && _otp == null,
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
                                          _otp != null ||
                                          (_quantities[service.slug] ?? 1) <= 1
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
                                  onPressed: _busy || _otp != null
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
                                  onPressed: _busy || _otp != null
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
                                  onPressed: _busy || _otp != null
                                      ? null
                                      : () {
                                          setState(() => _mode = 'sequential');
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
                          enabled: !_busy && _otp == null,
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
                                      _busy ||
                                          _otp != null ||
                                          slot['isAvailable'] != true
                                      ? null
                                      : () => setState(
                                          () => _startAt = '${slot['startAt']}',
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
                        if (_otp != null) ...[
                          OutlineButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _otp = null;
                                    _verificationToken = null;
                                    _code.clear();
                                    _timer?.cancel();
                                    _timer = null;
                                    _error = null;
                                  }),
                            child: const Text('Edit booking details'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Enter the code sent to ${_otp!['deliveryTarget'] ?? _email.text}.',
                          ),
                          const SizedBox(height: 12),
                          GetPrioOtpInput(
                            controller: _code,
                            enabled: !_busy && !_expired,
                            validation: formValidation,
                          ),
                          if (_expired)
                            const Text(
                              'This code has expired. Request a new code.',
                            ),
                          const SizedBox(height: 8),
                          OutlineButton(
                            onPressed: _busy || _resendSeconds > 0
                                ? null
                                : _resend,
                            child: Text(
                              _resendSeconds > 0
                                  ? 'Resend in ${_resendSeconds}s'
                                  : 'Resend code',
                            ),
                          ),
                        ],
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
                                _expired
                            ? null
                            : _submit,
                        child: Text(
                          _busy
                              ? 'Please wait...'
                              : _otp == null
                              ? 'Verify email to continue'
                              : 'Submit request and continue',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
