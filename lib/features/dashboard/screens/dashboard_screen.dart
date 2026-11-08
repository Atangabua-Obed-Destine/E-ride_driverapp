import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/dashboard/widgets/eride_nav_dock.dart';
import 'package:ride_sharing_user_app/features/wallet/controllers/wallet_controller.dart';
import 'package:ride_sharing_user_app/helper/driving_status_helper.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/domain/models/navigation_model.dart';
import 'package:ride_sharing_user_app/features/home/screens/home_screen.dart';
import 'package:ride_sharing_user_app/features/notification/screens/notification_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_screen.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';



class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageStorageBucket bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    Get.find<RideController>().updateRoute(true);
    final List<NavigationModel> item = [
      NavigationModel(name: 'home'.tr, activeIcon: Images.homeActive, inactiveIcon: Images.homeOutline, screen: const HomeMenu()),
      NavigationModel(name: 'activity'.tr, activeIcon: Images.activityActive, inactiveIcon: Images.activityOutline, screen: const TripHistoryMenu()),
      NavigationModel(name: 'notification'.tr, activeIcon: Images.notificationActive, inactiveIcon: Images.notificationOutline, screen: const NotificationMenu()),
      NavigationModel(name: 'wallet'.tr, activeIcon: Images.moneyActive, inactiveIcon: Images.moneyOutline, screen: const WalletScreenMenu()),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, val) async {
        // Only a back the route refused is ours to handle.
        if (didPop) return;
        if (Get.find<BottomMenuController>().currentTab != 0) {
          if(Get.find<ProfileController>().toggle){
            Get.find<ProfileController>().toggleDrawer();
            Get.find<BottomMenuController>().setTabIndex(0);
          }else{
            if(Get.find<BottomMenuController>().currentTab == 3){
              if(Get.find<WalletController>().walletTypeIndex == 0){
                Get.find<BottomMenuController>().setTabIndex(0);
              }else{
                Get.find<WalletController>().moveToPreviousProfileType();
              }
            }else{
              Get.find<BottomMenuController>().setTabIndex(0);
            }
          }
          return;
        } else {
          if(Get.find<ProfileController>().toggle){
            Get.find<ProfileController>().toggleDrawer();
          }else{
            Get.find<BottomMenuController>().exitApp();
          }
          return;
        }
      },
      child: GetBuilder<BottomMenuController>(builder: (menuController) {
        return SafeArea(
          top: false,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(children: [
              PageStorage(bucket: bucket, child: item[menuController.currentTab].screen),

              Positioned(
                left: 0, right: 0, bottom: 0,
                child: GetBuilder<ProfileController>(builder: (profileController) {
                  // The zoom drawer lives inside the Home tab, under this dock, so
                  // slide the dock away while the drawer is open.
                  final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
                  return AnimatedSlide(
                    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    offset: profileController.toggle ? const Offset(0, 1.4) : Offset.zero,
                    child: ERideNavDock(
                    items: item,
                    currentIndex: menuController.currentTab,
                    online: profileController.isOnline == "1",
                    onSelect: (index) {
                      if (index == menuController.currentTab) return;
                      HapticFeedback.selectionClick();
                      menuController.setTabIndex(index);
                    },
                    onGoTap: () {
                      HapticFeedback.mediumImpact();
                      DrivingStatusHelper.toggle();
                    },
                  ),
                  );
                }),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
