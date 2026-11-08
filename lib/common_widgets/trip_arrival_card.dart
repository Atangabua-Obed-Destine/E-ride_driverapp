import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum TripArrivalStage { enRoute, almostThere, arrived }

/// Always-on "how close are we to the drop-off" indicator for a running trip.
/// Same file in both apps. Distances are the server's road distance from the
/// driver's live location to the destination.
class TripArrivalCard extends StatelessWidget {
  /// Within this road distance the trip counts as arrived.
  static const double arrivedKm = 0.15;

  /// Within this road distance the trip is "almost there".
  static const double nearKm = 0.6;

  final double? remainingKm;
  final double? totalKm;
  final String? eta;
  final bool forDriver;
  final EdgeInsetsGeometry margin;

  const TripArrivalCard({super.key, required this.remainingKm, this.totalKm, this.eta, required this.forDriver, this.margin = const EdgeInsets.symmetric(horizontal: 16)});

  static TripArrivalStage stageFor(double? km) {
    if (km == null) return TripArrivalStage.enRoute;
    if (km <= arrivedKm) return TripArrivalStage.arrived;
    if (km <= nearKm) return TripArrivalStage.almostThere;
    return TripArrivalStage.enRoute;
  }

  static String formatDistance(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final TripArrivalStage stage = stageFor(remainingKm);
    const Color green = Color(0xFF1DB954);
    const Color amber = Color(0xFFF5A524);
    final Color brand = theme.primaryColor;

    final Color accent = switch (stage) {
      TripArrivalStage.arrived => green,
      TripArrivalStage.almostThere => amber,
      TripArrivalStage.enRoute => brand,
    };
    final IconData icon = switch (stage) {
      TripArrivalStage.arrived => Icons.where_to_vote_rounded,
      TripArrivalStage.almostThere => Icons.near_me_rounded,
      TripArrivalStage.enRoute => Icons.flag_rounded,
    };

    final String title;
    final String subtitle;
    switch (stage) {
      case TripArrivalStage.arrived:
        title = forDriver ? 'arrived_at_drop_off'.tr : 'you_have_arrived'.tr;
        subtitle = forDriver ? 'arrived_driver_hint'.tr : 'arrived_customer_hint'.tr;
      case TripArrivalStage.almostThere:
        title = 'almost_there'.tr;
        subtitle = '${formatDistance(remainingKm!)} ${'to_drop_off'.tr}';
      case TripArrivalStage.enRoute:
        title = remainingKm == null ? 'heading_to_drop_off'.tr : '${formatDistance(remainingKm!)} ${'to_drop_off'.tr}';
        subtitle = (eta ?? '').isNotEmpty ? '${'about'.tr} $eta' : 'on_the_way'.tr;
    }

    double? progress;
    if (remainingKm != null && (totalKm ?? 0) > 0) {
      progress = (1 - remainingKm! / totalKm!).clamp(0.0, 1.0);
    }
    if (stage == TripArrivalStage.arrived) progress = 1;

    return Semantics(
      liveRegion: true,
      label: '$title. $subtitle',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: margin,
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: stage == TripArrivalStage.arrived
              ? green.withValues(alpha: dark ? 0.22 : 0.12)
              : (dark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: stage == TripArrivalStage.enRoute ? 0.18 : 0.55)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  title,
                  key: ValueKey<String>(title),
                  style: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF1C1C1E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: theme.hintColor, fontSize: 12.5)),
            ])),
          ]),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
