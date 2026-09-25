import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/confirmation_bottomsheet_widget.dart';
import 'package:ride_sharing_user_app/features/availability/controllers/availability_controller.dart';
import 'package:ride_sharing_user_app/features/availability/widgets/daily_time_widget.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {

  @override
  void initState() {
    Get.find<AvailabilityController>().initScheduleData(Get.find<ProfileController>().profileInfo, isUpdate: false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBarWidget(title: 'availability'.tr, regularAppbar: true),
        body: GetBuilder<AvailabilityController>(builder: (availabilityController) {
          return availabilityController.isStateLoading ?
          Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0)) :
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('set_specific_time_for_driver_availability'.tr, style: textBold),
              SizedBox(height: Dimensions.paddingSizeExtraSmall),

              Text('here_you_setup_driver_individual_active_time'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
              SizedBox(height: Dimensions.paddingSizeDefault),

              Container(
                padding: EdgeInsets.only(left: Dimensions.paddingSizeDefault, top: Dimensions.paddingSizeExtraSmall, bottom: Dimensions.paddingSizeExtraSmall),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  border: Border.all(color: Theme.of(context).disabledColor),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('same_time_for_every_day'.tr, style: textRegular),

                  Transform.scale(
                    scale: 0.7,
                    child: CupertinoSwitch(
                      value: availabilityController.isSameTimeForEveryDay,
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Theme.of(context).hintColor.withValues(alpha: 0.5),
                      onChanged: (bool isActive){
                        Get.bottomSheet(ConfirmationBottomsheetWidget(
                          title: availabilityController.isSameTimeForEveryDay ? 'set_different_schedule_for_each_day'.tr : 'apply_same_schedule_for_every_day'.tr,
                          description: availabilityController.isSameTimeForEveryDay ? 'if_disabled_you_can_set_opening_and_closing_time_separately_for_each_day'.tr : 'if_enabled_you_can_set_the_schedule_for_one_day_and_it_will_apply_to_all_days'.tr,
                          onYesPressed: (){
                            Get.back();
                            availabilityController.setIsSameTimeForEveryDay(isActive);
                            availabilityController.toggleForEveryDay(sameTimeForEveryDay: (availabilityController.isSameTimeForEveryDay));
                            Get.find<ProfileController>().getProfileInfo().then((_) {
                              availabilityController.initScheduleData(Get.find<ProfileController>().profileInfo);
                            });
                          },
                          icon: Images.warning,
                          iconColor: Theme.of(context).cardColor,
                          onNoPressed: ()=> Get.back(),
                        ));
                      },
                    ),
                  ),
                ]),
              ),
              SizedBox(height: Dimensions.paddingSizeDefault),

              Flexible(child: Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    return Column(children: [
                      DailyTimeWidget(weekDay: index, isSameTimeForEveryDay: availabilityController.isSameTimeForEveryDay),

                      index != 6 ? Divider(color: Theme.of(context).hintColor.withValues(alpha: 0.2)) : const SizedBox(),
                    ]);
                  },
                ),
              )),
            ]),
          );
        }),
      ),
    );
  }
}
