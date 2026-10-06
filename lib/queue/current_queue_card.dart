import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

enum CurrentQueueCardStatus { open, unavailable, closed, paused }

class CurrentQueueCard extends StatelessWidget {
  const CurrentQueueCard({
    super.key,
    required this.status,
    this.waitingCount,
    this.currentTicketNumber,
    this.estimatedWaitMinutes,
    this.lastCalledAt,
    this.fee,
    this.unavailableReason,
  });

  final CurrentQueueCardStatus status;
  final int? waitingCount;
  final String? currentTicketNumber;
  final int? estimatedWaitMinutes;
  final DateTime? lastCalledAt;
  final String? fee;
  final String? unavailableReason;

  String _callTime(DateTime? date) {
    if (date == null) return '--';
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final statusBadge = switch (status) {
      CurrentQueueCardStatus.open => const PrimaryBadge(
        child: Text('QUEUE OPEN'),
      ),
      CurrentQueueCardStatus.paused => const SecondaryBadge(
        child: Text('PAUSED'),
      ),
      CurrentQueueCardStatus.closed => const DestructiveBadge(
        child: Text('QUEUE CLOSED'),
      ),
      CurrentQueueCardStatus.unavailable => const OutlineBadge(
        child: Text('UNAVAILABLE'),
      ),
    };
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: const Text('Current queue').h4()),
              statusBadge,
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  value: waitingCount?.toString() ?? '--',
                  label: 'WAITING IN LINE',
                  detailLabel: 'Currently serving',
                  detailValue: currentTicketNumber ?? '--',
                ),
              ),
              const SizedBox(
                height: 42,
                child: VerticalDivider(width: 1, thickness: 1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Metric(
                  value: estimatedWaitMinutes == null
                      ? '--'
                      : '$estimatedWaitMinutes mins',
                  label: 'ESTIMATED WAIT',
                  detailLabel: 'Last called ticket',
                  detailValue: _callTime(lastCalledAt),
                ),
              ),
            ],
          ),
          if (fee != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text(fee!),
          ],
          if (status == CurrentQueueCardStatus.unavailable &&
              unavailableReason != null) ...[
            const SizedBox(height: 12),
            Text(unavailableReason!),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.detailLabel,
    required this.detailValue,
  });

  final String value;
  final String label;
  final String detailLabel;
  final String detailValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).typography.xSmall
              .copyWith(color: GetPrioTheme.mutedInk),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).typography.h2),
        const SizedBox(height: 6),
        Text('$detailLabel $detailValue'),
      ],
    );
  }
}
