import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';

class ProfileLevelWidgetWidget extends StatelessWidget {
  const ProfileLevelWidgetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(builder: (profileController) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault, 100,
          Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault,
        ),
        child: Row(children:  [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).primaryColor, width: 2)),
            child: ClipOval(
              child: ImageWidget(
                width: 52, height: 52,
                image: '${Get.find<SplashController>().config?.imageBaseUrl?.profileImage}/${profileController.profileInfo?.profileImage??""}',
              ),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeDefault),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
            Text(
              '${profileController.profileInfo?.firstName ?? ''}  ${profileController.profileInfo?.lastName ?? ''}',
              style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge),
              maxLines: 1,overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),

            if(Get.find<SplashController>().config?.levelStatus ?? false)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8),
                  child: Text(
                    (profileController.profileInfo != null && profileController.profileInfo!.level != null) ?
                    '${profileController.profileInfo?.level?.name}':
                    '',
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white),
                  ),
                ),
              ),
          ])),

          GestureDetector(
              onTap: ()=> Get.find<ProfileController>().toggleDrawer(),
              child: const SizedBox(child: Icon(CupertinoIcons.clear, color: Colors.white)),
          )


        ]),
      );
    });
  }
}
