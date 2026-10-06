import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

/// A content-sized carousel so ticket details remain readable at any text scale.
class ActiveTicketCarousel extends StatefulWidget {
  const ActiveTicketCarousel({super.key, required this.children});

  final List<Widget> children;

  @override
  State<ActiveTicketCarousel> createState() => _ActiveTicketCarouselState();
}

class _ActiveTicketCarouselState extends State<ActiveTicketCarousel> {
  final _controller = PageController();
  final Map<int, double> _heights = {};
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: _heights[_index] ?? 450,
          child: PageView.builder(
            key: const Key('home-active-ticket-carousel'),
            controller: _controller,
            itemCount: widget.children.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: _MeasureTicket(
                onSize: (size) {
                  if (mounted && _heights[index] != size.height) {
                    setState(() => _heights[index] = size.height);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: widget.children[index],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        children: List.generate(
          widget.children.length,
          (index) => Semantics(
            label: 'Active ticket ${index + 1} of ${widget.children.length}',
            selected: index == _index,
            button: true,
            child: GestureDetector(
              key: ValueKey('home-ticket-indicator-$index'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _controller.animateToPage(
                index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: index == _index ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index == _index
                          ? GetPrioTheme.primary
                          : GetPrioTheme.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _MeasureTicket extends SingleChildRenderObjectWidget {
  const _MeasureTicket({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _TicketSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _TicketSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _TicketSizeReporter extends RenderProxyBox {
  _TicketSizeReporter(this.onSize);
  ValueChanged<Size> onSize;
  Size? _previousSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_previousSize == size) return;
    _previousSize = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(measured));
  }
}
