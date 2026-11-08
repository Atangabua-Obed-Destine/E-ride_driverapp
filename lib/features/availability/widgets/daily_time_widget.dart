import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/confirmation_dialog_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_time_picker_widget.dart';
import 'package:ride_sharing_user_app/features/availability/controllers/availability_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/profile_model.dart';
import 'package:ride_sharing_user_app/helper/date_converter.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class DailyTimeWidget extends StatelessWidget {
  final int weekDay;
  final bool isSameTimeForEveryDay;
  const DailyTimeWidget({super.key, required this.weekDay, required this.isSameTimeForEveryDay});

  @override
  Widget build(BuildContext context) {
    List<Schedule> scheduleList = [];

    int backendWeekDay = weekDay;

    for (var schedule in Get.find<AvailabilityController>().scheduleList ?? []) {

      if (schedule.day == backendWeekDay) {
        scheduleList.add(schedule);
      }
    }

    String dayString = weekDay == 0 ? 'sunday' : weekDay == 1 ? 'monday' : weekDay == 2 ? 'tuesday'
        : weekDay == 3 ? 'wednesday' : weekDay == 4 ? 'thursday' : weekDay == 5 ? 'friday' : 'saturday';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
      child: Row(crossAxisAlignment: scheduleList.isEmpty ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        Expanded(
          flex: 1,
          child: Padding(
            padding: EdgeInsets.only(top: scheduleList.isEmpty ? 0 : Dimensions.paddingSizeSmall),
            child: Text(
              dayString.tr,
              style: textMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Theme.of(context).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeDefault),

        Expanded(
          flex: 3,
          child: scheduleList.isEmpty ? _buildOffDayRow(context, dayString, backendWeekDay) : _buildScheduleList(context, scheduleList, dayString, backendWeekDay),
        ),
      ]),
    );
  }

  Widget _buildOffDayRow(BuildContext context, String dayString, int backendWeekDay) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall,
          vertical: Dimensions.paddingSizeExtraSmall,
        ),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Text(
          'off_day'.tr,
          style: textMedium.copyWith(color: Colors.red),
        ),
      ),
      const SizedBox(width: Dimensions.paddingSizeLarge),

      if (!isSameTimeForEveryDay || (isSameTimeForEveryDay && weekDay == 0))
        _buildAddButton(context, dayString, [], backendWeekDay),
    ]);
  }

  Widget _buildScheduleList(BuildContext context, List<Schedule> scheduleList, String dayString, int backendWeekDay) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...scheduleList.asMap().entries.map((entry) {
        int idx = entry.key;
        Schedule schedule = entry.value;
        return Padding(
          padding: EdgeInsets.only(
            bottom: idx < scheduleList.length - 1 ? Dimensions.paddingSizeLarge : 0,
          ),
          child: Row(children: [

            Stack(clipBehavior: Clip.none, children: [
              Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall, right: Dimensions.paddingSizeSmall),
                child: Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  decoration: BoxDecoration(
                    color: (!isSameTimeForEveryDay || (isSameTimeForEveryDay && weekDay == 0)) ? Theme.of(context).cardColor : Theme.of(context).disabledColor.withValues(alpha: 0.1),
                    border: Border.all(color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Get.isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xffBDBDBD).withValues(alpha: 0.1),
                        blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 10),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                  child: Text(
                    '${DateConverter.convertTimeToTime(schedule.startTime!.substring(0, 5))}  -  '
                        '${DateConverter.convertTimeToTime(schedule.endTime!.substring(0, 5))}',
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                ),
              ),

              if (!isSameTimeForEveryDay || (isSameTimeForEveryDay && weekDay == 0))
                Positioned(
                  top: 0, right: 0,
                  child: InkWell(
                    onTap: () => Get.dialog(
                      GetBuilder<AvailabilityController>(builder: (availabilityController){
                        return ConfirmationDialogWidget(
                          loading: availabilityController.isLoading,
                          icon: Images.warning,
                          description: 'are_you_sure_to_delete_this_schedule'.tr,
                          onYesPressed: () async {
                            await Get.find<AvailabilityController>().deleteSchedule(schedule.id);
                            Get.find<ProfileController>().getProfileInfo().then((_) {
                              Get.find<AvailabilityController>().initScheduleData(Get.find<ProfileController>().profileInfo);
                            });
                          },
                        );
                      }),
                      barrierDismissible: false,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: Dimensions.paddingSizeDefault),

            if (idx == scheduleList.length - 1 && (!isSameTimeForEveryDay || (isSameTimeForEveryDay && weekDay == 0))) ...[
              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
              _buildAddButton(context, dayString, scheduleList, backendWeekDay),
            ],

          ]),
        );
      }),
    ]);
  }

  Widget _buildAddButton(BuildContext context, String dayString, List<Schedule> scheduleList, int backendWeekDay) {
    String? openingTime;
    String? closingTime;

    return InkWell(
      onTap: () => Get.dialog(
        Builder(builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '${'schedule_for'.tr} ${dayString.tr}',
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
              ),
              const SizedBox(height: Dimensions.paddingSizeOverLarge),

              Row(children: [
                Expanded(
                  child: CustomTimePickerWidget(
                    title: 'start_time'.tr,
                    time: openingTime,
                    onTimeChanged: (time) => openingTime = time,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                Expanded(
                  child: CustomTimePickerWidget(
                    title: 'end_time'.tr,
                    time: closingTime,
                    onTimeChanged: (time) => closingTime = time,
                  ),
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeLarge),

              GetBuilder<AvailabilityController>(builder: (availabilityController) {
                return availabilityController.isLoading ? const Center(child: CircularProgressIndicator()) : Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(dialogContext).hintColor.withValues(alpha: 0.1),
                        minimumSize: const Size(1170, 45),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                      ),
                      child: Text(
                        'cancel'.tr,
                        textAlign: TextAlign.center,
                        style: textRegular.copyWith(color: Theme.of(dialogContext).textTheme.bodyLarge!.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeLarge),

                  Expanded(
                    child: ButtonWidget(
                      buttonText: 'add'.tr,
                      height: 45,
                      onPressed: () async {
                        bool overlapped = false;
                        if (openingTime != null && closingTime != null) {
                          for (int index = 0; index < scheduleList.length; index++) {
                            if (_isUnderTime(scheduleList[index].startTime!, openingTime!, closingTime) ||
                                _isUnderTime(scheduleList[index].endTime!, openingTime!, closingTime) ||
                                _isUnderTime(openingTime!, scheduleList[index].startTime!, scheduleList[index].endTime) ||
                                _isUnderTime(closingTime!, scheduleList[index].startTime!, scheduleList[index].endTime)) {
                              overlapped = true;
                              break;
                            }
                          }
                        }
                        if (openingTime == null) {
                          showCustomSnackBar('pick_start_time'.tr);
                        } else if (closingTime == null) {
                          showCustomSnackBar('pick_end_time'.tr);
                        } else if (DateConverter.convertStringTimeToDate(openingTime!).isAfter(DateConverter.convertStringTimeToDate(closingTime!))) {
                          showCustomSnackBar('end_time_must_be_after_the_starting_time'.tr);
                        } else if (overlapped) {
                          showCustomSnackBar('this_schedule_is_overlapped'.tr);
                        } else {

                          await availabilityController.addSchedule(
                            Schedule(day: backendWeekDay, startTime: openingTime, endTime: closingTime),
                          );
                          Get.find<ProfileController>().getProfileInfo().then((_) {
                            Get.find<AvailabilityController>().initScheduleData(Get.find<ProfileController>().profileInfo);
                          });
                        }
                      },
                    ),
                  ),
                ]);
              }),
            ]),
          ),
        )),
        barrierDismissible: false,
      ),
      child: Container(
        height: 30, width: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }

  bool _isUnderTime(String time, String startTime, String? endTime) {
    return DateConverter.convertStringTimeToDate(time).isAfter(DateConverter.convertStringTimeToDate(startTime)) &&
        DateConverter.convertStringTimeToDate(time).isBefore(DateConverter.convertStringTimeToDate(endTime!));
  }
}