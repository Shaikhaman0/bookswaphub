import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswaphub/core/config/app_config.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/book_card.dart';
import 'package:bookswaphub/widgets/book_cover_placeholder.dart';
import 'package:bookswaphub/widgets/error_state.dart';

class BookDetailsScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookDetailsScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends ConsumerState<BookDetailsScreen> {
  bool _busy = false;

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookProvider(widget.bookId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Book Details'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          tooltip: 'Back',
          onPressed: () => AppNavigationHelper.handleBack(context),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(bookProvider(widget.bookId)),
        ),
        data: (book) {
          if (book == null || book.status == 'removed') {
            return const Center(child: Text('This book is no longer available.'));
          }
          return LayoutBuilder(builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= AppDimensions.tabletBreakpoint;
            return SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: isDesktop ? _desktop(book) : _mobile(book),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _cover(Book book, double height) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Hero(
        tag: 'book_cover_${book.id}',
        child: book.imageUrls.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Image.network(
                  book.imageUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => BookCoverPlaceholder(title: book.title, author: book.author),
                ),
              )
            : BookCoverPlaceholder(title: book.title, author: book.author),
      ),
    );
  }

  Widget _desktop(Book book) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 300, child: _cover(book, 450)),
          const SizedBox(width: AppDimensions.xxl),
          Expanded(child: _details(book)),
        ],
      );

  Widget _mobile(Book book) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cover(book, 350),
          const SizedBox(height: AppDimensions.lg),
          _details(book),
        ],
      );

  Widget _details(Book book) {
    final uid = ref.watch(currentUidProvider);
    final isOwner = uid != null && uid == book.ownerId;
    final wished = ref.watch(wishlistIdSetProvider).contains(book.id);
    final related = ref.watch(relatedBooksProvider((id: book.id, categoryId: book.categoryId)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(book.title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: AppDimensions.sm),
        Text('by ${book.author}', style: const TextStyle(fontSize: 20, color: AppColors.textSecondary)),
        const SizedBox(height: AppDimensions.md),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: [
            if (book.category.isNotEmpty) Chip(label: Text(book.category)),
            Chip(label: Text(book.condition)),
            Chip(label: Text(book.status == 'available' ? 'Available' : book.status)),
            if (book.canSwap) const Chip(label: Text('Swap')),
            if (book.canBuy && book.price != null)
              Chip(label: Text('${book.currency.toUpperCase()} ${book.price!.toStringAsFixed(2)}')),
          ],
        ),
        const SizedBox(height: AppDimensions.lg),
        const Text('Description', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppDimensions.sm),
        Text(book.description.isEmpty ? 'No description provided.' : book.description,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: AppDimensions.lg),
        _owner(book),
        const SizedBox(height: AppDimensions.xl),
        if (isOwner)
          OutlinedButton.icon(
            onPressed: () => context.push('/edit-book/${book.id}'),
            icon: const Icon(Icons.edit),
            label: const Text('Edit your listing'),
          )
        else
          _actions(book, wished, uid),
        const SizedBox(height: AppDimensions.xl),
        const Text('Related Books', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppDimensions.md),
        related.when(
          loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const Text('Could not load related books.'),
          data: (books) => books.isEmpty
              ? const Text('No related books yet.', style: TextStyle(color: AppColors.textSecondary))
              : SizedBox(
                  height: 350,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.md),
                    itemBuilder: (_, i) => SizedBox(width: 150, child: BookCard(book: books[i])),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _actions(Book book, bool wished, String? uid) {
    final canAct = book.isAvailable && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (book.canSwap)
              Expanded(
                child: ElevatedButton(
                  onPressed: canAct ? () => _requestSwap(book) : null,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg)),
                  child: const Text('Request Swap', style: TextStyle(fontSize: 18)),
                ),
              ),
            if (book.canSwap && book.canBuy) const SizedBox(width: AppDimensions.md),
            if (book.canBuy && book.price != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: canAct ? () => _buy(book) : null,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg)),
                  child: Text('Buy (TEST) ${book.currency.toUpperCase()} ${book.price!.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            const SizedBox(width: AppDimensions.md),
            IconButton(
              tooltip: wished ? 'Remove from wishlist' : 'Add to wishlist',
              icon: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? Colors.red : null),
              iconSize: 32,
              onPressed: uid == null ? null : () => _toggleWishlist(uid, book.id, wished),
            ),
          ],
        ),
        if (!book.isAvailable)
          const Padding(
            padding: EdgeInsets.only(top: AppDimensions.sm),
            child: Text('This book is not available right now.', style: TextStyle(color: AppColors.textSecondary)),
          ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => context.go('/chat?with=${book.ownerId}'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message owner'),
            ),
            TextButton.icon(
              onPressed: () => _report(book),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report'),
            ),
          ],
        ),
        if (book.canBuy && AppConfig.paymentsDisabledReason != null)
          Text(AppConfig.paymentsDisabledReason!, style: const TextStyle(color: Colors.orange, fontSize: 12)),
        if (book.canBuy)
          const Text('Payments run in Stripe TEST mode only. Use test card 4242 4242 4242 4242. No real money is charged.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _owner(Book book) {
    final profile = ref.watch(profileProvider(book.ownerId));
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: book.ownerAvatar.isNotEmpty ? NetworkImage(book.ownerAvatar) : null,
            child: book.ownerAvatar.isEmpty ? const Icon(Icons.person, color: AppColors.primary) : null,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Owner: ${book.ownerName.isEmpty ? 'Reader' : book.ownerName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  profile.when(
                    data: (u) => u.rating > 0 ? '${u.rating.toStringAsFixed(1)}/5 rating' : 'No ratings yet',
                    loading: () => '…',
                    error: (_, __) => '',
                  ),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/profile/${book.ownerId}'),
            child: const Text('View Profile'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ actions

  Future<void> _toggleWishlist(String uid, String bookId, bool wished) async {
    try {
      final repo = ref.read(wishlistRepositoryProvider);
      wished ? await repo.remove(uid, bookId) : await repo.add(uid, bookId);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _requestSwap(Book book) async {
    final mine = (ref.read(myBooksProvider).asData?.value ?? const <Book>[])
        .where((b) => b.isAvailable && b.canSwap)
        .toList();
    String? offered;
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Request a swap'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                value: offered,
                decoration: const InputDecoration(labelText: 'Book you offer (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No book (just ask)')),
                  ...mine.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.title, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setS(() => offered = v),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade300, width: 0.7),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.blue),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: Whenever the owner accepts your swap request, your offered book will be confirmed as exchanged and automatically removed from your account.',
                        style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msg,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send request')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(swapRepositoryProvider).request(bookId: book.id, offeredBookId: offered, message: msg.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Swap request sent! View it in the Sent tab.'),
            action: SnackBarAction(
              label: 'View Swaps',
              onPressed: () => context.go('/swaps'),
            ),
          ),
        );
      }
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Stripe TEST checkout. The server sets the price; the app only sends the book id.
  /// "Paid" is shown only after the webhook marks the order as paid in Firestore.
  Future<void> _buy(Book book) async {
    final reason = AppConfig.paymentsDisabledReason;
    if (reason != null) {
      _snack(reason);
      return;
    }
    if (kIsWeb) {
      _snack('Test checkout is available on the Android/iOS app. (Web is not supported in this version.)');
      return;
    }
    setState(() => _busy = true);
    try {
      final order = await ref.read(paymentRepositoryProvider).createOrder(book.id);
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: order.clientSecret,
          merchantDisplayName: 'Book Swap Hub (TEST)',
          allowsDelayedPaymentMethods: true,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      _snack('Payment submitted. Waiting for server confirmation…');
      final status = await ref
          .read(paymentRepositoryProvider)
          .watchOrderStatus(order.orderId)
          .firstWhere((s) => s != 'pending' && s != 'requires_payment')
          .timeout(const Duration(seconds: 45), onTimeout: () => 'pending');
      _snack(status == 'paid'
          ? 'Payment confirmed (TEST). Thank you!'
          : status == 'pending'
              ? 'Still processing. Check back shortly.'
              : 'Payment status: $status');
    } on StripeException catch (e) {
      _snack(e.error.code == FailureCode.Canceled ? 'Payment cancelled.' : (e.error.localizedMessage ?? 'Payment failed.'));
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report(Book book) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    String reason = 'spam';
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Report this listing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                items: const ['spam', 'inappropriate', 'fake', 'scam', 'other']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setS(() => reason = v ?? 'spam'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Details (optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(reviewRepositoryProvider).report(
            reporterId: uid,
            targetType: 'book',
            targetId: book.id,
            reason: reason,
            details: details.text,
          );
      _snack('Thanks, our team will review this report.');
    } catch (e) {
      _snack(friendlyError(e));
    }
  }
}
