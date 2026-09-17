import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

/// Decorative previews of the real queue journey, never live account data.
class OnboardingArtwork extends StatelessWidget {
  const OnboardingArtwork({super.key, required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: 320,
      height: 300,
      child: switch (page) {
        0 => const _ReceptionStack(),
        1 => const _TicketUpdates(),
        _ => const _AlertOrbit(),
      },
    ),
  );
}

const _shadow = BoxShadow(
  color: Color(0x205B422A),
  blurRadius: 24,
  offset: Offset(0, 12),
);

class _ReceptionStack extends StatelessWidget {
  const _ReceptionStack();

  Widget _photo(String asset, double angle, Offset offset) =>
      Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 200,
            height: 218,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(17),
              boxShadow: const [_shadow],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      _photo(
        'assets/onboarding/reception-back.jpg',
        -.31,
        const Offset(-26, 19),
      ),
      _photo(
        'assets/onboarding/reception-middle.jpg',
        -.10,
        const Offset(-6, 0),
      ),
      _photo(
        'assets/onboarding/reception-front.jpg',
        .21,
        const Offset(25, -7),
      ),
      Positioned(
        right: 0,
        bottom: 27,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF282729),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.scanLine, size: 16, color: Color(0xFFFFFFFF)),
              SizedBox(width: 8),
              Text(
                'Scan to join',
                style: TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _TicketUpdates extends StatelessWidget {
  const _TicketUpdates();

  Widget _row(
    IconData icon,
    String title,
    String subtitle,
    String status, {
    bool active = false,
  }) {
    final content = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(active ? 0x185B422A : 0x0A5B422A),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8E7D8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF9D4600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: GetPrioTheme.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: GetPrioTheme.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF282729) : const Color(0xFFF2EEE8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                color: active ? const Color(0xFFFFFFFF) : GetPrioTheme.mutedInk,
              ),
            ),
          ),
        ],
      ),
    );
    return active
        ? content
        : Opacity(
            opacity: .63,
            child: Transform.scale(scale: .93, child: content),
          );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Transform.rotate(
      angle: -.05,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(
                LucideIcons.ticketCheck,
                'You’ve joined',
                'Your ticket is ready',
                'A–024',
              ),
              _row(
                LucideIcons.users,
                '3 people ahead',
                'You’re in the queue',
                'Waiting',
                active: true,
              ),
              _row(
                LucideIcons.refreshCw,
                'Stay up to date',
                'Check your latest status',
                'Your ticket',
              ),
            ],
          ),
          Positioned(
            right: 4,
            top: -23,
            child: Transform.rotate(
              angle: .17,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [_shadow],
                ),
                child: const Text(
                  'Your queue, at a glance',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AlertOrbit extends StatelessWidget {
  const _AlertOrbit();

  Widget _orb(IconData icon, double left, double top, {bool core = false}) =>
      Positioned(
        left: left,
        top: top,
        child: Container(
          width: core ? 94 : 58,
          height: core ? 94 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: core
                  ? const [Color(0xFFFFAD60), GetPrioTheme.primary]
                  : const [Color(0xFFFFFFFF), Color(0xFFEDE7E0)],
            ),
            boxShadow: const [_shadow],
          ),
          child: Icon(
            icon,
            size: core ? 35 : 24,
            color: core ? const Color(0xFF462206) : const Color(0xFF8A8176),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      for (final size in [185.0, 266.0])
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE4D8CC)),
          ),
        ),
      _orb(LucideIcons.bellRing, 113, 103, core: true),
      _orb(LucideIcons.ticket, 44, 31),
      _orb(LucideIcons.clock3, 250, 84),
      _orb(LucideIcons.mapPin, 16, 173),
      _orb(LucideIcons.smartphone, 208, 229),
      Positioned(
        left: 61,
        bottom: 26,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE8DFD6),
            border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
          ),
        ),
      ),
      Positioned(
        right: 5,
        top: 15,
        child: Transform.rotate(
          angle: .085,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [_shadow],
            ),
            child: const Text(
              'It’s your turn!',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
    ],
  );
}
