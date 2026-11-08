import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One "My activity" tile: the icon in a soft tile of its own colour, the
/// label, and the hours as a big figure with a small unit.
class MyActivityCardWidget extends StatelessWidget {
  final int index;
  final String title;
  final String icon;
  final int value;
  final Color color;

  const MyActivityCardWidget({super.key,  required this.index, required this.title, required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    int hour = 0, min =0;
    if(value>= 60){
      hour = (value/60).floor();
    }
    min = ((value % 60)).floor();
    final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Padding(
      padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSize),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.14)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment : CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: SizedBox(width: 16, height: 16, child: Image.asset(icon, color: color))),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: Text(
              title.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textMedium.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall),
            )),
          ]),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('$hour:${min.toString().padLeft(2, '0')}', style: textBold.copyWith(color: text, fontSize: 22)),
            const SizedBox(width: 4),
            Text('hr', style: textMedium.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall)),
          ]),
        ]),
      ),
    );
  }
}
