import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:ride_sharing_user_app/helper/driving_status_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';

/// The driver identity card that straddles the seam between the dark home
/// header and the body: avatar in a ring (green while online), name,
/// verification and level, and the online / offline switch. The switch runs
/// the same flow as the GO button on the nav dock (DrivingStatusHelper).
class ProfileStatusCardWidget extends StatefulWidget {
  final ProfileController profileController;
  const ProfileStatusCardWidget({super.key, required this.profileController});

  @override
  State<ProfileStatusCardWidget> createState() => _ProfileStatusCardWidgetState();
}

class _ProfileStatusCardWidgetState extends State<ProfileStatusCardWidget> {
  JustTheController tooltipController = JustTheController();
  JustTheController faceTooltipController = JustTheController();
  @override
  void initState() {
    WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_){
      if(widget.profileController.isCashInHandHoldAccount){
        tooltipController.showTooltip();
      }
      if(widget.profileController.profileInfo?.isVerified ?? false){
        faceTooltipController.showTooltip();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profileController.profileInfo;
    final Color accent = Theme.of(context).primaryColor;
    final Color hint = Theme.of(context).hintColor;
    final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final bool online = widget.profileController.isOnline == "1";
    final bool verified = profile?.isVerified ?? false;
    final bool showLevel = Get.find<SplashController>().config?.levelStatus ?? false;
    final String? imageBase = Get.find<SplashController>().config?.imageBaseUrl?.profileImage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: hint.withValues(alpha: Get.isDarkMode ? 0.25 : 0.12)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.45 : 0.16), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: profile != null && profile.firstName != null ?
        Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: online ? const Color(0xFF1DB954) : accent, width: 2),
              ),
              child: ClipOval(
                child: ImageWidget(
                  width: 48, height: 48,
                  image: '$imageBase/${profile.profileImage}',
                ),
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeDefault),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(
                  '${profile.firstName ?? ''} ${profile.lastName ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: text),
                )),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                if(widget.profileController.isCashInHandHoldAccount)...[
                  JustTheTooltip(
                    backgroundColor: Get.isDarkMode ? accent : Theme.of(context).textTheme.bodyMedium!.color,
                    controller: tooltipController,
                    preferredDirection: AxisDirection.down,
                    tailLength: 10,
                    tailBaseWidth: 20,
                    content: Container(
                      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                      child: Text('on_hold'.tr, style: textRegular.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault)),
                    ),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.error),
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.block, color: Theme.of(context).cardColor, size: Dimensions.paddingSizeSmall),
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                ],

                JustTheTooltip(
                  backgroundColor: Get.isDarkMode ? accent : Theme.of(context).textTheme.bodyMedium!.color,
                  controller: faceTooltipController,
                  preferredDirection: AxisDirection.down,
                  tailLength: 10,
                  tailBaseWidth: 20,
                  content: Container(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    child: Text(
                      verified ? 'verified'.tr : 'unverified'.tr,
                      style: textRegular.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault),
                    ),
                  ),
                  child: Image.asset(verified ? Images.faceVerifiedIcon : Images.nonVerificationIcon, height: 16, width: 16),
                ),
              ]),
              const SizedBox(height: 5),

              Row(children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: online ? const Color(0xFF1DB954) : hint),
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(
                  online ? 'you_are_online'.tr : 'you_are_offline'.tr,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: online ? const Color(0xFF1DB954) : hint),
                )),
                if (showLevel && profile.level?.name != null) ...[
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(profile.level!.name!, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: accent)),
                  ),
                ],
              ]),
            ])),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            _OnlineSwitch(online: online, onTap: DrivingStatusHelper.toggle),
          ]),
        ) :
        const SizedBox(),
      ),
    );
  }
}

/// A pill switch: grey with the knob left while offline, green with the knob
/// right while online.
class _OnlineSwitch extends StatelessWidget {
  final bool online;
  final VoidCallback onTap;
  const _OnlineSwitch({required this.online, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Duration d = reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final Color track = online ? const Color(0xFF1DB954) : Theme.of(context).hintColor.withValues(alpha: 0.35);

    return Semantics(
      toggled: online,
      label: online ? 'online'.tr : 'offline'.tr,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: d,
          curve: Curves.easeOut,
          width: 58, height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(16)),
          child: AnimatedAlign(
            duration: d,
            curve: Curves.easeOut,
            alignment: online ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Icon(
                online ? Icons.check_rounded : Icons.power_settings_new_rounded,
                size: 16,
                color: online ? const Color(0xFF1DB954) : Theme.of(context).hintColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
