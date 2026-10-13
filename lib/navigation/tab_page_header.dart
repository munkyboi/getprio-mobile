import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'main_page_top_bar.dart';

/// The tab shell supplies safe-area spacing; headings add no top margin.
class TabPageHeader extends StatelessWidget {
  const TabPageHeader({
    super.key,
    required this.title,
    required this.description,
    this.page,
  });
  final String title, description;
  final String? page;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (MainPageTopBarScope.maybeOf(context) case final scope?) ...[
        MainPageTopBar(
          scope: scope,
          active: scope.activePage == null || scope.activePage == page,
        ),
        const SizedBox(height: 20),
      ],
      Container(
        key: const Key('main-page-title'),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).colorScheme.border),
          ),
        ),
        child: Text(title, style: Theme.of(context).typography.h2),
      ),
      const SizedBox(height: 4),
      Text(description),
      const SizedBox(height: 20),
    ],
  );
}
