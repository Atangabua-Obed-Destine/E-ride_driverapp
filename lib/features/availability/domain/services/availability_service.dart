import 'package:ride_sharing_user_app/features/availability/domain/repositories/availability_repository_interface.dart';
import 'package:ride_sharing_user_app/features/availability/domain/services/availability_service_interface.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/profile_model.dart';
import 'package:get/get_connect/http/src/response/response.dart';

class AvailabilityService implements AvailabilityServiceInterface {
  final AvailabilityRepositoryInterface availabilityRepositoryInterface;
  AvailabilityService({required this.availabilityRepositoryInterface});

  @override
  Future<Response?> addSchedule(Schedule schedule) async {
    return await availabilityRepositoryInterface.addSchedule(schedule);
  }

  @override
  Future<Response> deleteSchedule(String? scheduleID) async {
    return await availabilityRepositoryInterface.deleteSchedule(scheduleID);
  }

  @override
  Future<Response> openingClosingStatus({required int sameTimeForEveryDay}) async {
    return await availabilityRepositoryInterface.openingClosingStatus(sameTimeForEveryDay: sameTimeForEveryDay);
  }
}
