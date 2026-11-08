import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/features/trip/screens/review_this_customer_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// E-Ride Move: the customer needs a truck. There is no fare in the app:
/// the driver and the customer agree the price in person, at the pickup.

/// "Move" with what the customer is moving and the photos of the load.
class MoveLoadCard extends StatelessWidget {
  final TripDetail trip;
  final EdgeInsets margin;
  const MoveLoadCard({super.key, required this.trip, this.margin = const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall)});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String note = (trip.note ?? '').trim();
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_shipping_rounded, size: 18, color: theme.primaryColor),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Text('move_what_to_carry'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor)),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(note, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.35)),
        ],
        if (trip.movePhotos.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Row(children: [
            for (final String url in trip.movePhotos)
              Padding(
                padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                child: InkWell(
                  onTap: () => _openPhoto(context, url),
                  borderRadius: BorderRadius.circular(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: theme.hintColor.withValues(alpha: 0.2))),
                  ),
                ),
              ),
          ]),
        ],
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.handshake_outlined, size: 16, color: theme.hintColor),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Expanded(child: Text('move_price_agree_with_customer'.tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
        ]),
      ]),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog(context: context, builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
    ));
  }
}

/// "We couldn't agree on the price": at the pickup, once the deposit is paid.
/// The move is cancelled; the server checks the driver is at the pickup.
class MoveNoAgreementButton extends StatelessWidget {
  final TripDetail trip;
  const MoveNoAgreementButton({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    if (!trip.isMove || !(trip.deposit?.isPaid ?? false)) return const SizedBox();
    final ThemeData theme = Theme.of(context);
    return GetBuilder<RideController>(builder: (rideController) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: rideController.movingNoAgreement ? null : () => _confirm(context),
            icon: rideController.movingNoAgreement
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.do_not_disturb_alt_rounded, color: theme.colorScheme.error),
            label: Text('move_no_agreement_button'.tr, style: textMedium.copyWith(color: theme.colorScheme.error)),
          ),
        ),
      );
    });
  }

  Future<void> _confirm(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    final bool? yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('move_no_agreement_title'.tr),
      content: Text('move_no_agreement_confirm_driver'.tr),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('move_keep_talking'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('move_cancel_the_move'.tr),
        ),
      ],
    ));
    if (yes != true) return;
    final bool done = await Get.find<RideController>().noAgreement(trip.id!);
    if (!done) return;
    Get.find<RiderMapController>().setRideCurrentState(RideState.initial);
    Get.offAll(() => const DashboardScreen());
    showCustomSnackBar('move_cancelled_no_agreement_driver'.tr, isError: false);
  }
}

/// The move is over (completed, or cancelled once it had started). Nothing
/// is paid in the app: collect the price you agreed, then the review.
void finishCompletedMove(String tripId, {bool reviewed = false}) {
  Get.find<RiderMapController>().setRideCurrentState(RideState.initial);
  if ((Get.find<SplashController>().config?.reviewStatus ?? false) && !reviewed) {
    Get.offAll(() => ReviewThisCustomerScreen(tripId: tripId));
  } else {
    Get.offAll(() => const DashboardScreen());
  }
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    Future.delayed(const Duration(milliseconds: 400), _showMoveCompletedSheet);
  } else {
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(onResume: () {
      listener.dispose();
      Future.delayed(const Duration(milliseconds: 600), _showMoveCompletedSheet);
    });
  }
}

Future<void> _showMoveCompletedSheet() async {
  final RideController ride = Get.find<RideController>();
  final double deposit = ride.tripDetail?.deposit?.amount ?? 0;
  await Get.bottomSheet(
    Builder(builder: (context) {
      final ThemeData theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.paddingSizeLarge)),
        ),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.check_circle_rounded, size: 40, color: theme.primaryColor),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('move_completed_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge)),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            deposit > 0
                ? 'move_completed_body_driver_fee'.trParams({'amount': PriceConverter.convertPrice(context, deposit)})
                : 'move_completed_body_driver'.tr,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.4),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr),
            ),
          ),
        ])),
      );
    }),
    isScrollControlled: true,
  );
}
