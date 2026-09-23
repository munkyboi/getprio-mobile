import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../feedback_toast.dart';
import '../keyboard_avoidance.dart';
import '../queue/queue_models.dart';
import 'vendor_social_repository.dart';

Future<void> showFavoritesSheet(
  BuildContext context,
  VendorSocialRepository repository, {
  ValueChanged<VendorSummary>? onOpen,
}) async {
  await openDrawerOverlay<void>(
    context: context,
    position: OverlayPosition.bottom,
    expands: false,
    transformBackdrop: false,
    builder: (context) => SocialSheet(
      title: 'Favorites',
      topPadding: GetPrioTheme.bottomSheetTopPadding,
      headerSpacing: 8,
      child: FavoritesList(
        repository: repository,
        editable: true,
        onOpen: onOpen == null
            ? null
            : (vendor) {
                closeDrawer(context);
                onOpen(vendor);
              },
      ),
    ),
  ).future;
}

class SocialSheet extends StatelessWidget {
  const SocialSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.topPadding = 20,
    this.headerSpacing = 16,
  });
  final String title;
  final Widget child;
  final Widget? footer;
  final double topPadding;
  final double headerSpacing;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        topPadding,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height * .65 -
                    MediaQuery.viewInsetsOf(context).bottom)
                .clamp(120.0, MediaQuery.sizeOf(context).height * .65),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title).h3()),
                GhostButton(
                  density: ButtonDensity.icon,
                  onPressed: () => closeDrawer(context),
                  child: const Icon(LucideIcons.x),
                ),
              ],
            ),
            SizedBox(height: headerSpacing),
            Expanded(child: child),
            ?footer,
          ],
        ),
      ),
    ),
  );
}

class FavoritesList extends StatefulWidget {
  const FavoritesList({
    super.key,
    required this.repository,
    this.editable = false,
    this.onOpen,
  });
  final VendorSocialRepository repository;
  final bool editable;
  final ValueChanged<VendorSummary>? onOpen;
  @override
  State<FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<FavoritesList> {
  late Future<void> _load;
  @override
  void initState() {
    super.initState();
    _load = widget.repository.loadFavorites();
    widget.repository.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.hasError && widget.repository.favorites == null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load favorites.'),
            GhostButton(
              onPressed: () =>
                  setState(() => _load = widget.repository.loadFavorites()),
              child: const Text('Try again'),
            ),
          ],
        );
      }
      if (snapshot.connectionState != ConnectionState.done &&
          widget.repository.favorites == null) {
        return const Center(child: Text('Loading favorites…'));
      }
      return ListenableBuilder(
        listenable: widget.repository,
        builder: (context, _) {
          final all = widget.repository.favorites ?? [];
          final vendors = widget.editable ? all : all.take(5).toList();
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vendors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Save vendors using the heart on their profile.'),
                ),
              for (final vendor in vendors) ...[
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        style: const ButtonStyle.ghost().copyWith(
                          padding: (context, states, padding) =>
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: widget.onOpen == null
                            ? null
                            : () => widget.onOpen!(vendor),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: vendor.logoUrl == null
                                  ? Icon(LucideIcons.store, size: 30)
                                  : Image.network(
                                      vendor.logoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) =>
                                          Icon(LucideIcons.store, size: 30),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendor.name,
                                    style: const TextStyle(fontSize: 16),
                                  ).bold(),
                                  if (vendor.category?.isNotEmpty == true)
                                    Text(
                                      vendor.category!,
                                      style: const TextStyle(
                                        fontSize: GetPrioTypography.labelSize,
                                        color: GetPrioTheme.mutedInk,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.editable)
                      GhostButton(
                        key: ValueKey('delete-favorite-${vendor.slug}'),
                        density: ButtonDensity.icon,
                        onPressed: widget.repository.isPending(vendor.slug)
                            ? null
                            : () async {
                                try {
                                  await widget.repository.setFavorite(
                                    vendor,
                                    false,
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    showFeedbackToast(
                                      context,
                                      message: 'Could not remove favorite.',
                                      isError: true,
                                    );
                                  }
                                }
                              },
                        child: const Icon(
                          LucideIcons.trash2,
                          semanticLabel: 'Remove favorite',
                        ),
                      ),
                  ],
                ),
                const Divider(),
              ],
              if (!widget.editable && all.length > 5)
                GhostButton(
                  onPressed: () => showFavoritesSheet(
                    context,
                    widget.repository,
                    onOpen: widget.onOpen,
                  ),
                  child: const Text('View all favorites'),
                ),
            ],
          );
          return widget.editable
              ? SingleChildScrollView(child: content)
              : content;
        },
      );
    },
  );
}

