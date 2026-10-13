import 'package:shadcn_flutter/shadcn_flutter.dart';

const listPagePadding = EdgeInsets.fromLTRB(20, 10, 20, 20);

/// Shared two-column tab styling for customer ticket and booking lists.
class ListFilterTabs extends StatelessWidget {
  const ListFilterTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Tabs(
    index: index,
    onChanged: onChanged,
    expand: true,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    children: [
      for (var i = 0; i < labels.length; i++)
        TabItem(
          child: Semantics(
            selected: index == i,
            button: true,
            child: Text(labels[i]),
          ),
        ),
    ],
  );
}
