import 'package:flutter/services.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/common_widgets/trip_arrival_card.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/helper/ride_request_ringer.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ride_sharing_user_app/common_widgets/expandable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/map/controllers/otp_time_count_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/services/ride_service_interface.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/final_fare_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/on_going_trip_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/parcel_list_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/pending_ride_request_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/remaining_distance_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/trip/screens/payment_received_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';



class RideController extends GetxController implements GetxService{
  final RideServiceInterface rideServiceInterface;
  RideController({required this.rideServiceInterface});
  int _orderStatusSelectedIndex = 0;
  int get orderStatusSelectedIndex => _orderStatusSelectedIndex;
  bool isLoading = false;
  bool isPinVerificationLoading = false;
  String? _rideId;
  String? get rideId => _rideId;
  List<String>? _thumbnailPaths;
  List<String>? get thumbnailPaths => _thumbnailPaths;
  double totalParcelWeight = 0;
  int totalParcelCount = 0;
  TripDetail? tripDetail;
  JustTheController justTheController = JustTheController();

  bool isShowDriverArrivalTooltip = false;

  void setRideId(String id){
    _rideId = id;
  }


  void setOrderStatusTypeIndex(int index){
    _orderStatusSelectedIndex = index;
    update();
  }



  Future<Response> bidding(String tripId, String amount) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.bidding(tripId, amount);
    if (response.statusCode == 200) {
      Get.back();
      isLoading = false;
     showCustomSnackBar('bid_submitted_successfully'.tr, isError: false);
     getPendingRideRequestList(1);
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }


  bool notSplashRoute= false;
  void updateRoute(bool showHideIcon, {bool notify = false}){
    notSplashRoute = showHideIcon;
    if(notify){
      update();
    }

  }

