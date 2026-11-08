import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/help_and_support/screens/help_and_support_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/helper/extension_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class AccountPausedWarningWidget extends StatelessWidget {
  const AccountPausedWarningWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.customThemeColors.warningBackGroundColor,
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      margin: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_rounded, color: Theme.of(context).colorScheme.error, size: 20),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          Expanded(child: Text(
            '${'your_account_is_paused_by_admin_for'.tr} ${((Get.find<ProfileController>().profileInfo?.pauseDuration ?? 0)/60).toInt()} ${'hours'.tr}',
            style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall),
          )),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          InkWell(
            onTap: ()=> Get.find<ProfileController>().removeFaveVerificationSuspendWarning(),
            child: Container(
              height: 20, width: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Theme.of(context).hintColor, size: 14),
            ),
          ),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),

        RichText(text: TextSpan(
          text: '${Get.find<ProfileController>().profileInfo?.pausedReason ?? ''}${Get.find<ProfileController>().profileInfo?.pausedReason != null ? '.' : ''} ${'contact'.tr} ',
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
          children: [
            TextSpan(
              text: 'support'.tr,
              recognizer: TapGestureRecognizer()..onTap = () => Get.to(() => const HelpAndSupportScreen()),
              style: textRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).colorScheme.surfaceContainer,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
            TextSpan(text: ' ${'for_help'.tr}'),
          ],
        )),
      ]),
    );
  }
}
