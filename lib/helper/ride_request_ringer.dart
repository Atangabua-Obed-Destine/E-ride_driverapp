import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Rings the driver's phone for a new ride or parcel request, like an
/// incoming call.
///
/// Two paths, one sound:
///  * App closed, backgrounded or phone locked: the backend sends new requests
///    as data-only pushes, the background handler calls [show], and Android
///    shows a call-style notification that loops the ringtone (FLAG_INSISTENT)
///    until the driver acts, for at most [ringFor].
///  * App open: the request already opens on screen, so [startInAppRing] loops
///    the same ringtone with vibration until [stopInAppRing] or [ringFor].
///
/// Safe to use from the background isolate: no GetX, no BuildContext.
class RideRequestRinger {
  static const String channelId = 'ride_request_ring';
  static const String channelName = 'Ride requests';
  static const String actionView = 'view_request';
  static const String actionDismiss = 'dismiss_request';
  static const Duration ringFor = Duration(seconds: 30);

  /// "The customer paid the booking deposit": a shorter ring, so it is not
  /// mistaken for a new request, with a Go to pickup button.
  static const Set<String> depositActions = {'deposit_paid'};
  static const String actionGoToPickup = 'go_to_pickup';
  static const Duration depositRingFor = Duration(seconds: 10);
  static const String depositNoticeChannelId = 'deposit_notice';
  static const String depositNoticeChannelName = 'Trip updates (silent)';

  static const Set<String> requestActions = {'new_ride_request', 'new_parcel_request'};
  static const Set<String> goneActions = {
    'another_driver_assigned', 'customer_canceled_trip', 'customer_canceled_the_trip', 'trip_canceled',
  };

  /// Android's FLAG_INSISTENT: the sound repeats until the notification is
  /// cancelled or acted on.
  static const int _flagInsistent = 4;
  static final Int64List _vibration = Int64List.fromList([0, 900, 600, 900, 600, 900]);

  static int idFor(String? rideRequestId) =>
      (rideRequestId == null || rideRequestId.isEmpty) ? 7100 : (rideRequestId.hashCode & 0x3fffffff);

  static Future<void> ensureChannel(FlutterLocalNotificationsPlugin fln) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final AndroidFlutterLocalNotificationsPlugin? android =
        fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // The channel every other push names ("hexaride"). It was never created,
    // so Android filed those pushes under a silent fallback channel.
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'hexaride',
      'E-Ride Driver',
      description: 'Trip updates, messages and account notices.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    ));

