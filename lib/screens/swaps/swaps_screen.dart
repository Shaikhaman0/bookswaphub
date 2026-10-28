import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/data/models/swap_request.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/error_state.dart';
import 'package:bookswaphub/widgets/swap_status_chip.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:go_router/go_router.dart';

class SwapsScreen extends ConsumerStatefulWidget {
  const SwapsScreen({super.key});

  @override
  ConsumerState<SwapsScreen> createState() => _SwapsScreenState();
}

class _SwapsScreenState extends ConsumerState<SwapsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _uid = '';
  String? _busySwapId;
  bool _autoSwitched = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );

  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// All swap changes go to the server (Cloud Function), which validates who may do what.
  Future<void> _act(String swapId, String action) async {
    setState(() => _busySwapId = swapId);
    try {
      await ref.read(swapRepositoryProvider).act(swapId, action, myUid: _uid);
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busySwapId = null);
    }
  }

  Future<void> _confirmAndAccept(String swapId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Swap Request?'),
        content: const Text(
          'Please confirm: If you accept this swap request, your book and the offered book will be confirmed as exchanged and removed from your active account library.\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept & Exchange'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _act(swapId, 'accept');
    }
  }

  Future<void> _review(SwapRequest swap) async {
    int rating = 5;
    final comment = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Leave a review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setLocal(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(controller: comment, maxLength: 1000, maxLines: 3, decoration: const InputDecoration(hintText: 'How did it go?')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (submit != true) return;
    try {
      await ref.read(swapRepositoryProvider).submitReview(swapId: swap.id, rating: rating, comment: text);
      if (mounted) _toast('Review submitted. Thank you!');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  List<SwapRequest> _getFilteredSwaps(List<SwapRequest> swaps, int tabIndex) {
    switch (tabIndex) {
      case 0:
        return swaps
            .where(
              (s) =>
          s.status == SwapStatus.pending &&
              s.ownerId == _uid,
        )
            .toList();

      case 1:
        return swaps
            .where(
              (s) =>
          s.status == SwapStatus.pending &&
              s.requesterId == _uid,
        )
            .toList();

      case 2:
        return swaps
            .where(
              (s) =>
          s.status == SwapStatus.accepted ||
              s.status == SwapStatus.inProgress,
        )
            .toList();

      case 3:
        return swaps
            .where(
              (s) =>
          s.status == SwapStatus.completed ||
              s.status == SwapStatus.rejected ||
              s.status == SwapStatus.cancelled,
        )
            .toList();

      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    _uid = ref.watch(currentUidProvider) ?? '';
    final swapsAsync = ref.watch(swapsProvider);

    return swapsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Swaps')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Swaps')),
        body: ErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(swapsProvider)),
      ),
      data: (swaps) {
        final incoming = _getFilteredSwaps(swaps, 0);
        final sent = _getFilteredSwaps(swaps, 1);
        final active = _getFilteredSwaps(swaps, 2);
        final completed = _getFilteredSwaps(swaps, 3);

        if (!_autoSwitched && incoming.isEmpty && sent.isNotEmpty) {
          _autoSwitched = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _tabController.index == 0) {
              _tabController.animateTo(1);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Swaps'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(text: incoming.isEmpty ? 'Incoming' : 'Incoming (${incoming.length})'),
                Tab(text: sent.isEmpty ? 'Sent' : 'Sent (${sent.length})'),
                Tab(text: active.isEmpty ? 'Active' : 'Active (${active.length})'),
                Tab(text: completed.isEmpty ? 'Completed' : 'Completed (${completed.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSwapList(incoming, 'Incoming', 'No incoming swap requests.'),
              _buildSwapList(sent, 'Sent', 'You haven\'t sent any swap requests.'),
              _buildSwapList(active, 'Active', 'No active swaps.'),
              _buildSwapList(completed, 'Completed', 'No completed swaps yet.'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwapList(
      List<SwapRequest> swaps,
      String tabName,
      String emptyMessage,
      ) {
    if (swaps.isEmpty) {
      return EmptyState(
        icon: Icons.swap_horiz,
        title: 'No $tabName Swaps',
        description: emptyMessage,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > AppDimensions.tabletBreakpoint) {
          return GridView.builder(
            padding: const EdgeInsets.all(
              AppDimensions.lg,
            ),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: AppDimensions.md,
              mainAxisSpacing: AppDimensions.md,
            ),
            itemCount: swaps.length,
            itemBuilder: (context, index) {
              return _buildSwapCard(swaps[index]);
            },
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(
              AppDimensions.md,
            ),
            itemCount: swaps.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.md,
                ),
                child: _buildSwapCard(swaps[index]),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildSwapCard(SwapRequest swap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppDimensions.radiusLg,
        ),
      ),
      child: InkWell(
        onTap: () => _showSwapDetails(swap),
        borderRadius: BorderRadius.circular(
          AppDimensions.radiusLg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            AppDimensions.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SwapStatusChip(
                    status: swap.status.name,
                  ),
                  Text(
                    '${swap.createdAt.day}/${swap.createdAt.month}/${swap.createdAt.year}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: swap.requesterAvatar.isNotEmpty ? NetworkImage(swap.requesterAvatar) : null,
                    child: swap.requesterAvatar.isEmpty
                        ? Text(
                            swap.requesterName.isNotEmpty ? swap.requesterName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 10),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      swap.requesterId == _uid ? 'Sent to ${swap.ownerName}' : 'From ${swap.requesterName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: AppDimensions.sm,
              ),
              Container(
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildBookInfo(
                        swap.bookTitle,
                        swap.bookCover,
                        label: 'Requested',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                      ),
                      child: Icon(
                        Icons.sync_alt,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: _buildBookInfo(
                        swap.offeredBookTitle ?? 'Open offer',
                        swap.offeredBookCover ?? '',
                        label: 'Offered',
                      ),
                    ),
                  ],
                ),
              ),
              if (swap.message.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          swap.message,
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (swap.status == SwapStatus.pending) ...[
                const SizedBox(height: AppDimensions.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: swap.ownerId == _uid
                        ? Colors.amber.withValues(alpha: 0.12)
                        : Colors.blue.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(
                      color: swap.ownerId == _uid ? Colors.amber.shade400 : Colors.blue.shade300,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        swap.ownerId == _uid ? Icons.warning_amber_rounded : Icons.info_outline,
                        size: 16,
                        color: swap.ownerId == _uid ? Colors.amber.shade800 : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          swap.ownerId == _uid
                              ? 'Notice: If you accept this swap request, your book and the offered book will be marked as exchanged and removed from your account.'
                              : 'Notice: Whenever the owner accepts your swap request, your offered book will be marked as exchanged and removed from your account.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: swap.ownerId == _uid ? Colors.brown.shade800 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(
                height: AppDimensions.sm,
              ),
              _buildActionButtons(swap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookInfo(
    String title,
    String coverUrl, {
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(
            AppDimensions.radiusSm,
          ),
          child: SizedBox(
            width: 60,
            height: 80,
            child: coverUrl.isEmpty
                ? Container(
                    color: AppColors.divider,
                    child: const Icon(Icons.book, color: AppColors.textSecondary, size: 28),
                  )
                : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.divider,
                        child: const Icon(
                          Icons.book,
                          color: AppColors.textSecondary,
                          size: 28,
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(
          height: AppDimensions.xs,
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons(SwapRequest swap) {
    final busy = _busySwapId == swap.id;
    final isOwner = swap.ownerId == _uid;
    final isRequester = swap.requesterId == _uid;
    final otherId = isOwner ? swap.requesterId : swap.ownerId;

    Widget chatButton() => TextButton.icon(
          onPressed: () => context.go('/chat?with=$otherId'),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Message'),
        );

    if (swap.status == SwapStatus.pending && isOwner) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: busy ? null : () => _act(swap.id, 'reject'),
            child: const Text('Reject', style: TextStyle(color: AppColors.error)),
          ),
          const SizedBox(width: AppDimensions.sm),
          ElevatedButton(
            onPressed: busy ? null : () => _confirmAndAccept(swap.id),
            child: Text(busy ? '...' : 'Accept'),
          ),
        ],
      );
    }

    if (swap.status == SwapStatus.pending && isRequester) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: busy ? null : () => _act(swap.id, 'cancel'),
          child: const Text('Cancel Request', style: TextStyle(color: AppColors.error)),
        ),
      );
    }

    if (swap.status == SwapStatus.accepted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          chatButton(),
          TextButton(
            onPressed: busy ? null : () => _act(swap.id, 'cancel'),
            child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: busy ? null : () => _act(swap.id, 'start'),
            child: const Text('Mark In Progress'),
          ),
        ],
      );
    }

    if (swap.status == SwapStatus.inProgress) {
      final iConfirmed = swap.confirmedBy.contains(_uid);
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          chatButton(),
          ElevatedButton(
            // Completion needs BOTH people to confirm that the exchange really happened.
            onPressed: (busy || iConfirmed) ? null : () => _act(swap.id, 'confirmComplete'),
            child: Text(iConfirmed ? 'Waiting for the other person' : 'Confirm exchange done'),
          ),
        ],
      );
    }

    if (swap.status == SwapStatus.completed) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _review(swap),
          icon: const Icon(Icons.star_border, size: 18),
          label: const Text('Leave a review'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showSwapDetails(
      SwapRequest swap,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            AppDimensions.radiusLg,
          ),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(
            AppDimensions.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Swap Progress',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(
                height: AppDimensions.lg,
              ),

              _buildTimelineStep(
                'Request Sent',
                true,
              ),

              _buildTimelineStep(
                'Accepted',
                swap.status != SwapStatus.pending &&
                    swap.status != SwapStatus.rejected &&
                    swap.status != SwapStatus.cancelled,
              ),

              _buildTimelineStep(
                'Exchange In Progress',
                swap.status == SwapStatus.inProgress ||
                    swap.status == SwapStatus.completed,
              ),

              _buildTimelineStep(
                'Completed',
                swap.status == SwapStatus.completed,
                isLast: true,
              ),

              const SizedBox(
                height: AppDimensions.xl,
              ),

              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineStep(
      String title,
      bool isCompleted, {
        bool isLast = false,
      }) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.success
                    : AppColors.divider,
              ),
              child: isCompleted
                  ? const Icon(
                Icons.check,
                size: 16,
                color: Colors.white,
              )
                  : null,
            ),

            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted
                    ? AppColors.success
                    : AppColors.divider,
              ),
          ],
        ),

        const SizedBox(
          width: AppDimensions.md,
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: 24.0,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isCompleted
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isCompleted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}