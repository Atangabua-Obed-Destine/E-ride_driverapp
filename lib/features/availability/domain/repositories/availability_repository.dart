import 'package:get/get_connect/http/src/response/response.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/availability/domain/repositories/availability_repository_interface.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/profile_model.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class AvailabilityRepository implements AvailabilityRepositoryInterface {
  final ApiClient apiClient;
  AvailabilityRepository({required this.apiClient});

  @override
  Future<Response?> addSchedule(Schedule schedule) async {
    return await apiClient.postData(AppConstants.setAvailabilitySchedule, schedule.toJson());
  }

  @override
  Future<Response> deleteSchedule(String? scheduleID) async {
    return await apiClient.postData('${AppConstants.deleteAvailabilitySchedule}/$scheduleID', {"_method": "delete"});
  }

  @override
  Future<Response> openingClosingStatus({required int sameTimeForEveryDay}) async{
    return await apiClient.putData(AppConstants.availabilitySameTime, {'same_time_for_every_day': sameTimeForEveryDay});
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int id) {
    throw UnimplementedError();
  }

  @override
  Future get(String id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset = 1}) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int id) {
    throw UnimplementedError();
  }
}
