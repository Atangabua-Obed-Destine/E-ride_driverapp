import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/common_widgets/unread_badge.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_inbox_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';



class RiderDetailsWidget extends StatelessWidget {
  final RideController rideController;
  const RiderDetailsWidget({super.key, required this.rideController});

  @override
  Widget build(BuildContext context) {
    return Container(width: Get.width,
      margin: const EdgeInsets.only(
        left: Dimensions.paddingSizeLarge,
        right: Dimensions.paddingSizeLarge,
        bottom: Dimensions.paddingSizeLarge,
      ),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
        border: Border.all(width: .75, color: Theme.of(context).hintColor.withValues(alpha: 0.25)),
      ),
      child: Padding(padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Stack(children: [
              Container(
                transform: Matrix4.translationValues(
                  Get.find<LocalizationController>().isLtr ? -3 : 3, -3, 0,
                ),
                child: CircularPercentIndicator(radius: 28, percent: .75,lineWidth: 1,
                  backgroundColor: Colors.transparent,
                  progressColor: Theme.of(Get.context!).primaryColor,
                ),
              ),

              ClipRRect(borderRadius : BorderRadius.circular(100),
                child: ImageWidget(width: 50,height: 50,
                  image: rideController.tripDetail!.customer?.profileImage != null ?
                  '${Get.find<SplashController>().config!.imageBaseUrl!.profileImageCustomer}'
                      '/${rideController.tripDetail!.customer?.profileImage??''}' :
                  '',
                ),
              ),
            ]),

            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if(rideController.tripDetail!.customer!.firstName != null )
                SizedBox(width:100 ,
                  child: Text('${rideController.tripDetail!.customer!.firstName!} '
                      '${rideController.tripDetail!.customer!.lastName ?? ''}',
                  ),
                ),

              if(rideController.tripDetail!.customer != null)
                Row(children: [
                  Icon(
                    Icons.star_rate_rounded, color: Theme.of(Get.context!).primaryColor,
                    size: Dimensions.iconSizeMedium,
                  ),

                  Text(
                    double.parse(rideController.tripDetail!.customerAvgRating!).toStringAsFixed(1),
                    style: textRegular,
                  ),
                ]),
            ]),
          ]),

          Container(width: 1,height: 25, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.15)),

          InkWell(
            onTap : () => Get.find<ChatController>().createChannel(
              rideController.tripDetail!.customer!.id!,tripId: rideController.tripDetail!.id,
            ),
            child: GetBuilder<ChatInboxController>(builder: (inbox) => UnreadBadge(
              count: inbox.unreadForTrip(rideController.tripDetail?.id),
              offset: const Offset(-9, -8),
              child: SizedBox(width: Dimensions.iconSizeLarge,
                child: Image.asset(Images.customerMessage, color: Theme.of(context).primaryColor),
              ),
            )),
          ),

          Container(width: 1,height: 25, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.15)),

          InkWell(
            onTap: () => CallOptionsSheet.show(
              phone: rideController.tripDetail?.customer?.phone,
              name: '${rideController.tripDetail?.customer?.firstName ?? ''} ${rideController.tripDetail?.customer?.lastName ?? ''}',
            ),
            child: SizedBox(width: Dimensions.iconSizeLarge,
              child: Image.asset(Images.customerCall, color: Theme.of(context).primaryColor),
            ),
          ),

          const SizedBox()
        ]),
      ),
    );
  }
}