  Future<Response> getRideDetails(String tripId, {bool fromHomeScreen = false}) async {
    isLoading = true;
    _thumbnailPaths = null;
    if (kDebugMode) {
      print('details api call-====> $tripId');
    }
    Response response = await rideServiceInterface.getRideDetails(tripId);
    if (response.statusCode == 200) {
      tripDetail = TripDetailsModel.fromJson(response.body).data!;
      // A trip can come back without a route line; the map skips an empty one.
      polyline = tripDetail!.encodedPolyline ?? '';
      isLoading = false;
      // Keep the trip chat live (and its unread badge) while the trip runs.
      Get.find<ChatInboxController>().syncTrip(tripDetail!.id, tripDetail!.currentStatus);
      _syncTripProgressTimer();

      List<Attachments> attachments = tripDetail?.parcelRefund?.attachments ?? [];
      _thumbnailPaths = List.filled(attachments.length, '');

      Future.forEach(attachments, (element) async{
        if(element.file?.contains('.mp4') ?? false){
          String? path = await generateThumbnail(element.file!);
          _thumbnailPaths?[tripDetail!.parcelRefund!.attachments!.indexOf(element)] =  path ?? '';

          update();
        }
      });

    }else if(response.statusCode == 403){
      isLoading = false;
    }else{
      isLoading = false;
      fromHomeScreen ? null : ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<Response> uploadScreenShots(String tripId, XFile file) async {
    Response response = await rideServiceInterface.uploadScreenShots(tripId, file);
    if (response.statusCode == 200) {
    }
    update();
    return response;
  }


  String polyline = '';

  Future<Response> getRideDetailBeforeAccept(String tripId) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.getRideDetailBeforeAccept(tripId);
    if (response.statusCode == 200) {
      tripDetail = TripDetailsModel.fromJson(response.body).data!;
      isLoading = false;
      // A trip can come back without a route line; the map skips an empty one.
      polyline = tripDetail!.encodedPolyline ?? '';
      Get.find<RideController>().remainingDistance(tripId,mapBound: true);
      Get.find<RiderMapController>().getPickupToDestinationPolyline();
      if (kDebugMode) {
        print('polyline is ====> $polyline');
      }
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }

    update();
    return response;
  }


  List<TripDetail>? ongoingTrip, lastRideDetails;
  List<TripDetail>? get ongoingRideList => ongoingTrip;

  /// The home screen knows the running trip from these lists without loading
  /// its details, so the trip chat (and its unread badge) starts from here too.
  void _watchChatOf(List<TripDetail>? trips) {
    for (final TripDetail trip in trips ?? const <TripDetail>[]) {
      Get.find<ChatInboxController>().syncTrip(trip.id, trip.currentStatus);
    }
  }

  Future<Response> ongoingTripList() async {
    Response response = await rideServiceInterface.ongoingTripList();
    if (response.statusCode == 200) {
      ongoingTrip = [];
      if(response.body['data'] != null){
        ongoingTrip!.addAll(OngoingTripModel.fromJson(response.body).data!);
      }
      _watchChatOf(ongoingTrip);

    }else{
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<void> getLastRideDetail() async {
    Response response = await rideServiceInterface.lastRideDetail();
    if (response.statusCode == 200) {
      lastRideDetails = [];
      if(response.body['data'] != null){
        lastRideDetails!.addAll(OngoingTripModel.fromJson(response.body).data!);
      }
      _watchChatOf(lastRideDetails);

    }else{
      ApiChecker.checkApi(response);
    }
    update();
  }

  bool accepting = false;
  String? onPressedTripId ;
  Future<Response> tripAcceptOrRejected(String tripId, String action, String type, String parcelWeight, {bool showSuccess = true}) async {
    // The driver answered, so the request stops ringing.
    RideRequestRinger.stopInAppRing();
    onPressedTripId = tripId;

      accepting = true;
      update();
    Response response = await rideServiceInterface.tripAcceptOrReject(tripId, action);
    if (response.statusCode == 200) {

      accepting = false;
      Get.find<RiderMapController>().getPickupToDestinationPolyline();
      if(action == 'rejected'){
        await rideServiceInterface.ignoreMessage(tripId);
        showCustomSnackBar('trip_is_rejected'.tr, isError: false);

      }else{
        if(type == 'parcel'){
          totalParcelCount ++;
          totalParcelWeight += double.parse(parcelWeight);
        }

        if(showSuccess){
          showCustomSnackBar('trip_is_accepted'.tr, isError: false);
        }

        Future.delayed(const Duration(seconds: 15)).then((_){
          if((Get.find<SplashController>().config?.maximumParcelRequestAcceptLimitStatus ?? false) && type == 'parcel'){
            if(totalParcelCount ==  Get.find<SplashController>().config?.maximumParcelRequestAcceptLimit){
              showCustomSnackBar(
                  isError: true,
                  'booking_acceptance_limit_reached'.tr,
                  subMessage: 'kindly_complete_the_delivery_of_the_ongoing'.tr,
                  seconds: 5
              );
            }
          }

          if(
          type == 'parcel' &&
              (totalParcelWeight > (Get.find<ProfileController>().profileInfo?.vehicle?.parcelWeightCapacity ?? 0)) &&
              (Get.find<ProfileController>().profileInfo?.vehicle?.parcelWeightCapacity != null)
          ){
            showCustomSnackBar(
                isError: true,
                'parcel_weight_limit_exceeded'.tr,
                subMessage: 'parcel_weight_exceeds_the_set_limit'.tr,
                seconds: 5
            );
          }
        });

        Get.find<OtpTimeCountController>().initialCounter();

        // The customer may owe a booking deposit before the driver sets off:
        // read it, and hear the moment it is paid.
        PusherHelper().customerDepositPaid(tripId);
        getRideDetails(tripId);

      }

    }else{

      accepting = false;
    }
    accepting = false;
    onPressedTripId = null;
    update();
    return response;
  }


  String _verificationCode = '';
  String _otp = '';
  String get otp => _otp;
  String get verificationCode => _verificationCode;

  void updateVerificationCode(String query) {
    _verificationCode = query;
    if(_verificationCode.isNotEmpty){
      _otp = _verificationCode;
    }
    update();
  }

  void clearVerificationCode() {
    _verificationCode = '';
    update();
  }


  Uint8List? imageFile;

  Future<Response> matchOtp(String tripId, String otp, List<MultipartBody> proofImages) async {
    isPinVerificationLoading = true;
    update();
    if (kDebugMode) {
      print('otp and id ===> $tripId/$otp');
    }
    Response response = await rideServiceInterface.matchOtp(tripId, otp, proofImages);
    if (response.statusCode == 200) {

      if(tripDetail?.type != 'parcel'){
        Get.find<SafetyAlertController>().checkDriverNeedSafety();
      }

      clearVerificationCode();
      // Sender pays at pickup, unless it was already paid in the app (food &
      // shop orders, digitally paid parcels): then just start delivering.
      if(tripDetail!.type! == 'parcel' &&  tripDetail?.parcelInformation?.payer == 'sender' && tripDetail?.paymentStatus != AppConstants.paid){
        Get.find<RiderMapController>().setRideCurrentState(RideState.ongoing);
        getFinalFare(tripId).then((value) {
          if(value.statusCode == 200){
            Get.to(()=> const PaymentReceivedScreen(fromParcel: true,));
          }
        });
      }else{
        remainingDistance(tripDetail!.id!,mapBound: true);
        getRideDetails(tripDetail!.id!);
        Get.find<RiderMapController>().setRideCurrentState(RideState.ongoing);
      }

      if(otp.isEmpty){
        showCustomSnackBar('trip_started'.tr, isError: false);
      }else{
        showCustomSnackBar('otp_verified_successfully'.tr, isError: false);
      }

      isPinVerificationLoading = false;
      Future.delayed(const Duration(seconds: 12)).then((value) async{
        imageFile = await Get.find<RiderMapController>().mapController!.takeSnapshot();
        if(imageFile!= null) {
          uploadScreenShots(tripDetail!.id!, XFile.fromData(imageFile!));
        }
      });

      PusherHelper().tripCancelAfterOngoing(tripDetail!.id!);
      PusherHelper().tripPaymentSuccessful(tripDetail!.id!);

    }else{
      showCustomSnackBar('${response.body['errors'][0]['error_code']}',subMessage: '${response.body['errors'][0]['message']}');
      isPinVerificationLoading = false;
    }
    update();
    return response;
  }



  String myDriveMode = '';
  RemainingDistanceModel? matchedMode;
  List<RemainingDistanceModel> remainingDistanceItem = [];


  String? _arrivedMarkedFor;
  Timer? _tripProgressTimer;
  String? _tripProgressFor;

  /// While a trip is ongoing, refresh the distance to the drop-off every
  /// 20 s so the arrival card stays live (it used to update only on taps).
  void _syncTripProgressTimer() {
    final bool live = tripDetail?.currentStatus == 'ongoing' && tripDetail?.id != null;
    if (!live) {
      _tripProgressTimer?.cancel();
      _tripProgressTimer = null;
      _tripProgressFor = null;
      return;
    }
    if (_tripProgressTimer != null && _tripProgressFor == tripDetail!.id) return;
    _tripProgressTimer?.cancel();
    final String id = tripDetail!.id!;
    _tripProgressFor = id;
    _tripProgressTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (tripDetail?.id == id && tripDetail?.currentStatus == 'ongoing') {
        remainingDistance(id);
      } else {
        _tripProgressTimer?.cancel();
        _tripProgressTimer = null;
        _tripProgressFor = null;
      }
    });
  }

  Future<Response> remainingDistance(String tripId,{bool mapBound = false}) async {
    myDriveMode = Get.find<ProfileController>().profileInfo!.vehicle!.category!.type!;
    isLoading = true;
    Response response = await rideServiceInterface.remainDistance(tripId);
     List<String> status = ['accepted','ongoing','outForPickup'];
    if (response.statusCode == 200) {
      isLoading = false;
      if(status.contains(Get.find<RiderMapController>().currentRideState.name)){
        Get.find<RiderMapController>().getDriverToPickupOrDestinationPolyline(response.body[0]['encoded_polyline'],mapBound: mapBound);
      }

      remainingDistanceItem = [];
      response.body.forEach((distance) {
        remainingDistanceItem.add(RemainingDistanceModel.fromJson(distance));

      });
      if(remainingDistanceItem.isNotEmpty){
        matchedMode =  remainingDistanceItem[0];
      }

      if(matchedMode != null && (matchedMode!.distance! * 1000) <= 100 && tripDetail != null && tripDetail!.currentStatus == 'pending' ){
        arrivalPickupPoint(tripId);
      }

      // Arrived at the drop-off: tell the server once per trip, with a buzz
      // and a sound. (This used to repeat on every refresh while inside the
      // admin "completion radius", which can be kilometres wide.)
      if(tripDetail != null && tripDetail!.currentStatus == 'ongoing' && !tripDetail!.isPaused! && matchedMode != null && matchedMode!.isPicked! &&
          TripArrivalCard.stageFor(matchedMode!.distance) == TripArrivalStage.arrived && _arrivedMarkedFor != tripId){
        _arrivedMarkedFor = tripId;
        arrivalDestination(tripId, "destination");
        getRideDetails(tripId);
        HapticFeedback.heavyImpact();
        AudioPlayer audio = AudioPlayer();
        audio.play(AssetSource('notification.wav'));
      }

    }else{
      isLoading = false;
    }
    update();
    return response;
  }

  bool isStatusUpdating = false;

  Future<Response> tripStatusUpdate(String status,String id, String message, String cancellationCause, List<MultipartBody> proofImages, {String? dateTime}) async {
    isLoading = true;
    isStatusUpdating = true;
    update();
    Response response = await rideServiceInterface.tripStatusUpdate(status, id,cancellationCause,dateTime ?? '', proofImages);

    if (response.statusCode == 200) {
      Get.find<TripController>().othersCancellationController.clear();
      Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
      showCustomSnackBar(message.tr, isError: false);
      Get.find<OtpTimeCountController>().clearAllImages();
      isLoading = false;
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    isStatusUpdating = false;
    update();
    return response;
  }


  PendingRideRequestModel? pendingRideRequestModel;
  PendingRideRequestModel? get getPendingRideRequestModel => pendingRideRequestModel;

  Future<Response> getPendingRideRequestList(int offset, {int limit = 10, bool isUpdate = false}) async {
    isLoading = true;
    if(isUpdate){
      update();
    }
    Response response = await rideServiceInterface.getPendingRideRequestList(offset, limit: limit);
    if (response.statusCode == 200) {
      pendingRideRequestModel?.data = [];
      pendingRideRequestModel?.totalSize = 0;
      pendingRideRequestModel?.offset = '1';
      if(response.body['data'] != null && response.body['data'] != ''){
        if(offset == 1 ){
          pendingRideRequestModel = PendingRideRequestModel.fromJson(response.body);
        }else{
          pendingRideRequestModel!.totalSize =  PendingRideRequestModel.fromJson(response.body).totalSize;
          pendingRideRequestModel!.offset =  PendingRideRequestModel.fromJson(response.body).offset;
          pendingRideRequestModel!.data!.addAll(PendingRideRequestModel.fromJson(response.body).data!);
        }
      }

      isLoading = false;
    }
    else{
      pendingRideRequestModel?.data = [];
      pendingRideRequestModel?.totalSize = 0;
      pendingRideRequestModel?.offset = '1';
      isLoading = false;
      if(!(Get.find<ProfileController>().profileInfo?.vehicle == null  && Get.find<ProfileController>().isFirstTimeShowBottomSheet)){
       // ApiChecker.checkApi(response);
      }
    }
    update();
    return response;
  }


  FinalFare? finalFare;
  Future<Response> getFinalFare(String tripId) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.getFinalFare(tripId);
    if (response.statusCode == 200 ) {
      Get.find<RiderMapController>().initializeData();
      if(response.body['data'] != null){
        finalFare = FinalFareModel.fromJson(response.body).data!;

      }
      isLoading = false;
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-d');
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  DateFormat get dateFormat => _dateFormat;

  void selectDate(String type, BuildContext context){
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),

      lastDate: DateTime(2030),
    ).then((date) {
      if (type == 'start'){
        _startDate = date!;
      }else{
        _endDate = date!;
      }

      update();
    });
  }



  Future<Response> arrivalPickupPoint(String tripId) async {
    isLoading = true;
    if (kDebugMode) {
      print('details api call-====> $tripId');
    }
    Response response = await rideServiceInterface.arrivalPickupPoint(tripId);
    if (response.statusCode == 200) {
      isLoading = false;
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<Response> arrivalDestination(String tripId, String type) async {
    Response response = await rideServiceInterface.arrivalDestination(tripId, type);
    if (response.statusCode == 200) {
      if (kDebugMode) {
        print("===Arrived destination aria===");
      }
    }else{

      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<Response> waitingForCustomer (String tripId, String waitingStatus) async {
    isLoading = true;
    Response response = await rideServiceInterface.waitingForCustomer(tripId, waitingStatus);
    if (response.statusCode == 200) {
      getRideDetails(tripId);
      isLoading = false;
      showCustomSnackBar('trip_status_updated_successfully'.tr, isError: false);
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<void> focusOnBottomSheet(GlobalKey<ExpandableBottomSheetState> key) async {
    if(key.currentState?.expansionStatus == ExpansionStatus.expanded) {
      // ignore: invalid_use_of_protected_member
      key.currentState?.reassemble();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    key.currentState?.expand();
  }

  ParcelListModel? parcelListModel;
  Future<Response> getOngoingParcelList() async {
    isLoading = true;
    Response? response = await rideServiceInterface.getOnGoingParcelList(1);
    if(response!.statusCode == 200 ){
      isLoading = false;
      if(response.body['data'] != null){
        parcelListModel = ParcelListModel.fromJson(response.body);
      }
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
    _calculateTotalParcelWeight();
    return response;
  }

  void _calculateTotalParcelWeight(){
    totalParcelWeight = 0;
    totalParcelCount = 0;
    if(parcelListModel != null){
      totalParcelCount = parcelListModel!.data!.length;
      for(int i = 0 ; i< parcelListModel!.data!.length ; i++){
        totalParcelWeight += double.parse(parcelListModel?.data?[i].parcelInformation?.weight ?? '0');
      }
    }
  }

  ParcelListModel? unpaidParcelListModel;
  Future<Response> getUnpaidParcelList() async {
    isLoading = true;
    Response? response = await rideServiceInterface.getUnpaidParcelList(1);
    if(response!.statusCode == 200 ){
      isLoading = false;
      if(response.body['data'] != null){
        unpaidParcelListModel = ParcelListModel.fromJson(response.body);
      }
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
    return response;
  }

  Future<String?> generateThumbnail(String filePath) async {
    final directory = await getTemporaryDirectory();

    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: filePath, // Replace with your video URL
      thumbnailPath: directory.path,
      imageFormat: ImageFormat.PNG,  // You can use JPEG or WEBP too
      maxHeight: 100,                 // Specify the height of the thumbnail
      maxWidth: 200,                 // Specify the Width of the thumbnail
      quality: 1,                    // Quality of the thumbnail
    );

    return thumbnailPath;
  }

  String loadingId = '';
  Future<Response> checkDriverReachedDestination(String tripId) async {
    isLoading = true;
    loadingId = tripId;
    update();
    Response response = await rideServiceInterface.remainDistance(tripId);
    if (response.statusCode == 200) {
      getRideDetails(tripId);
      isLoading = false;
      Get.find<RiderMapController>().checkDriverReachedDestination(response.body[0]['encoded_polyline']);

      remainingDistanceItem = [];
      response.body.forEach((distance) {
        remainingDistanceItem.add(RemainingDistanceModel.fromJson(distance));
      });

      if(remainingDistanceItem.isNotEmpty){
        matchedMode =  remainingDistanceItem[0];
      }

    }else{
      isLoading = false;
    }
    update();
    return response;
  }

  void showSafetyAlertTooltip(){
    justTheController.showTooltip();
  }

  /// E-Ride Move: "We couldn't agree" on the price at the pickup.
  bool movingNoAgreement = false;
  Future<bool> noAgreement(String tripId) async {
    if (movingNoAgreement) return false;
    movingNoAgreement = true;
    update();
    final Response response = await rideServiceInterface.moveNoAgreement(tripId);
    movingNoAgreement = false;
    update();
    if (response.statusCode == 200) return true;
    final body = response.body;
    final errors = body is Map ? body['errors'] : null;
    showCustomSnackBar(errors is List && errors.isNotEmpty && errors.first is Map ? '${errors.first['message']}' : 'something_went_wrong'.tr);
    return false;
  }

  Future<Response> startForPickup(String tripId) async {
    isPinVerificationLoading = true;
    update();

    Response response = await rideServiceInterface.startForPickup(tripId);
    if (response.statusCode == 200) {
        getRideDetails(tripDetail!.id!);
        Get.find<RiderMapController>().setRideCurrentState(RideState.outForPickup);

      // if(otp.isEmpty){
      //   showCustomSnackBar('trip_started'.tr, isError: false);
      // }else{
      //   showCustomSnackBar('otp_verified_successfully'.tr, isError: false);
      // }

      isPinVerificationLoading = false;

    }else{
      isPinVerificationLoading = false;
    }
    update();
    return response;
  }

  void toggleShowDriverNearByTooltip(bool action){
    isShowDriverArrivalTooltip = action;
    update();
  }

}