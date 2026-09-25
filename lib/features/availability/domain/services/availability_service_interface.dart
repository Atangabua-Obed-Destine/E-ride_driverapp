import 'package:ride_sharing_user_app/features/profile/domain/models/profile_model.dart';

abstract class AvailabilityServiceInterface {

  Future<dynamic> addSchedule(Schedule schedule);
  Future<dynamic> deleteSchedule(String? scheduleID);
  Future<dynamic> openingClosingStatus({required int sameTimeForEveryDay});
}
