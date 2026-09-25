import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/out_of_zone/controllers/out_of_zone_controller.dart';
import 'package:ride_sharing_user_app/features/out_of_zone/screens/out_of_zone_map_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class OutOfZoneWidget extends StatelessWidget {
  const OutOfZoneWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OutOfZoneController>(builder: (outOfZoneController){
      return outOfZoneController.isDriverOutOfZone ?
      InkWell(
        onTap: ()=> Get.to(()=> const OutOfZoneMapScreen()),
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          margin: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall, horizontal: Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.1)
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.warning,size: 24,color: Theme.of(context).colorScheme.error),
              const SizedBox(width: Dimensions.paddingSizeDefault),

              Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
                Text('you_are_out_of_zone'.tr,style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall)),

                Text('to_get_request_must'.tr,style: textRegular.copyWith(fontSize: 10,color: Theme.of(context).primaryColor))
              ])
            ]),

            Image.asset(Images.homeOutOfZoneIcon,height: 30,width: 30)
          ]),
        ),
      ) :
      const SizedBox();
    });
  }
}
