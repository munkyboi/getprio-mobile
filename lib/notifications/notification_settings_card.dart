import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../account/account_settings_repository.dart';

class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key, required this.repository});
  final AccountSettingsRepository? repository;

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  NotificationSettings? _settings;
  bool _loading = true, _saving = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NotificationSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _settings = null;
      _error = null;
      _saving = false;
    });
    try {
      final repository = widget.repository;
      if (repository == null) throw StateError('Unavailable');
      final settings = await repository.loadNotificationSettings().timeout(
        const Duration(seconds: 20),
      );
      if (mounted && generation == _generation) {
        setState(() => _settings = settings);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Notification settings could not be loaded.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save(bool enabled) async {
    final repository = widget.repository;
    if (_saving || repository == null) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = await repository
          .updateNotificationSettings(queueAlerts: enabled)
          .timeout(const Duration(seconds: 20));
      if (mounted && generation == _generation) {
        setState(() => _settings = settings);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Could not save notification settings. Please try again.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('notification-settings-card'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Notification settings').h4(),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_settings != null)
          Row(
            children: [
              const Icon(LucideIcons.bell, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Queue alerts'),
                    SizedBox(height: 4),
                    Text('Receive notifications about your queue tickets.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                key: const Key('notification-queue-alerts'),
                value: _settings!.queueAlerts,
                onChanged: _saving ? null : _save,
              ),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!),
          if (_settings == null && widget.repository != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlineButton(
                onPressed: _load,
                child: const Text('Retry settings'),
              ),
            ),
        ],
      ],
    ),
  );
}
