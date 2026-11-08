import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/location/widgets/location_radar.dart';
import 'package:ride_sharing_user_app/features/out_of_zone/controllers/out_of_zone_controller.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/loader_widget.dart';


/// First screen after login: the E-Ride radar artwork, the pitch, and the
/// one action, pinned to the bottom. Same screen the user app shows, with the
/// driver's copy. The location flow in [BottomButton] is unchanged.
class AccessLocationScreen extends StatelessWidget {
  const AccessLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        body: PopScope(canPop: false,
          onPopInvokedWithResult: (didPop, val) async {
            if (didPop) return;
            Get.find<BottomMenuController>().exitApp();
            return;
          },
          child: GetBuilder<LocationController>(builder: (locationController) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(children: [
                  Expanded(
                    child: LayoutBuilder(builder: (context, viewport) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: viewport.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeExtraLarge,
                              vertical: Dimensions.paddingSizeLarge,
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              LayoutBuilder(builder: (context, constraints) {
                                final double side = constraints.maxWidth.clamp(0.0, 252.0);
                                return LocationRadar(size: side);
                              }),
                              const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                              Text(
                                'find_customer_near_you'.tr,
                                textAlign: TextAlign.center,
                                style: textBold.copyWith(fontSize: 22, height: 1.3, color: Theme.of(context).textTheme.bodyMedium?.color),
                              ),
                              const SizedBox(height: Dimensions.paddingSizeSmall),

                              Text(
                                'please_select_you_location_to_start_finding_available_customer_near_you'.tr,
                                textAlign: TextAlign.center,
                                style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.6, color: Theme.of(context).hintColor),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ),

                  const BottomButton(),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class BottomButton extends StatelessWidget {
  const BottomButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeExtraLarge, 0, Dimensions.paddingSizeExtraLarge, Dimensions.paddingSizeExtraLarge,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ButtonWidget(buttonText: 'use_current_location'.tr,
          radius: 16, height: 52,
          onPressed: () async {
            Get.find<LocationController>().checkPermission().then((permission){
             if(permission){
               Get.dialog(const LoaderWidget(), barrierDismissible: false);
               Get.find<LocationController>().getCurrentLocation().then((value){
                 Get.back();
                 if(value.latitude != 0 && value.longitude != 0){
                   if(Get.find<AuthController>().isLoggedIn()){
                     Get.find<OutOfZoneController>().getZoneList();
                     Get.offAll(()=> const DashboardScreen());
                   }else{
                     LoginHelper.checkLoginMedium();
                   }
                 }
               });
             }
            });

          }, icon: Icons.my_location,
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: Theme.of(context).hintColor),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Flexible(child: Text(
            'location_used_only_for_matching'.tr,
            textAlign: TextAlign.center,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
          )),
        ]),
      ]),
    );
  }
}
