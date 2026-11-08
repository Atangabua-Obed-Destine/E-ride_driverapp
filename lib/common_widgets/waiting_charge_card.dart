import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Paid waiting on a running trip, as the server reports it in the trip's
/// `waiting` field. Same file in both apps.
class TripWaiting {
  final bool isPaused;
  final DateTime? pausedSince;
  final double idleMinutes;
  final double feePerMin;
  final double freeMinutes;

  /// Server clock minus this phone's clock, so the live timer matches the
  /// minutes the server will charge even if the phone's clock is off.
  final Duration clockOffset;

  const TripWaiting({
    required this.isPaused,
    required this.pausedSince,
    required this.idleMinutes,
    required this.feePerMin,
    required this.freeMinutes,
    this.clockOffset = Duration.zero,
  });

  factory TripWaiting.fromJson(Map<String, dynamic> json) {
    final DateTime? serverTime = DateTime.tryParse('${json['server_time'] ?? ''}');
    return TripWaiting(
      isPaused: json['is_paused'] == true || json['is_paused'] == 1 || json['is_paused'] == '1',
      pausedSince: DateTime.tryParse('${json['paused_since'] ?? ''}'),
      idleMinutes: double.tryParse('${json['idle_minutes']}') ?? 0,
      feePerMin: double.tryParse('${json['fee_per_min']}') ?? 0,
      freeMinutes: double.tryParse('${json['free_minutes']}') ?? 0,
      clockOffset: serverTime == null ? Duration.zero : serverTime.difference(DateTime.now()),
    );
  }

  /// Length of the pause that is running now.
  Duration currentPause() {
    if (!isPaused || pausedSince == null) return Duration.zero;
    final Duration d = DateTime.now().add(clockOffset).difference(pausedSince!);
    return d.isNegative ? Duration.zero : d;
  }

  /// All waiting on this trip so far, in minutes.
  double totalMinutes() => idleMinutes + currentPause().inMilliseconds / 60000.0;

  /// What the waiting adds to the fare so far (the server's formula).
  double chargeSoFar() => math.max(totalMinutes() - freeMinutes, 0) * feePerMin;

  bool get worthShowing => isPaused || idleMinutes > 0;
}

/// Live "waiting" card: a ticking timer while the trip is paused, the charge
/// so far and the per-minute rate. After a resume it shrinks to one line
/// with the total that will be added to the fare.
class WaitingChargeCard extends StatefulWidget {
  final TripWaiting waiting;

  /// True in the driver app (wording), false in the customer app.
  final bool forDriver;
  final String Function(double amount) formatPrice;
  final EdgeInsetsGeometry margin;

  const WaitingChargeCard({super.key, required this.waiting, required this.forDriver, required this.formatPrice, this.margin = const EdgeInsets.symmetric(horizontal: 16)});

  @override
  State<WaitingChargeCard> createState() => _WaitingChargeCardState();
}

class _WaitingChargeCardState extends State<WaitingChargeCard> with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant WaitingChargeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.waiting.isPaused) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _ticker?.cancel();
      _ticker = null;
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  static String _clock(Duration d) {
    final int h = d.inHours;
    final String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final TripWaiting w = widget.waiting;
    final ThemeData theme = Theme.of(context);
    const Color amber = Color(0xFFF5A524);
    final bool charged = w.feePerMin > 0;
    final double total = w.totalMinutes();
    final bool inFreeTime = charged && w.freeMinutes > 0 && total < w.freeMinutes;
    final String rate = '${widget.formatPrice(w.feePerMin)}/${'min_short'.tr}';

    if (!w.isPaused) {
      // Resumed: one quiet line with what has been added.
      return Container(
        margin: widget.margin,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.hourglass_bottom_rounded, size: 18, color: amber),
          const SizedBox(width: 10),
          Expanded(child: Text(
            charged
                ? '${'waiting_time'.tr}: ${total.toStringAsFixed(total < 10 ? 1 : 0)} ${'min_short'.tr} · +${widget.formatPrice(w.chargeSoFar())}'
                : '${'waiting_time'.tr}: ${total.toStringAsFixed(total < 10 ? 1 : 0)} ${'min_short'.tr}',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13, fontWeight: FontWeight.w600),
          )),
        ]),
      );
    }

    return Semantics(
      liveRegion: true,
      label: widget.forDriver ? 'trip_paused_waiting_charged'.tr : 'driver_is_waiting_for_you'.tr,
      child: Container(
        margin: widget.margin,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: amber.withValues(alpha: 0.55)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: amber.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: const Icon(Icons.pause_rounded, color: amber, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.forDriver ? 'trip_paused'.tr : 'driver_is_waiting_for_you'.tr,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                charged
                    ? (inFreeTime
                        ? '${'first_minutes_free'.trParams({'min': w.freeMinutes.toStringAsFixed(0)})} · $rate'
                        : '${'waiting_is_charged'.tr} · $rate')
                    : 'no_waiting_charge_here'.tr,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
            ])),
            Text(
              _clock(w.currentPause()),
              style: const TextStyle(color: amber, fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ]),
          if (charged) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 10),
            Row(children: [
              Text('waiting_charge_so_far'.tr, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const Spacer(),
              Text(
                '+${widget.formatPrice(w.chargeSoFar())}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
