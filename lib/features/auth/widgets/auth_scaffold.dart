import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Shell for the driver sign-in steps: the splash canvas with the finished
/// route drawn across it (reversed, as on the driver splash), the E-Ride
/// lockup with the DRIVER badge, a white title and subtitle, and a white card
/// that holds the form.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final bool showLockup;
  final VoidCallback? onBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = true,
    this.showLockup = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kSplashInk,
        body: Stack(children: [
          Positioned.fill(child: SplashBackdrop(accent: accent)),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.45,
                child: CustomPaint(
                  painter: RouteMapPainter(animation: const AlwaysStoppedAnimation<double>(1.0), accent: accent, reversed: true),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, Dimensions.paddingSizeLarge, 0),
                child: Row(children: [
                  if (showBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: Dimensions.paddingSizeDefault, height: 48),
                  const Spacer(),
                  if (!showLockup) Image.asset(Images.brandMarkOnDark, height: 26, fit: BoxFit.contain),
                ]),
              ),

              if (showLockup) ...[
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Center(child: Column(children: [
                  Image.asset(Images.logoOnDark, height: 64, fit: BoxFit.contain),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: accent.withValues(alpha: 0.7)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'driver'.tr.toUpperCase(),
                      style: textSemiBold.copyWith(fontSize: 10, letterSpacing: 2.5, color: Colors.white),
                    ),
                  ),
                ])),
                const SizedBox(height: Dimensions.paddingSizeLarge),
              ],

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeLarge, Dimensions.paddingSizeSmall, Dimensions.paddingSizeLarge, 0,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: textBold.copyWith(fontSize: 26, color: Colors.white)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeLarge, Dimensions.paddingSizeExtraLarge, Dimensions.paddingSizeLarge, Dimensions.paddingSizeExtraLarge,
                    ),
                    child: child,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
