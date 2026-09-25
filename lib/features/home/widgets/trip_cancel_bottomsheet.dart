import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/help_and_support/screens/help_and_support_screen.dart';
import 'package:ride_sharing_user_app/helper/date_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class TripCancelBottomSheet extends StatelessWidget {
  final String tripId;
  final String cancelledAt;
  final String reason;

  const TripCancelBottomSheet({
    super.key,
    required this.tripId,
    required this.cancelledAt,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 5, width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),

            Text('${'trip'.tr} #$tripId', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge), textAlign: TextAlign.center),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),

            Text(
              DateConverter.tripDetailsShowFormat(cancelledAt),
              style: textRegular.copyWith(color: Theme.of(context).colorScheme.secondaryFixedDim, fontSize: Dimensions.fontSizeSmall),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            Text('cancelled'.tr, style: textSemiBold.copyWith(color: Theme.of(context).colorScheme.error, fontSize: Dimensions.fontSizeDefault), textAlign: TextAlign.center),
            const SizedBox(height: Dimensions.paddingSizeDefault),

            Text(
              reason,
              style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),

            InkWell(
              onTap: () {
                Get.back();
                Get.to(() => const HelpAndSupportScreen());
              },
              child: Text('contact_for_support'.tr, style: textMedium.copyWith(
                color: Theme.of(context).colorScheme.surfaceContainer,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.surfaceContainer,
                fontSize: Dimensions.fontSizeDefault,
              )),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
          ]),
        ),
      ),
    );
  }
}