String compactRatingCount(int count) => count >= 1000
    ? '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}k'
    : '$count';
String reviewDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});
  final VendorReview review;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(reviewDate(review.createdAt)),
            Semantics(
              label: '${review.stars} out of 5 stars',
              child: Text(
                '${'★' * review.stars}${'☆' * (5 - review.stars)}',
                style: const TextStyle(color: Color(0xFFB77900)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(review.comment.isEmpty ? 'No comment' : review.comment),
        const SizedBox(height: 12),
        Text('- ${review.customerName}'),
      ],
    ),
  );
}

class VendorSocialHeader extends StatefulWidget {
  const VendorSocialHeader({
    super.key,
    required this.repository,
    required this.vendor,
  });
  final VendorSocialRepository repository;
  final VendorSummary vendor;
  @override
  State<VendorSocialHeader> createState() => _VendorSocialHeaderState();
}

class _VendorSocialHeaderState extends State<VendorSocialHeader> {
  late Future<void> favorites;
  late Future<VendorReviewsPage> reviews;
  @override
  void initState() {
    super.initState();
    favorites = widget.repository.loadFavorites();
    reviews = widget.repository.reviews(widget.vendor.slug);
    widget.repository.addListener(_reload);
  }

  void _reload() {
    if (mounted) {
      setState(() => reviews = widget.repository.reviews(widget.vendor.slug));
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_reload);
    super.dispose();
  }

