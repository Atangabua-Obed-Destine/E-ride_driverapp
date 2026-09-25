import 'package:ride_sharing_user_app/features/profile/domain/models/profile_model.dart';
import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class AvailabilityRepositoryInterface implements RepositoryInterface {
  Future<dynamic> addSchedule(Schedule schedule);
  Future<dynamic> deleteSchedule(String? scheduleID);
  Future<dynamic> openingClosingStatus({required int sameTimeForEveryDay});
}
