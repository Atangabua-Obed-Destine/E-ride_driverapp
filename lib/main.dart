import 'package:ride_sharing_user_app/helper/chat_notification_helper.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/splash/screens/splash_screen.dart';
import 'dart:convert';
import 'package:ride_sharing_user_app/helper/notification_helper.dart';
import 'package:ride_sharing_user_app/helper/ride_request_ringer.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/helper/di_container.dart' as di;
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/localization/messages.dart';
import 'package:ride_sharing_user_app/theme/dark_theme.dart';
import 'package:ride_sharing_user_app/theme/light_theme.dart';
import 'package:ride_sharing_user_app/theme/theme_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'features/map/controllers/map_controller.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
late List<CameraDescription> cameras;

Future<void> main() async {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark, // dark text for status bar
      statusBarColor: Colors.transparent),
  );

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  cameras = await availableCameras();

  Map<String, Map<String, String>> languages = await di.init();

  final RemoteMessage? remoteMessage = await FirebaseMessaging.instance.getInitialMessage();

  await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
  await RideRequestRinger.ensureChannel(flutterLocalNotificationsPlugin);
  await ChatNotificationHelper.ensureChannel(flutterLocalNotificationsPlugin);

  // Opened by tapping the ringing request notification while the app was
  // closed: route to that request the same way an FCM tap does.
  Map<String, dynamic>? launchData = remoteMessage?.data;
  final NotificationAppLaunchDetails? launch = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  final NotificationResponse? launchResponse = launch?.notificationResponse;
  if ((launch?.didNotificationLaunchApp ?? false) && launchResponse?.actionId != RideRequestRinger.actionDismiss) {
    final String? payload = launchResponse?.payload;
    if (payload != null && payload.startsWith('{')) {
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
        if (RideRequestRinger.depositActions.contains(data['action'])) {
          // Opened from the "deposit received" alert: go to that trip.
          launchData = data;
          RideRequestRinger.cancelDepositPaid(data['ride_request_id'] as String?, flutterLocalNotificationsPlugin);
        } else if (RideRequestRinger.requestActions.contains(data['action'])) {
          launchData = data;
          RideRequestRinger.cancel(data['ride_request_id'] as String?, flutterLocalNotificationsPlugin);
        } else if (ChatNotificationHelper.isChatPush(data)) {
          launchData = data;
          ChatNotificationHelper.cancelConversation(ChatNotificationHelper.conversationOf(data), flutterLocalNotificationsPlugin);
        }
      } catch (_) {}
    }
  }

  FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);


  runApp(MyApp(languages: languages, notificationData: launchData));
}

class MyApp extends StatelessWidget {
  final Map<String, Map<String, String>> languages;
  final Map<String,dynamic>? notificationData;
  const MyApp({super.key, required this.languages, this.notificationData});


  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Get.isDarkMode? const Color(0xFF053B35) : const Color(0xFF00A08D),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark)
    );
    if(GetPlatform.isWeb) {
      Get.find<SplashController>().initSharedData();

    }

    return GetBuilder<ThemeController>(builder: (themeController) {
      return GetBuilder<LocalizationController>(builder: (localizeController) {
        return GetBuilder<SplashController>(builder: (configController) {
          return (GetPlatform.isWeb && configController.config == null) ? const SizedBox() : GetMaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: Get.key,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
            ),
            theme: themeController.darkTheme ? darkTheme : lightTheme,
            locale: localizeController.locale,
            home: SplashScreen(notificationData: notificationData),
            translations: Messages(languages: languages),
            fallbackLocale: Locale(AppConstants.languages[0].languageCode, AppConstants.languages[0].countryCode),
            defaultTransition: Transition.fade,
            transitionDuration: const Duration(milliseconds: 500),
              builder:(context,child){
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(0.95)),
                  child: SafeArea(
                    top: false,
                    child: GetBuilder<RideController>(builder: (rideController) {
                      return Stack(children: [
                          child!,
                          if(rideController.notSplashRoute)...[
                            if(!Get.find<SplashController>().isUnderMaintenance || Get.find<SplashController>().haveOngoingRides())...[
                              Positioned(top: Get.height * 0.3, right: 0,
                                  child: GestureDetector(
                                      onTap: () async{
                                        Response res = await rideController.getRideDetails(rideController.rideId ?? '1', fromHomeScreen: true);
                                        if(res.statusCode == 403 || rideController.tripDetail?.currentStatus == 'returning' || rideController.tripDetail?.currentStatus == 'returned'){
                                          Get.find<RiderMapController>().setRideCurrentState(RideState.initial);
                                        }
                                        Get.to(()=> const MapScreen());
                                      },
                                      onHorizontalDragEnd: (DragEndDetails details){
                                        _onHorizontalDrag(details);
                                        Get.to(()=> const MapScreen());
                                      },
                                      // A slim tab on the screen edge (was a wide red half
                                      // disc that covered content on every screen).
                                      child: Semantics(
                                        button: true,
                                        label: 'map'.tr,
                                        child: Container(
                                          width: 30,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1C1C1E).withValues(alpha: 0.92),
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                            border: Border(left: BorderSide(color: Theme.of(context).primaryColor, width: 2.5)),
                                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(-2, 3))],
                                          ),
                                          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                            Icon(Icons.map_rounded, color: Colors.white, size: 16),
                                            Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 14),
                                          ]),
                                        ),
                                      ),
                                  ),
                              ),
                            ]
                          ]
                        ],
                      );
                    }),
                  ),
                );
              }
          );
        });
      });
    });
  }
  void _onHorizontalDrag(DragEndDetails details) {
    if(details.primaryVelocity == 0) return;

    if (details.primaryVelocity!.compareTo(0) == -1) {
      debugPrint('dragged from left');
    } else {
      debugPrint('dragged from right');
    }
  }
}