  static const _orange = Color(0xFFFF8800);
  static const _ink = Color(0xFF080808);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final favorite = widget.repository.contains(widget.vendor.slug);
      return Container(
        key: const Key('vendor-social-pill'),
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: GetPrioTheme.card.withAlpha(224),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<void>(
              future: favorites,
              builder: (context, snapshot) => SizedBox(
                width: 44,
                height: 44,
                child: GhostButton(
                  key: const Key('vendor-favorite-toggle'),
                  density: ButtonDensity.icon,
                  onPressed:
                      snapshot.connectionState != ConnectionState.done ||
                          widget.repository.isPending(widget.vendor.slug)
                      ? null
                      : () async {
                          try {
                            if (snapshot.hasError) {
                              await widget.repository.loadFavorites();
                            }
                            await widget.repository.setFavorite(
                              widget.vendor,
                              !widget.repository.contains(widget.vendor.slug),
                            );
                          } catch (_) {
                            if (context.mounted) {
                              showFeedbackToast(
                                context,
                                message: 'Could not update favorites.',
                                isError: true,
                              );
                            }
                          }
                        },
                  child: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    size: 26,
                    color: favorite ? _orange : _ink,
                    semanticLabel: favorite
                        ? 'Remove favorite'
                        : 'Add favorite',
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 30,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0x40000000),
              ),
            ),
            FutureBuilder<VendorReviewsPage>(
              future: reviews,
              builder: (context, snapshot) {
                final unrated = snapshot.hasData && snapshot.data!.count == 0;
                return GhostButton(
                  key: const Key('vendor-rating-summary'),
                  density: ButtonDensity.compact,
                  onPressed: () => showReviewsSheet(
                    context,
                    widget.repository,
                    widget.vendor.slug,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 9, right: 12),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            unrated ? Icons.star_border : Icons.star,
                            size: 27,
                            color: unrated ? _ink : _orange,
                          ),
                          const SizedBox(width: 6),
                          if (unrated)
                            const Text(
                              'Not yet rated',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: _ink,
                              ),
                            )
                          else ...[
                            Text(
                              snapshot.hasData
                                  ? snapshot.data!.average.toStringAsFixed(1)
                                  : '—',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              snapshot.hasData
                                  ? '(${compactRatingCount(snapshot.data!.count)})'
                                  : '(—)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: _ink,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showReviewsSheet(
  BuildContext context,
  VendorSocialRepository repository,
  String slug,
) async {
  await openDrawerOverlay<void>(
    context: context,
    position: OverlayPosition.bottom,
    expands: false,
    transformBackdrop: false,
    builder: (context) => SocialSheet(
      title: 'Reviews',
      topPadding: GetPrioTheme.bottomSheetTopPadding,
      headerSpacing: 8,
      child: VendorReviews(repository: repository, slug: slug, paginated: true),
    ),
  ).future;
}

class VendorReviews extends StatefulWidget {
  const VendorReviews({
    super.key,
    required this.repository,
    required this.slug,
    this.paginated = false,
  });
  final VendorSocialRepository repository;
  final String slug;
  final bool paginated;
  @override
  State<VendorReviews> createState() => _VendorReviewsState();
}

class _VendorReviewsState extends State<VendorReviews> {
  late Future<VendorReviewsPage> _load;
  int page = 1;
  @override
  void initState() {
    super.initState();
    _reload();
    widget.repository.addListener(_changed);
  }

  void _reload() {
    _load = widget.repository.reviews(
      widget.slug,
      page: page,
      pageSize: widget.paginated ? 10 : 5,
    );
  }

  void _changed() {
    if (mounted) setState(_reload);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<VendorReviewsPage>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: Text('Loading reviews…'));
      }
      if (snapshot.hasError) {
        return GhostButton(
          onPressed: _changed,
          child: const Text('Could not load reviews. Try again'),
        );
      }
      final data = snapshot.data!;
      if (data.reviews.isEmpty) return const Text('No public reviews yet.');
      if (widget.paginated) {
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: data.reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) =>
                    ReviewCard(review: data.reviews[index]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GhostButton(
                  onPressed: page <= 1
                      ? null
                      : () => setState(() {
                          page--;
                          _reload();
                        }),
                  child: const Text('Previous'),
                ),
                Text('$page / ${data.totalPages}'),
                GhostButton(
                  onPressed: page >= data.totalPages
                      ? null
                      : () => setState(() {
                          page++;
                          _reload();
                        }),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReviewCarousel(reviews: data.reviews),
          if (data.total > 5)
            GhostButton(
              onPressed: () =>
                  showReviewsSheet(context, widget.repository, widget.slug),
              child: const Text('View all reviews'),
            ),
        ],
      );
    },
  );
}

class _ReviewCarousel extends StatefulWidget {
  const _ReviewCarousel({required this.reviews});

  final List<VendorReview> reviews;