    await android?.createNotificationChannel(AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Rings when a customer requests a ride or a parcel delivery.',
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('ride_request_ring'),
          enableVibration: true,
          vibrationPattern: _vibration,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        ));

    // Where a ring that was not answered settles, without sound.
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      depositNoticeChannelId,
      depositNoticeChannelName,
      description: 'Trip updates that already rang, kept until opened.',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    ));
  }

  /// Shows the ringing request alert for push [data] (the FCM data map).
  static Future<void> show(Map<String, dynamic> data, FlutterLocalNotificationsPlugin fln) async {
    final bool parcel = data['action'] == 'new_parcel_request' || data['type'] == 'parcel';
    final String title = (data['title'] as String?)?.isNotEmpty == true
        ? data['title'] as String
        : (parcel ? 'New parcel request' : 'New ride request');

    final String pickup = (data['pickup_address'] as String?) ?? '';
    final String fare = (data['estimated_fare'] as String?) ?? '';
    final List<String> parts = [if (pickup.isNotEmpty) pickup, if (fare.isNotEmpty) fare];
    final String body = parts.isNotEmpty ? parts.join('  ·  ') : ((data['body'] as String?) ?? '');

    await ensureChannel(fln);
    await fln.show(
      id: idFor(data['ride_request_id'] as String?),
      title: title,
      body: body,
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('ride_request_ring'),
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          enableVibration: true,
          vibrationPattern: _vibration,
          additionalFlags: Int32List.fromList([_flagInsistent]),
          timeoutAfter: ringFor.inMilliseconds,
          ongoing: true,
          autoCancel: true,
          icon: 'notification_icon',
          styleInformation: BigTextStyleInformation(body),
          actions: const [
            AndroidNotificationAction(actionView, 'View request', showsUserInterface: true, cancelNotification: true),
            AndroidNotificationAction(actionDismiss, 'Dismiss', cancelNotification: true),
          ],
        ),
      ),
    );
  }

  static Future<void> cancel(String? rideRequestId, FlutterLocalNotificationsPlugin fln) async {
    await fln.cancel(id: idFor(rideRequestId));
  }

  static int depositIdFor(String? rideRequestId) => idFor(rideRequestId) ^ 0x1;

  /// Rings briefly for a paid booking deposit (app closed or in the background).
  static Future<void> showDepositPaid(Map<String, dynamic> data, FlutterLocalNotificationsPlugin fln) async {
    final String title = (data['title'] as String?)?.isNotEmpty == true ? data['title'] as String : 'Deposit received';
    final String body = (data['body'] as String?) ?? '';
    final String button = (data['button'] as String?)?.isNotEmpty == true ? data['button'] as String : 'Go to pickup';
    await ensureChannel(fln);
    await fln.show(
      id: depositIdFor(data['ride_request_id'] as String?),
      title: title,
      body: body,
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('ride_request_ring'),
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          enableVibration: true,
          vibrationPattern: _vibration,
          additionalFlags: Int32List.fromList([_flagInsistent]),
          autoCancel: true,
          icon: 'notification_icon',
          styleInformation: BigTextStyleInformation(body),
          actions: [
            AndroidNotificationAction(actionGoToPickup, button, showsUserInterface: true, cancelNotification: true),
          ],
        ),
      ),
    );

    // Ring for a few seconds only. If the driver has not opened it, the
    // ringing alert is replaced by a silent one that stays in the shade.
    await Future.delayed(depositRingFor);
    final AndroidFlutterLocalNotificationsPlugin? android =
        fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final int id = depositIdFor(data['ride_request_id'] as String?);
    final active = await android?.getActiveNotifications() ?? const [];
    if (!active.any((n) => n.id == id)) return;
    await fln.cancel(id: id);
    await fln.show(
      id: id,
      title: title,
      body: body,
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          depositNoticeChannelId,
          depositNoticeChannelName,
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: false,
          autoCancel: true,
          icon: 'notification_icon',
          styleInformation: BigTextStyleInformation(body),
          actions: [
            AndroidNotificationAction(actionGoToPickup, button, showsUserInterface: true, cancelNotification: true),
          ],
        ),
      ),
    );
  }

  static Future<void> cancelDepositPaid(String? rideRequestId, FlutterLocalNotificationsPlugin fln) async {
    await fln.cancel(id: depositIdFor(rideRequestId));
  }

  // ---------------------------------------------------------------------------
  // In-app ring (app in the foreground).
  // ---------------------------------------------------------------------------

  static AudioPlayer? _player;
  static Timer? _stopTimer;
  static String? ringingFor;

  static Future<void> startInAppRing({String? rideRequestId, Duration? duration}) async {
    ringingFor = rideRequestId;
    _stopTimer?.cancel();
    _stopTimer = Timer(duration ?? ringFor, stopInAppRing);
    try {
      // A fresh player per ring, configured before the source is set: reusing
      // a player or changing its mode mid-prepare can leave Android's
      // MediaPlayer in an invalid state (MEDIA_ERROR -38).
      await _player?.dispose();
      final AudioPlayer player = AudioPlayer();
      _player = player;
      await player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.notificationRingtone,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource('ride_request_ring.wav'));
      await player.resume();
    } catch (_) {
      // Sound is best effort; the request is already on screen.
    }
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 900, 600, 900, 600, 900]);
      }
    } catch (_) {}
  }

  static Future<void> stopInAppRing({String? rideRequestId}) async {
    if (rideRequestId != null && ringingFor != null && rideRequestId != ringingFor) return;
    ringingFor = null;
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      Vibration.cancel();
    } catch (_) {}
  }
}
