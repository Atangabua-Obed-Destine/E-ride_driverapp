import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/helper/ride_request_ringer.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The customer paid the booking deposit: unlock the trip, ring briefly and
/// show a large "go to the pickup" alert. The socket and the push can both
/// arrive; it rings once per trip.
class DepositHelper {
  static final Set<String> _announced = {};

  /// When the driver last opened a trip from the "deposit received" alert.
  static DateTime? _openedAt;

  /// Only a payment this recent rings again inside the app (the phone already
  /// rang if it came in while the app was closed).
  static const Duration _freshFor = Duration(seconds: 20);

  static void onDepositPaid(String? tripId) {
    if (tripId == null || tripId.isEmpty) return;
    Get.find<RideController>().getRideDetails(tripId).then((value) {
      if (value.statusCode != 200 || !_announced.add(tripId)) return;
      // Just came in through the notification: already on the trip.
      if (_openedAt != null && DateTime.now().difference(_openedAt!) < const Duration(seconds: 10)) return;
      final deposit = Get.find<RideController>().tripDetail?.deposit;
      final paidAt = deposit?.paidAt;
      final fresh = paidAt == null || DateTime.now().add(deposit!.clockOffset).difference(paidAt) < _freshFor;
      if (fresh) {
        RideRequestRinger.startInAppRing(rideRequestId: tripId, duration: RideRequestRinger.depositRingFor);
      }
      _showAlert(tripId);
    });
  }

  /// Opens the trip on the map, ready to drive to the pickup.
  static Future<void> openTrip(String? tripId) async {
    RideRequestRinger.stopInAppRing();
    if (tripId == null || tripId.isEmpty) return;
    _announced.add(tripId);
    _openedAt = DateTime.now();
    final rideController = Get.find<RideController>();
    final value = await rideController.getRideDetails(tripId);
    if (value.statusCode != 200) return;
    final status = rideController.tripDetail?.currentStatus;
    if (status != 'accepted' && status != 'out_for_pickup') return;
    Get.find<RiderMapController>().setRideCurrentState(status == 'accepted' ? RideState.accepted : RideState.outForPickup);
    rideController.updateRoute(false, notify: true);
    if (Get.currentRoute != '/MapScreen') {
      Get.to(() => const MapScreen());
    }
  }

  static void _showAlert(String tripId) {
    final trip = Get.find<RideController>().tripDetail;
    final context = Get.context;
    if (context == null) return;
    final customer = (trip?.customer?.firstName ?? '').trim();
    final amount = trip?.deposit == null ? '' : PriceConverter.convertPrice(context, trip!.deposit!.amount);
    Get.dialog(
      Builder(builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          insetPadding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.paddingSizeLarge)),
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.verified_rounded, size: 44, color: theme.primaryColor),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text('deposit_received_title'.tr, textAlign: TextAlign.center,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                (customer.isEmpty ? 'deposit_received_body_no_name' : 'deposit_received_body').trParams({'customer': customer, 'amount': amount}),
                textAlign: TextAlign.center,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.4),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall)),
                  ),
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text('go_to_pickup'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    openTrip(tripId);
                  },
                ),
              ),
            ]),
          ),
        );
      }),
      barrierDismissible: true,
    ).then((_) => RideRequestRinger.stopInAppRing());
  }
}
