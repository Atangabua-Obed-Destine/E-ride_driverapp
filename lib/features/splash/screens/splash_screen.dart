import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/features/wallet/controllers/wallet_controller.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';

class SplashScreen extends StatefulWidget {
  final Map<String, dynamic>? notificationData;
  const SplashScreen({super.key, this.notificationData});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  StreamSubscription<List<ConnectivityResult>>? _onConnectivityChanged;

  /// One-shot entrance: map, route, logo, badge.
  late final AnimationController _intro;

  /// Loops while the splash is up, driving the loading bar. The splash waits on
  /// the configuration call, so there is no sensible fixed duration.
  late final AnimationController _pulse;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _badgeFade;
  late final Animation<double> _badgeSlide;
  late final Animation<double> _chromeFade;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    if (!GetPlatform.isIOS) {
      _checkConnectivity();
    }

    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

    _logoFade = CurvedAnimation(parent: _intro, curve: const Interval(0.14, 0.52, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.14, 0.62, curve: Curves.easeOutCubic)),
    );
    _badgeFade = CurvedAnimation(parent: _intro, curve: const Interval(0.42, 0.78, curve: Curves.easeOut));
    _badgeSlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic)),
    );
    _chromeFade = CurvedAnimation(parent: _intro, curve: const Interval(0.60, 1.0, curve: Curves.easeOut));

    // Unchanged boot sequence. Everything below this line is the original flow.
    Get.find<SplashController>().initSharedData();
    Get.find<TripController>().rideCancellationReasonList();
    Get.find<TripController>().parcelCancellationReasonList();
    Get.find<AuthController>().remainingTime();
    Get.find<WalletController>().getPaymentGetWayList();
    LoginHelper().handleIncomingLinks(widget.notificationData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS "remove animations" accessibility setting: show the final
    // composition immediately rather than animating into it.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce == _reduceMotion && (_intro.isAnimating || _intro.value > 0)) return;
    _reduceMotion = reduce;
    if (reduce) {
      _intro.value = 1;
      _pulse.stop();
    } else {
      _intro.forward();
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _onConnectivityChanged?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _checkConnectivity() {
    bool isFirst = true;
    _onConnectivityChanged = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      bool isConnected = result.contains(ConnectivityResult.wifi) || result.contains(ConnectivityResult.mobile);
      if ((isFirst && !isConnected) || !isFirst && context.mounted) {
        ScaffoldMessenger.of(Get.context!).removeCurrentSnackBar();
        ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar();
        ScaffoldMessenger.of(Get.context!).showSnackBar(SnackBar(
          backgroundColor: isConnected ? Colors.green : Colors.red,
          duration: Duration(seconds: isConnected ? 3 : 6000),
          content: Text(
            isConnected ? 'connected'.tr : 'no_connection'.tr,
            textAlign: TextAlign.center,
          ),
        ));

        if (isConnected) {
          LoginHelper().handleIncomingLinks(widget.notificationData);
        }
      }
      isFirst = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The canvas is dark in both themes, so the status bar icons must be
      // light regardless of the device's light/dark setting.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: kSplashInk,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: kSplashInk,
        body: Stack(fit: StackFit.expand, children: [

          SplashBackdrop(accent: accent),

          // Same route motif as the customer app, drawn the other way down the
          // screen: for a driver the story is work arriving, not a trip leaving.
          CustomPaint(
            painter: RouteMapPainter(animation: _intro, accent: accent, reversed: true),
          ),

          const SplashLogoScrim(),

          SafeArea(
            child: Column(children: [
              const Spacer(flex: 6),

              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: _LogoGlow(accent: accent),
                ),
              ),

              const SizedBox(height: 24),

              AnimatedBuilder(
                animation: _intro,
                builder: (_, child) => Opacity(
                  opacity: _badgeFade.value,
                  child: Transform.translate(offset: Offset(0, _badgeSlide.value), child: child),
                ),
                child: _DriverBadge(accent: accent),
              ),

              const Spacer(flex: 5),

              FadeTransition(
                opacity: _chromeFade,
                child: SplashLoadingBar(
                  animation: _pulse,
                  accent: accent,
                  animate: !_reduceMotion,
                ),
              ),

              const SizedBox(height: 34),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The lockup with a soft brand glow behind it.
///
/// Uses the dark-background variant of the logo: the shipped logo.png mixes
/// near-black and white elements, so on a dark canvas its mark disappears.
/// logo_on_dark.png is the same artwork with the greyscale parts mapped to
/// white, leaving the brand red untouched.
class _LogoGlow extends StatelessWidget {
  final Color accent;
  const _LogoGlow({required this.accent});

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.58, 260.0);
    return SizedBox(
      width: width * 1.9,
      height: width * 1.9,
      child: Stack(alignment: Alignment.center, children: [
        // Radial rather than a BoxShadow: a shadow would trace the image's
        // rectangular bounds and read as a glowing box behind the logo.
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accent.withValues(alpha: 0.34), Colors.transparent],
              stops: const [0.0, 0.72],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Image.asset(Images.logoOnDark, width: width, fit: BoxFit.contain),
      ]),
    );
  }
}

/// What tells the two apps apart at a glance, on the splash and in screenshots.
class _DriverBadge extends StatelessWidget {
  final Color accent;
  const _DriverBadge({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Text(
          'DRIVER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.4,
            color: Color.lerp(accent, Colors.white, 0.55),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          // The company's own tagline, straight from the logo artwork. Not a
          // translatable UI string: it is part of the brand.
          'EMMY\'S RELIABLE INTEGRATED\nDELIVERY & EXPRESS',
          textAlign: TextAlign.center,
          // Decorative brand text: allow a little growth for readability, but
          // not so much that it pushes the lockup off a small screen.
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
          style: TextStyle(
            fontSize: 10,
            height: 1.7,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: Colors.white.withValues(alpha: 0.50),
          ),
        ),
      ),
    ]);
  }
}
