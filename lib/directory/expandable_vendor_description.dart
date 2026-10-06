import 'package:shadcn_flutter/shadcn_flutter.dart';

class ExpandableVendorDescription extends StatefulWidget {
  const ExpandableVendorDescription({super.key, required this.description});

  final String description;

  @override
  State<ExpandableVendorDescription> createState() =>
      _ExpandableVendorDescriptionState();
}

class _ExpandableVendorDescriptionState
    extends State<ExpandableVendorDescription> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ExpandableVendorDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description != widget.description) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = DefaultTextStyle.of(context).style;
        final painter = TextPainter(
          text: TextSpan(text: widget.description, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.description,
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (canExpand) ...[
              const SizedBox(height: 8),
              GhostButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                density: ButtonDensity.compact,
                child: Text(_expanded ? 'Show less' : 'Read more'),
              ),
            ],
          ],
        );
      },
    );
  }
}