  @override
  State<_ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<_ReviewCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.reviews.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_controller.hasClients ||
          !TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent == false ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      _controller.animateToPage(
        (_index + 1) % widget.reviews.length,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _ReviewCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.reviews.length) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 245,
        child: PageView(
          controller: _controller,
          onPageChanged: (index) {
            setState(() => _index = index);
            _restartTimer();
          },
          children: widget.reviews
              .map(
                (review) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SingleChildScrollView(
                    child: ReviewCard(review: review),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 8),
      Semantics(
        label: 'Review ${_index + 1} of ${widget.reviews.length}',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.reviews.length,
            (index) => Container(
              key: ValueKey('review-carousel-dot-$index'),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == _index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == _index
                    ? GetPrioTheme.primary
                    : GetPrioTheme.mutedInk.withAlpha(80),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> showVendorRatingForm(
  BuildContext context,
  VendorSocialRepository repository,
  QueueTicket ticket,
) async {
  await showOverlay<void>(
    context,
    DialogConfiguration(),
    builder: (context) =>
        VendorRatingForm(repository: repository, ticket: ticket),
  ).future;
}

class VendorRatingForm extends StatefulWidget {
  const VendorRatingForm({
    super.key,
    required this.repository,
    required this.ticket,
  });
  final VendorSocialRepository repository;
  final QueueTicket ticket;
  @override
  State<VendorRatingForm> createState() => _VendorRatingFormState();
}

class _VendorRatingFormState extends State<VendorRatingForm> {
  final comment = TextEditingController();
  final _commentFocus = FocusNode();
  int stars = 0;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    _commentFocus.dispose();
    comment.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    _commentFocus.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.rate(
        widget.ticket.lookupCode,
        stars,
        comment.text.trim(),
      );
      if (mounted) {
        closeOverlay(context);
        showFeedbackToast(context, message: 'Thank you for your review.');
      }
    } catch (next) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not submit your review. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && stars == 0 && comment.text.isEmpty,
    child: AlertDialog(
      title: Text('Rate ${widget.ticket.vendorName ?? 'vendor'}'),
      content: SizedBox(
        width: 340,
        child: KeyboardAwareScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                children: [
                  for (var star = 1; star <= 5; star++)
                    GhostButton(
                      density: ButtonDensity.icon,
                      onPressed: busy
                          ? null
                          : () => setState(() => stars = star),
                      child: Semantics(
                        label: '$star stars',
                        excludeSemantics: true,
                        selected: star == stars,
                        child: Text(
                          star <= stars ? '★' : '☆',
                          style: const TextStyle(
                            fontSize: 28,
                            color: Color(0xFFB77900),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              KeyboardAwareField(
                focusNode: _commentFocus,
                builder: (context, focusNode) => TextField(
                  controller: comment,
                  focusNode: focusNode,
                  onTapOutside: (_) => _commentFocus.unfocus(),
                  enabled: !busy,
                  maxLines: 5,
                  maxLength: 500,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  placeholder: const Text('Share your experience (optional)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text('${comment.text.characters.length}/500'),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        GetPrioActionButton.outline(
          onPressed: busy ? null : () => closeOverlay(context),
          child: const Text('Do it later'),
        ),
        GetPrioActionButton.primary(
          onPressed: busy || stars == 0 ? null : submit,
          child: Text(busy ? 'Submitting…' : 'Rate vendor'),
        ),
      ],
    ),
  );
}

class TicketReviewAction extends StatefulWidget {
  const TicketReviewAction({
    super.key,
    required this.repository,
    required this.ticket,
    this.prompt = false,
  });
  final VendorSocialRepository repository;
  final QueueTicket ticket;
  final bool prompt;
  @override
  State<TicketReviewAction> createState() => _TicketReviewActionState();
}

class _TicketReviewActionState extends State<TicketReviewAction> {
  late Future<Map<String, dynamic>> _load;
  @override
  void initState() {
    super.initState();
    _load = widget.repository.ticketRating(widget.ticket.lookupCode);
    widget.repository.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(
        () => _load = widget.repository.ticketRating(widget.ticket.lookupCode),
      );
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return GhostButton(
          onPressed: _refresh,
          child: const Text('Could not load rating. Try again'),
        );
      }
      if (!snapshot.hasData) return const SizedBox.shrink();
      if (snapshot.data!['rating'] != null) {
        return const Text('Thank you for reviewing this visit.');
      }
      if (snapshot.data!['eligible'] != true) return const SizedBox.shrink();
      if (widget.prompt) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await promptVendorRating(
            this.context,
            widget.repository,
            widget.ticket,
          );
        });
      }
      return GetPrioActionButton.outline(
        onPressed: () =>
            showVendorRatingForm(context, widget.repository, widget.ticket),
        child: const Text('Rate vendor'),
      );
    },
  );
}

Future<void> promptVendorRating(
  BuildContext context,
  VendorSocialRepository repository,
  QueueTicket ticket,
) async {
  if (!repository.promptedTickets.add(ticket.lookupCode)) return;
  try {
    final status = await repository.ticketRating(ticket.lookupCode);
    if (!context.mounted ||
        status['eligible'] != true ||
        status['rating'] != null) {
      return;
    }
    final rate = await showOverlay<bool>(
      context,
      DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('How was your visit?'),
        content: Text(
          'Your ticket was served. Rate ${ticket.vendorName ?? 'the vendor'}.',
        ),
        actions: [
          GetPrioActionButton.outline(
            onPressed: () => closeOverlay(dialogContext, false),
            child: const Text('Do it later'),
          ),
          GetPrioActionButton.primary(
            onPressed: () => closeOverlay(dialogContext, true),
            child: const Text('Rate vendor'),
          ),
        ],
      ),
    ).future;
    if (context.mounted && rate == true) {
      await showVendorRatingForm(context, repository, ticket);
    }
  } catch (_) {
    repository.promptedTickets.remove(ticket.lookupCode);
  }
}
