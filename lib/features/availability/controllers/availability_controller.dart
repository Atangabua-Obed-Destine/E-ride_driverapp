import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/availability/domain/services/availability_service_interface.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/profile_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

class AvailabilityController extends GetxController implements GetxService{
  final AvailabilityServiceInterface availabilityServiceInterface;
  AvailabilityController({required this.availabilityServiceInterface});

  bool isLoading = false;
  bool _isSameTimeForEveryDay = false;
  bool get isSameTimeForEveryDay => _isSameTimeForEveryDay;
  List<Schedule>? _scheduleList;
  List<Schedule>? get scheduleList => _scheduleList;

  void initScheduleData(ProfileInfo? profileModel, {isUpdate = true}){
    _scheduleList = [];
    _isSameTimeForEveryDay = profileModel?.availabilitySchedule?.sameTimeForEveryDay ?? false;
    _scheduleList?.addAll(profileModel?.availabilitySchedule?.schedule ?? []);
    if(isUpdate){
      update();
    }
  }

  void setIsSameTimeForEveryDay(bool value) {
    _isSameTimeForEveryDay = value;
    update();
  }

  Future<void> addSchedule(Schedule schedule) async {
    schedule.startTime = '${schedule.startTime!}:00';
    schedule.endTime = '${schedule.endTime!}:00';
    isLoading = true;
    update();
    Response response = await availabilityServiceInterface.addSchedule(schedule);
    String? scheduleID = response.body['data']['id'];
    if(scheduleID != null) {
      schedule.id = scheduleID;
      _scheduleList!.add(schedule);
      Get.back();
      showCustomSnackBar('schedule_added_successfully'.tr, isError: false);
    }
    isLoading = false;
    update();
  }

  Future<void> deleteSchedule(String? scheduleID) async {
    isLoading = true;
    update();
    Response response = await availabilityServiceInterface.deleteSchedule(scheduleID);
    if(response.statusCode == 200) {
      _scheduleList!.removeWhere((schedule) => schedule.id == scheduleID);
      Get.back();
      showCustomSnackBar('schedule_removed_successfully'.tr, isError: false);
    }else{
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
  }

  bool isStateLoading= false;
  Future<void> toggleForEveryDay({ required bool sameTimeForEveryDay}) async {
    isStateLoading = true;
    update();

    Response response = await availabilityServiceInterface.openingClosingStatus(
      sameTimeForEveryDay: _isSameTimeForEveryDay ? 1 : 0,
    );

    if(Get.isDialogOpen!){
      Get.back();
    }

    if(response.statusCode == 200) {

    }else {
      ApiChecker.checkApi(response);
    }

    isStateLoading = false;
    update();
  }



}
