import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../directory/vendor_profile_hero.dart';
import '../queue/queue_models.dart';

class DetailPassAppBar extends StatelessWidget {
  const DetailPassAppBar({super.key, required this.title, this.backKey});
  final String title;
  final Key? backKey;
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: GetPrioTheme.paper,
    surfaceBlur: 0,
    surfaceOpacity: 0,
    child: SizedBox(
      height: 48,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(title).bold(),
          ),
          Positioned(
            left: 0,
            child: IconButton.ghost(
              key: backKey,
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class DetailPassCard extends StatelessWidget {
  const DetailPassCard({
    super.key,
    required this.vendor,
    required this.children,
  });
  final VendorSummary vendor;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: GetPrioTheme.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: GetPrioTheme.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x145B422A),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            key: const Key('detail-pass-hero'),
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VendorProfileCover(vendor: vendor, height: 250),
                VendorProfileLogo(vendor: vendor, size: 120),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}

class DetailPassField extends StatelessWidget {
  const DetailPassField({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).typography.small
              .copyWith(color: GetPrioTheme.mutedInk),
        ),
        const SizedBox(height: 4),
        Text(value).bold(),
      ],
    ),
  );
}

class DetailPassDivider extends StatelessWidget {
  const DetailPassDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: LayoutBuilder(
      builder: (_, constraints) => Row(
        children: [
          for (var i = 0; i < (constraints.maxWidth / 10).floor(); i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(height: 1, color: GetPrioTheme.line),
              ),
            ),
        ],
      ),
    ),
  );
}
