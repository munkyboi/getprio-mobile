import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The tab shell supplies safe-area spacing; headings add no top margin.
class TabPageHeader extends StatelessWidget {
  const TabPageHeader({
    super.key,
    required this.title,
    required this.description,
  });
  final String title, description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
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
