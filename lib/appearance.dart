import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_theme.dart';

abstract interface class AppearanceStore {
  Future<String?> read();
  Future<void> write(String mode);
}

class SecureAppearanceStore implements AppearanceStore {
  const SecureAppearanceStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'getprio.appearance';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String mode) => _storage.write(key: _key, value: mode);
}

class AppearanceController extends ChangeNotifier {
  AppearanceController({this.store = const SecureAppearanceStore()});
  final AppearanceStore store;
  ThemeMode mode = ThemeMode.system;
  bool saving = false;
  String? error;
  bool _disposed = false;
  int _revision = 0;

  Future<void> load() async {
    final revision = _revision;
    try {
      final saved = await store.read();
      if (_disposed || revision != _revision) return;
      mode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } catch (_) {
      // An unavailable/invalid preference falls back to the device setting.
    }
  }

  Future<void> select(ThemeMode next) async {
    if (saving) return;
    _revision++;
    saving = true;
    error = null;
    notifyListeners();
    try {
      await store.write(next.name);
      if (!_disposed) mode = next;
    } catch (_) {
      if (!_disposed) error = 'Could not save appearance. Please try again.';
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}

/// Rebuilds the app theme without recreating its API/session repositories.
class AppearanceHost extends StatefulWidget {
  const AppearanceHost({super.key, this.controller, required this.builder});
  final AppearanceController? controller;
  final Widget Function(ThemeMode mode) builder;
  @override
  State<AppearanceHost> createState() => _AppearanceHostState();
}

class _AppearanceHostState extends State<AppearanceHost> {
  late final controller = widget.controller ?? AppearanceController();
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (_, _) => widget.builder(controller.mode),
    ),
  );
}

Future<void> showAppearanceSheet(BuildContext context) async {
  final controller = AppearanceScope.maybeOf(context);
  if (controller == null) return;
  await openDrawerOverlay<void>(
    context: context,
    position: OverlayPosition.bottom,
    expands: false,
    transformBackdrop: true,
    builder: (_) => AppearanceSheet(controller: controller),
  ).future;
}

class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key, required this.controller});
  final AppearanceController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => SafeArea(
      top: false,
      child: Padding(
        key: const Key('appearance-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Appearance',
                    style: Theme.of(context).typography.h3,
                  ),
                ),
                IconButton.ghost(
                  key: const Key('appearance-close'),
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => closeSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Choose how GetPrio looks on this device.'),
            const SizedBox(height: 24),
            Row(
              children: [
                for (final mode in [
                  ThemeMode.light,
                  ThemeMode.dark,
                  ThemeMode.system,
                ])
                  Expanded(
                    child: Semantics(
                      selected: controller.mode == mode,
                      button: true,
                      label: '${_label(mode)} appearance',
                      child: GhostButton(
                        key: ValueKey('appearance-${mode.name}'),
                        density: ButtonDensity.compact,
                        onPressed: controller.saving
                            ? null
                            : () => controller.select(mode),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PhonePreview(
                              mode: mode,
                              selected: controller.mode == mode,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: controller.mode == mode
                                    ? GetPrioTheme.primary
                                    : GetPrioTheme.colors(context).paperAccent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _label(mode),
                                style: TextStyle(
                                  color: controller.mode == mode
                                      ? GetPrioTheme.onPrimary
                                      : GetPrioTheme.colors(context).ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              controller.mode == ThemeMode.system
                  ? 'System follows your device’s Light or Dark setting.'
                  : '${_label(controller.mode)} mode stays on regardless of your device setting.',
            ),
            if (controller.saving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Saving appearance…'),
              ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(controller.error!),
              ),
          ],
        ),
      ),
    ),
  );
  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.mode, required this.selected});
  final ThemeMode mode;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    width: 66,
    height: 100,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      border: Border.all(
        color: selected
            ? GetPrioTheme.primary
            : GetPrioTheme.colors(context).line,
        width: selected ? 2 : 1,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Row(
            children: [
              if (mode != ThemeMode.dark)
                Expanded(
                  child: ColoredBox(
                    color: GetPrioTheme.paper,
                    child: _mockContent(false),
                  ),
                ),
              if (mode != ThemeMode.light)
                Expanded(
                  child: ColoredBox(
                    color: const Color(0xFF181613),
                    child: _mockContent(true),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 24,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF82796F),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _mockContent(bool dark) => Padding(
    padding: const EdgeInsets.fromLTRB(5, 18, 5, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: i == 0 ? 9 : 13,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF51473D) : const Color(0xFFDFD6CC),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 5),
        ],
      ],
    ),
  );
}
