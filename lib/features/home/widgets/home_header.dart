import 'package:ride_sharing_user_app/common_widgets/unread_badge.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_inbox_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_header_motif.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The pinned home header: splash ink with the route motif, the menu
/// button, a time-of-day greeting with the driver's first name, and an
/// online / offline status pill. The identity card below straddles its
/// bottom edge.
class HomeHeader extends StatelessWidget {
  /// Total height including the status bar; HomeScreen reserves this much
  /// at the top of its scroll view and overlaps the identity card on it.
  /// Measured from the real status bar: a fixed height let the card cover
  /// the greeting on phones with a tall status bar or large display size.
  static double heightOf(BuildContext context) => MediaQuery.paddingOf(context).top + 92;

  /// Top of the identity card: just under the greeting row.
  static double cardTopOf(BuildContext context) => MediaQuery.paddingOf(context).top + 60;

  final VoidCallback onMenuTap;
  const HomeHeader({super.key, required this.onMenuTap});

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'good_morning'.tr;
    if (hour < 17) return 'good_afternoon'.tr;
    if (hour < 20) return 'good_evening'.tr;
    return 'good_night'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: heightOf(context),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kSplashInkLow, kSplashInk]),
        ),
        child: Stack(children: [
          Positioned.fill(
            top: MediaQuery.paddingOf(context).top,
            child: HomeHeaderMotif(accent: accent),
          ),

          SafeArea(
            bottom: false,
            child: GetBuilder<ProfileController>(builder: (profileController) {
              final bool online = profileController.isOnline == "1";
              final String name = profileController.profileInfo?.firstName ?? '';
              return Padding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeSmall, 6, Dimensions.paddingSizeDefault, 0),
                child: Row(children: [
                  IconButton(
                    tooltip: 'profile'.tr,
                    onPressed: onMenuTap,
                    icon: GetBuilder<ChatInboxController>(builder: (inbox) => UnreadBadge(
                      count: inbox.totalUnread,
                      dot: true,
                      offset: const Offset(-2, -2),
                      borderColor: const Color(0xFF1C1C1E),
                      child: Image.asset(Images.menuIcon, color: Colors.white, width: 22),
                    )),
                  ),
                  const SizedBox(width: 2),

                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      name.isEmpty ? _greeting() : '${_greeting()}, $name',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ready_when_you_are'.tr,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ])),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online ? const Color(0xFF1DB954) : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        online ? 'online'.tr : 'offline'.tr,
                        style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white),
                      ),
                    ]),
                  ),
                ]),
              );
            }),
          ),
        ]),
      ),
    );
  }
}
