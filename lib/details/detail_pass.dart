import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../navigation/scroll_aware_app_bar.dart';
import '../directory/vendor_profile_hero.dart';
import '../queue/queue_models.dart';

class DetailPassAppBar extends StatelessWidget {
  const DetailPassAppBar({super.key, required this.title, this.backKey});
  final String title;
  final Key? backKey;
  @override
  Widget build(BuildContext context) => ScrollAwareAppBar(
    title: Text(title),
    leading: [
      GetPrioBackButton(
        key: backKey,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

class DetailPassCard extends StatelessWidget {
  const DetailPassCard({
    super.key,
    required this.vendor,
    required this.children,
    this.footer,
    this.ticketCutouts = false,
  });
  final VendorSummary vendor;
  final List<Widget> children;
  final Widget? footer;
  final bool ticketCutouts;
  @override
  Widget build(BuildContext context) => ticketCutouts
      ? _ticket(context)
      : Container(
          decoration: BoxDecoration(
            color: GetPrioTheme.colors(context).card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GetPrioTheme.colors(context).line),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  footer == null ? 20 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
              if (footer != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  child: footer!,
                ),
            ],
          ),
        );
  Widget _ticket(BuildContext context) {
    final colors = GetPrioTheme.colors(context);
    final groups = <List<Widget>>[[]];
    for (final child in children) {
      if (child is DetailPassDivider) {
        groups.add([]);
      } else {
        groups.last.add(child);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0)
            SizedBox(
              key: ValueKey('ticket-cutout-$i'),
              height: 40,
              child: CustomPaint(
                painter: TicketCutoutPainter(
                  fill: colors.card,
                  line: colors.line,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(
                left: BorderSide(color: colors.line),
                right: BorderSide(color: colors.line),
                top: i == 0 ? BorderSide(color: colors.line) : BorderSide.none,
                bottom: i == groups.length - 1
                    ? BorderSide(color: colors.line)
                    : BorderSide.none,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 24 : 0),
                bottom: Radius.circular(i == groups.length - 1 ? 24 : 0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (i == 0)
                  SizedBox(
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: groups[i],
                  ),
                ),
                if (i == groups.length - 1 && footer != null) footer!,
              ],
            ),
          ),
        ],
      ],
    );
  }
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
              .copyWith(color: GetPrioTheme.colors(context).mutedInk),
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
                child: Container(
                  height: 1,
                  color: GetPrioTheme.colors(context).line,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Transparent semicircular edge cut-outs meet the dashed perforation.
class TicketCutoutPainter extends CustomPainter {
  const TicketCutoutPainter({required this.fill, required this.line});
  final Color fill, line;
  Path outline(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()
      ..addOval(Rect.fromCircle(center: Offset(0, size.height / 2), radius: 10))
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height / 2),
          radius: 10,
        ),
      ),
  );
  @override
  void paint(Canvas canvas, Size size) {
    final path = outline(size);
    canvas.drawPath(path, Paint()..color = fill);
    final border = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Draw only side edges and cut-out arcs; body sections join without seams.
    for (final x in [0.0, size.width]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height / 2 - 10), border);
      canvas.drawLine(
        Offset(x, size.height / 2 + 10),
        Offset(x, size.height),
        border,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, size.height / 2), radius: 10),
        x == 0 ? -1.5707963 : 1.5707963,
        3.1415926,
        false,
        border,
      );
    }
    for (double x = 18; x < size.width - 18; x += 10) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + 6).clamp(0, size.width - 18), size.height / 2),
        border,
      );
    }
  }

  @override
  bool shouldRepaint(TicketCutoutPainter old) =>
      old.fill != fill || old.line != line;
}
