import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_deposit_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// After accepting: while the customer has not paid the booking deposit, the
/// driver waits (and does not set off) with the time left. Once paid, a short
/// line says it is paid and will not be collected in cash.
class DepositWaitingBanner extends StatefulWidget {
  final TripDetail trip;
  const DepositWaitingBanner({super.key, required this.trip});

  /// The driver must wait before setting off or starting the trip.
  static bool blocks(TripDetail? trip) => trip?.deposit?.isAwaiting ?? false;

  @override
  State<DepositWaitingBanner> createState() => _DepositWaitingBannerState();
}

class _DepositWaitingBannerState extends State<DepositWaitingBanner> {
  Timer? _timer;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final deposit = widget.trip.deposit;
      // Time ran out: the server cancels the trip on its next sweep (up to a minute
      // or so later). Read it again every 10 s until it does, not just once.
      if (deposit != null && deposit.isAwaiting && deposit.timeLeft == Duration.zero) {
        final DateTime now = DateTime.now();
        if (_lastCheck == null || now.difference(_lastCheck!) >= const Duration(seconds: 10)) {
          _lastCheck = now;
          // Once the trip is gone, stop: while the app is hidden the move to the
          // dashboard only completes when it comes back, and this kept asking.
          Get.find<RideController>().checkTripStillMine(widget.trip.id!).then((bool mine) {
            if (!mine) _timer?.cancel();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final TripDeposit? deposit = widget.trip.deposit;
    if (deposit == null || !(deposit.isAwaiting || deposit.isPaid || deposit.isApplied)) return const SizedBox();
    final theme = Theme.of(context);
    final amount = PriceConverter.convertPrice(context, deposit.amount);

    if (!deposit.isAwaiting) {
      return Container(
        margin: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
        ),
        child: Row(children: [
          Icon(Icons.verified_rounded, size: 18, color: theme.primaryColor),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Expanded(child: Text((widget.trip.isMove ? 'move_deposit_received_line' : 'deposit_received_line').trParams({'amount': amount}),
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
        ]),
      );
    }

    final left = deposit.timeLeft;
    final customer = (widget.trip.customer?.firstName ?? '').trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeDefault),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.orange)),
        const SizedBox(width: Dimensions.paddingSizeDefault),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('deposit_waiting_title'.tr,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Text(
            (customer.isEmpty ? 'deposit_waiting_body_no_name' : 'deposit_waiting_body').trParams({'amount': amount, 'customer': customer}),
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color, height: 1.35),
          ),
        ])),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Text(_clock(left), style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: Colors.orange.shade800)),
      ]),
    );
  }
}
