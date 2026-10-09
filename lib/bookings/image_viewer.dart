import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../navigation/scroll_aware_app_bar.dart';

class BookingImageViewer extends StatelessWidget {
  const BookingImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });
  final String imageUrl, title;
  @override
  Widget build(BuildContext context) => Scaffold(
    headers: [
      ScrollAwareAppBar(
        title: Text(title),
        leading: [
          IconButton.ghost(
            key: const Key('booking-image-close'),
            icon: const Icon(LucideIcons.x),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ],
    child: SafeArea(
      top: false,
      child: Center(
        child: InteractiveViewer(
          key: const Key('booking-image-viewer'),
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            semanticLabel: title,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load image. Close the viewer and tap the image to try again.',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
