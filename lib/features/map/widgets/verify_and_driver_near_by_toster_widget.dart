import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/helper/extension_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class VerifyAndDriverNearByToasterWidget extends StatelessWidget {
  const VerifyAndDriverNearByToasterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController){
      return GetBuilder<RiderMapController>(builder: (riderMapController){
        return ((Get.find<SplashController>().config?.enableAutoArrivalNotification ?? false) && rideController.isShowDriverArrivalTooltip && (riderMapController.currentRideState == RideState.accepted || riderMapController.currentRideState == RideState.outForPickup)) ?
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
              color: Theme.of(context).cardColor
          ),
          margin: EdgeInsets.all(Dimensions.paddingSizeSmall).copyWith(top: Get.height * 0.15),
          padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: Row(children: [
            Icon(Icons.info, color: context.customThemeColors.infoColor),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('almost_at_pickup_point'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall)),

                  InkWell(
                    onTap: ()=> rideController.toggleShowDriverNearByTooltip(false),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).hintColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                  ),
                ]),

                RichText(text: TextSpan(text: 'almost_there_just'.tr, children: [
                  TextSpan(text: ' ${rideController.remainingDistanceItem.isNotEmpty ? rideController.remainingDistanceItem[0].duration?.split(' ').first : ((Get.find<SplashController>().config?.notificationArriveTime ?? 0)/60)} ', style: textBold.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall)),
                  TextSpan(text: 'minutes_away_avoid_unnecessary_calls'.tr, style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall))
                ], style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall)))
              ]),
            )
          ]),
        ) :
        const SizedBox();
      });
    });
  }
}
