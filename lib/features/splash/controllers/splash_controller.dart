import 'dart:async';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashController extends GetxController implements GetxService {
  final SplashServiceInterface splashServiceInterface;
  SplashController({required this.splashServiceInterface});

  ConfigModel? _config;

  ConfigModel? get config => _config;

  /// Dial code for the configured country, falling back to Cameroon.
  ///
  /// The /configuration call can fail or still be in flight when an auth screen
  /// builds. Those screens read `config!.countryCode!` ... `.dialCode!`
  /// directly, so a null config threw during build and painted the red error
  /// screen instead of the login form. CountryCode.fromCountryCode also throws
  /// on a code it does not know, hence the try/catch.
  String get countryDialCode {
    final String? code = _config?.countryCode;
    if(code != null && code.isNotEmpty) {
      try {
        final String? dial = CountryCode.fromCountryCode(code).dialCode;
        if(dial != null && dial.isNotEmpty) {
          return dial;
        }
      } catch (_) {
        // unknown country code in the config; fall through to the default
      }
    }
    return '+237';
  }

  /// OTP resend countdown, falling back to 60s when there is no config yet.
  int get otpResendTime => _config?.otpResendTime ?? 60;

  /// Whether drivers may register themselves. Defaults to false rather than
  /// throwing when the config has not arrived.
  bool get selfRegistrationEnabled => _config?.selfRegistration ?? false;

  /// True only when the backend has the DRIVER app in maintenance mode.
  ///
  /// Reads false when there is no config, so a failed /configuration call
  /// cannot crash the maintenance checks that run on the cold-start path and
  /// on every notification.
  bool get isUnderMaintenance {
    final MaintenanceMode? mode = _config?.maintenanceMode;
    return mode != null &&
        mode.maintenanceStatus == 1 &&
        mode.selectedMaintenanceSystem?.driverApp == 1;
  }

  bool isShowToolTips = true;
  bool loading = false;
  Future<bool> getConfigData({bool reload= true}) async {
    loading = true;
    Response response = await splashServiceInterface.getConfigData();
    bool isSuccess = false;
    if(response.statusCode == 200) {
      isSuccess = true;
      loading = false;
      _config = ConfigModel.fromJson(response.body);
    }else {
      loading = false;
      ApiChecker.checkApi(response);
    }
    if(reload){
      update();
    }
    return isSuccess;
  }

  Future<bool> initSharedData() {
    return splashServiceInterface.initSharedData();
  }



  Future<bool> removeSharedData() {
    return splashServiceInterface.removeSharedData();
  }

  final Uri params = Uri(
    scheme: 'mailto',
    path: '',
    query: 'subject=support Feedback&body=',
  );

  String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  Future<void> sendMailOrCall(String url, bool isMail) async {
    if (!await launchUrl(Uri.parse(isMail? params.toString() :url))) {
      throw 'Could not launch $url';
    }
  }


  String? _pusherConnectionStatus;
  String? get pusherConnectionStatus => _pusherConnectionStatus;

  void setPusherStatus(String? connection){
    _pusherConnectionStatus = connection;
  }


  bool haveOngoingRides() {
    return splashServiceInterface.haveOngoingRides();
  }

  void saveOngoingRides(bool value) {
    return splashServiceInterface.saveOngoingRides(value);
  }

  void addLastReFoundData(Map<String,dynamic>? data) => splashServiceInterface.addLastReFoundData(data);
  Map<String, dynamic>? getLastRefundData() => splashServiceInterface.getLastRefundData();

  void hideToolTips(){
    isShowToolTips = false;
  }

}