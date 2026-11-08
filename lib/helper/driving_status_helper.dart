import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/confirmation_bottomsheet_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/loader_widget.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/home_screen_helper.dart';
import 'package:ride_sharing_user_app/util/images.dart';

/// Going online / offline, as the status card's switch always did it:
/// refuse while a ride or parcel is in progress, confirm before going
/// offline, show the loader around the API call, refresh the daily log, and
/// trigger face verification after going online when the admin asks for it.
///
/// Lives here so the status card and the GO button on the nav dock share one
/// implementation.
class DrivingStatusHelper {
  static Future<void> toggle() async {
    final ProfileController profileController = Get.find<ProfileController>();
    final bool online = profileController.isOnline == "1";
    final bool goingOnline = !online;

    int ridingCount = Get.find<RideController>().ongoingRideList?.length ?? 0;
    int parcelCount = Get.find<RideController>().parcelListModel?.totalSize ?? 0;
    if((ridingCount + parcelCount) > 0){
      showCustomSnackBar('sorry_you_canot_go_offline'.tr);
      return;
    }

    if(online){
      Get.bottomSheet(ConfirmationBottomsheetWidget(
        iconColor: Get.theme.cardColor,
        title: 'do_you_want_to_turn_off_the_status'.tr,
        description: 'if_you_turn_off_the_status_you_wouldnot_get_any_trips'.tr,
        icon: Images.errorMessageIcon,
        onYesPressed: () async{
          Get.back();
          Get.dialog(const LoaderWidget(), barrierDismissible: false);
          await profileController.profileOnlineOffline(goingOnline).then((value){
            profileController.getDailyLog();
            if(value.statusCode == 200){
              Get.back();
            }
          });
        },
        onNoPressed: ()=> Get.back(),
      ));
    }else{
      Get.dialog(const LoaderWidget(), barrierDismissible: false);
      await profileController.profileOnlineOffline(goingOnline).then((value){
        if(value.statusCode == 200){
          profileController.getDailyLog();
          Get.back();
          if((Get.find<SplashController>().config?.chooseVerificationWhenToTrigger == "before_going_online") && (Get.find<SplashController>().config?.verifyDriverIdentity ?? false)){
            HomeScreenHelper().faceVerificationSheet();
          }
        }
      });
    }
  }
}
