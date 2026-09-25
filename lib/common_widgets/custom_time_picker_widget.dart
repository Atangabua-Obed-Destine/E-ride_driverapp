import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/helper/date_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class CustomTimePickerWidget extends StatefulWidget {
  final String title;
  final String? time;
  final Function(String?) onTimeChanged;
  const CustomTimePickerWidget({super.key, required this.title, required this.time, required this.onTimeChanged});

  @override
  State<CustomTimePickerWidget> createState() => _CustomTimePickerWidgetState();
}

class _CustomTimePickerWidgetState extends State<CustomTimePickerWidget> {
  String? _myTime;

  @override
  void initState() {
    super.initState();

    _myTime = widget.time;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      InkWell(
        onTap: () async {
          TimeOfDay? time = await showTimePicker(
            context: context, initialTime: TimeOfDay(hour: DateTime.now().hour, minute: DateTime.now().minute),
            builder: (BuildContext context, Widget? child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  alwaysUse24HourFormat: false,
                ),
                child: child!,
              );
            },
          );
          if(time != null) {
            setState(() {
              _myTime = DateConverter.convertDateTimeToString(DateTime(DateTime.now().year, 1, 1, time.hour, time.minute));
            });
            widget.onTimeChanged(_myTime);
          }
        },
        child: Stack(clipBehavior: Clip.none, children: [

          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(color: Theme.of(context).hintColor, width: 0.5),
            ),
            padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault, right: Dimensions.paddingSizeSmall),
            child: Row( children: [
              Icon(Icons.access_time_filled, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: Dimensions.paddingSizeExtraSmall),


              Text(
                _myTime != null ? DateConverter.convertTimeToTime(_myTime!) : ' - -  : - - ', style: textRegular.copyWith(color: _myTime != null ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).hintColor, fontSize: Dimensions.fontSizeDefault),
              ),

            ]),
          ),

          Positioned(
            left: 10, top: -Get.height * 0.03,
            child: Container(
              //decoration: BoxDecoration(color: Theme.of(context).cardColor),
              padding: const EdgeInsets.all(5),
              child: Text(widget.title, style: textRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall)),
            ),
          ),

        ]),
      ),

    ]);
  }
}