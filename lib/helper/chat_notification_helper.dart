import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat message notifications, shown like a messaging app: one notification
/// per conversation, the sender's name, the actual text, the last few lines,
/// and "Reply" / "Mark as read" right from the notification shade.
///
/// The backend sends chat pushes to Android as data-only messages so this
/// class can build them. It never touches GetX or a BuildContext, so the
/// background push handler and the notification-action isolate can use it.
class ChatNotificationHelper {
  static const String channelId = 'chat_messages';
  static const String actionReply = 'chat_reply';
  static const String actionMarkRead = 'chat_mark_read';
  static const String chatAction = 'new_message';
  static const int _maxLines = 7;

  /// Same id for the same conversation in every isolate and every run.
  static int idFor(String conversationId) {
    int hash = 0x811c9dc5;
    for (final int unit in conversationId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 300000 + (hash % 1000000);
  }

  static bool isChatPush(Map<String, dynamic> data) => data['action'] == chatAction;

  static String conversationOf(Map<String, dynamic> data) =>
      (data['channel_id'] as String?)?.isNotEmpty == true ? data['channel_id'] as String : (data['type'] as String? ?? '');

  static Future<void> ensureChannel(FlutterLocalNotificationsPlugin fln) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final String lang = await _language();
    await fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          channelId,
          lang == 'fr' ? 'Messages' : 'Messages',
          description: lang == 'fr' ? 'Messages de votre chauffeur ou client pendant une course.' : 'Messages from your driver or rider during a trip.',
          importance: Importance.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification'),
          enableVibration: true,
        ));
  }

  /// Shows (or extends) the conversation notification for chat push [data].
  /// Returns false when there is nothing to show.
  static Future<bool> show(Map<String, dynamic> data, FlutterLocalNotificationsPlugin fln) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    if ((data['status'] as String?) == '0') return false; // switched off in the admin panel
    final String conversation = conversationOf(data);
    if (conversation.isEmpty) return false;

    final String sender = _sender(data);
    final String text = _body(data);
    await _post(
      fln: fln,
      data: data,
      line: Message(text, _sentAt(data), Person(name: sender, key: data['sender_id'] as String? ?? sender, important: true)),
      alert: true,
    );
    return true;
  }

  /// Adds the user's own reply (or a "not sent" note) to the conversation
  /// notification, without sound.
  static Future<void> _appendMine(Map<String, dynamic> data, FlutterLocalNotificationsPlugin fln, String text, {bool failed = false}) async {
    final String lang = await _language();
    final String shown = failed ? (lang == 'fr' ? '$text  (non envoyé, ouvrez E-Ride)' : '$text  (not sent, open E-Ride)') : text;
    await _post(fln: fln, data: data, line: Message(shown, DateTime.now(), null), alert: false);
  }

  static Future<void> _post({
    required FlutterLocalNotificationsPlugin fln,
    required Map<String, dynamic> data,
    required Message line,
    required bool alert,
  }) async {
    final String conversation = conversationOf(data);
    final int id = idFor(conversation);
    final String lang = await _language();
    final AndroidFlutterLocalNotificationsPlugin? android =
        fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await ensureChannel(fln);

    // Earlier lines come from the notification already on screen, so a
    // dismissed conversation starts fresh.
    List<Message> lines = <Message>[];
    try {
      final MessagingStyleInformation? existing = await android?.getActiveNotificationMessagingStyle(id: id);
      lines = List<Message>.from(existing?.messages ?? const <Message>[]);
    } catch (_) {}
    lines.add(line);
    if (lines.length > _maxLines) lines = lines.sublist(lines.length - _maxLines);

    final Person me = Person(name: lang == 'fr' ? 'Vous' : 'You', key: 'me');
    final String sender = _sender(data);
    final bool canReply = (data['ride_request_id'] as String?)?.isNotEmpty == true;

    await fln.show(
      id: id,
      title: sender,
      body: line.text,
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          icon: 'notification_icon',
          color: const Color(0xFFE02020),
          playSound: alert,
          sound: const RawResourceAndroidNotificationSound('notification'),
          onlyAlertOnce: !alert,
          silent: !alert,
          autoCancel: true,
          styleInformation: MessagingStyleInformation(
            me,
            conversationTitle: (data['trip_ref'] as String?)?.isNotEmpty == true
                ? '${lang == 'fr' ? 'Course' : 'Trip'} #${data['trip_ref']}'
                : null,
            groupConversation: false,
            messages: lines,
          ),
          actions: [
            if (canReply)
              AndroidNotificationAction(
                actionReply,
                lang == 'fr' ? 'Répondre' : 'Reply',
                inputs: [AndroidNotificationActionInput(label: lang == 'fr' ? 'Votre message' : 'Your message')],
                allowGeneratedReplies: true,
                showsUserInterface: false,
                cancelNotification: false,
              ),
            AndroidNotificationAction(
              actionMarkRead,
              lang == 'fr' ? 'Marquer comme lu' : 'Mark as read',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> cancelConversation(String conversationId, FlutterLocalNotificationsPlugin fln) async {
    if (conversationId.isEmpty) return;
    try {
      await fln.cancel(id: idFor(conversationId));
    } catch (_) {}
  }

  /// Handles "Reply" and "Mark as read". Returns true when [response] was a
  /// chat action (so the caller should not also route it).
  static Future<bool> handleAction(NotificationResponse response, FlutterLocalNotificationsPlugin fln) async {
    if (response.actionId != actionReply && response.actionId != actionMarkRead) return false;
    final Map<String, dynamic>? data = decode(response.payload);
    if (data == null || !isChatPush(data)) return false;
    final String conversation = conversationOf(data);

    if (response.actionId == actionMarkRead) {
      await cancelConversation(conversation, fln);
      await _put(AppConstants.chatMarkRead, {'channel_id': conversation});
      return true;
    }

    final String text = (response.input ?? '').trim();
    if (text.isEmpty) return true;
    final bool sent = await _put(AppConstants.sendMessage, {
      'message': text,
      'channel_id': conversation,
      'trip_id': data['ride_request_id'] as String? ?? '',
    });
    await _appendMine(data, fln, text, failed: !sent);
    return true;
  }

  static Map<String, dynamic>? decode(String? payload) {
    if (payload == null || !payload.startsWith('{')) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------

  static String _sender(Map<String, dynamic> data) {
    final String name = ((data['sender_name'] as String?) ?? (data['user_name'] as String?) ?? '').trim();
    return name.isNotEmpty ? name : AppConstants.appName;
  }

  static String _body(Map<String, dynamic> data) {
    final String preview = ((data['chat_body'] as String?) ?? '').trim();
    if (preview.isNotEmpty) return preview;
    return ((data['body'] as String?) ?? '').trim();
  }

  static DateTime _sentAt(Map<String, dynamic> data) =>
      DateTime.tryParse((data['sent_at'] as String?) ?? '')?.toLocal() ?? DateTime.now();

  static Future<String> _language() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.languageCode) ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  /// Authenticated form PUT from any isolate, using the saved login token.
  static Future<bool> _put(String path, Map<String, String> fields) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final String? token = prefs.getString(AppConstants.token);
      if (token == null || token.isEmpty) return false;
      final http.Response res = await http.post(
        Uri.parse('${AppConstants.baseUrl}$path'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Localization': prefs.getString(AppConstants.languageCode) ?? 'en',
        },
        body: {...fields, '_method': 'put'},
      ).timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
