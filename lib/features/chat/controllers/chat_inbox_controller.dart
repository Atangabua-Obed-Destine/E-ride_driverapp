import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/chat_banner.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_controller.dart';
import 'package:ride_sharing_user_app/features/chat/domain/models/message_model.dart';
import 'package:ride_sharing_user_app/features/chat/domain/services/chat_service_interface.dart';
import 'package:ride_sharing_user_app/features/chat/screens/chat_screen.dart';
import 'package:ride_sharing_user_app/features/chat/screens/message_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/helper/chat_notification_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/main.dart';

/// Everything that keeps the trip chat live outside the chat screen itself.
///
///  * Subscribes to this user's private chat channel for the active trip as
///    soon as a driver is assigned, not only while the chat is open, and
///    re-subscribes after every reconnect (the socket library does not).
///  * Delivers each new message exactly once, whether it came over the
///    websocket or as a push: into the open chat, or as an unread count plus
///    an in-app banner.
///  * Read receipts and "typing" from the other side.
///
/// Mirrors the user app's ChatInboxController (MessageController there plays
/// ChatController's role here).
class ChatInboxController extends GetxController with WidgetsBindingObserver implements GetxService {
  final ChatServiceInterface messageServiceInterface;
  ChatInboxController({required this.messageServiceInterface});

  /// This app listens on `private-<audience>-ride-chat.<tripId>`.
  static const String _audience = 'driver';
  static const Set<String> _liveStatuses = {'accepted', 'out_for_pickup', 'ongoing'};

  // ---------------------------------------------------------------- unread
  final Map<String, int> _unreadByChannel = {};
  final Map<String, String> _tripByChannel = {};

  int get totalUnread => _unreadByChannel.values.fold(0, (sum, n) => sum + n);
  int unreadForChannel(String? channelId) => channelId == null ? 0 : (_unreadByChannel[channelId] ?? 0);
  int unreadForTrip(String? tripId) {
    if (tripId == null || tripId.isEmpty) return 0;
    int sum = 0;
    _unreadByChannel.forEach((channel, n) {
      if (_tripByChannel[channel] == tripId) sum += n;
    });
    return sum;
  }

  Future<void> refreshUnread() async {
    if (!_signedIn) return;
    try {
      final Response response = await messageServiceInterface.getUnreadSummary();
      if (response.statusCode != 200 || response.body is! Map) return;
      final dynamic data = response.body['data'];
      if (data is! Map) return;
      _unreadByChannel.clear();
      for (final dynamic row in (data['channels'] as List? ?? const [])) {
        if (row is! Map) continue;
        final String? channel = row['channel_id']?.toString();
        if (channel == null || channel == openChannelId) continue;
        _unreadByChannel[channel] = int.tryParse('${row['unread']}') ?? 0;
        final String? trip = row['trip_id']?.toString();
        if (trip != null) _tripByChannel[channel] = trip;
      }
      update();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- open chat
  String? openChannelId;
  String? openTripId;
  String? openPeerName;

  /// The other party is typing in the open chat.
  bool peerTyping = false;
  Timer? _typingTimer;

  void chatOpened({required String channelId, required String tripId, required String peerName}) {
    openChannelId = channelId;
    openTripId = tripId;
    openPeerName = peerName;
    _tripByChannel[channelId] = tripId;
    _unreadByChannel.remove(channelId);
    peerTyping = false;
    ChatNotificationHelper.cancelConversation(channelId, flutterLocalNotificationsPlugin);
    watchTrip(tripId);
    _afterFrame(() {
      ChatBanner.dismiss(animated: false);
      update();
    });
  }

  void chatClosed(String channelId) {
    if (openChannelId != channelId) return;
    openChannelId = null;
    openTripId = null;
    openPeerName = null;
    peerTyping = false;
    _typingTimer?.cancel();
    _afterFrame(update);
    // The chat list (if it is underneath) and the badges follow the server.
    if (Get.find<ChatController>().channelModel != null) {
      Get.find<ChatController>().getChannelList(1);
    }
    refreshUnread();
  }

  // ---------------------------------------------------------------- realtime
  String? _watchedTripId;
  PrivateChannel? _channel;
  PusherChannelsClient? _client;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _healthTimer;

  /// Called whenever trip details load. Watches a live trip; stops watching
  /// only when the watched trip itself has ended (an old trip opened from
  /// history must not stop the current one).
  void syncTrip(String? tripId, String? status) {
    _log('syncTrip $tripId $status');
    if (tripId == null || tripId.isEmpty) return;
    if (_liveStatuses.contains(status)) {
      watchTrip(tripId);
    } else if (tripId == _watchedTripId) {
      stopWatching();
    }
  }

  void watchTrip(String tripId) {
    if (_watchedTripId != tripId) {
      _detach();
      _watchedTripId = tripId;
    }
    _ensureLive();
    _healthTimer ??= Timer.periodic(const Duration(seconds: 20), (_) => _ensureLive());
  }

  void stopWatching() {
    _detach();
    _watchedTripId = null;
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  void _detach() {
    for (final StreamSubscription<dynamic> s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    try {
      _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    _client = null;
  }

  /// Makes sure the chat channel is subscribed on the current socket client.
  void _ensureLive() {
    final String? tripId = _watchedTripId;
    final PusherChannelsClient? client = PusherHelper.pusherClient;
    if (tripId == null || client == null || !_signedIn) {
      _log('not live: trip=$tripId client=${client != null} signedIn=$_signedIn');
      return;
    }
    final SplashController config = Get.find<SplashController>();
    if (config.config?.webSocketUrl == null) return;

    if (!identical(client, _client) || _channel == null) {
      _detach();
      _client = client;
      final String scheme = config.config!.websocketScheme == 'https' ? 'https' : 'http';
      final PrivateChannel channel = client.privateChannel(
        'private-$_audience-ride-chat.$tripId',
        forceCreateNewInstance: true,
        authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
          authorizationEndpoint: Uri.parse('$scheme://${config.config!.webSocketUrl}/broadcasting/auth'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${Get.find<AuthController>().getUserToken()}',
          },
        ),
      );
      _channel = channel;
      _subscriptions
        ..add(channel.bind('$_audience-ride-chat.$tripId').listen((e) => _onSocketMessage(e.data)))
        ..add(channel.bind('ride-chat-read.$tripId').listen((e) => _onReadReceipt(e.data)))
        ..add(channel.bind('ride-chat-typing.$tripId').listen((e) => _onTyping(e.data)))
        ..add(channel.whenSubscriptionSucceeded().listen((_) => _log('subscribed ${channel.name}')))
        ..add(channel.onSubscriptionError().listen((e) => _log('subscription error ${channel.name}: ${e.data}')))
        ..add(channel.onAuthenticationSubscriptionFailed().listen((e) => _log('auth failed ${channel.name}: ${e.data}')))
        // The library does not restore subscriptions after a reconnect.
        ..add(client.onConnectionEstablished.listen((_) {
          _channel?.subscribeIfNotUnsubscribed();
          refreshUnread();
        }));
      _log('subscribing ${channel.name}');
      channel.subscribe();
    } else {
      _channel!.subscribeIfNotUnsubscribed();
    }
  }

  void _onSocketMessage(dynamic raw) {
    _log('socket message');
    final Map<String, dynamic>? data = _decode(raw);
    final dynamic conversation = data?['channel_conversation'];
    if (conversation is! Map) return;
    final Map<String, dynamic> json = Map<String, dynamic>.from(conversation);
    final Map<String, dynamic> channel = json['channel'] is Map ? Map<String, dynamic>.from(json['channel']) : {};
    final Message message = Message.fromJson(json);
    final String? channelId = channel['id']?.toString();
    if (channelId == null) return;
    final String sender = '${message.user?.firstName ?? ''} ${message.user?.lastName ?? ''}'.trim();
    _deliver(
      id: message.id,
      channelId: channelId,
      tripId: channel['trip_id']?.toString() ?? _watchedTripId ?? '',
      senderId: message.user?.id ?? message.userId,
      senderName: sender,
      preview: _previewOf(message),
      imagePath: message.user?.profileImage,
      message: message,
      fromSocket: true,
    );
  }

  void _onReadReceipt(dynamic raw) {
    final Map<String, dynamic>? data = _decode(raw);
    final String? channelId = data?['channel_id']?.toString();
    if (channelId == null || channelId != openChannelId) return;
    Get.find<ChatController>().markMineRead();
  }

  void _onTyping(dynamic raw) {
    final Map<String, dynamic>? data = _decode(raw);
    final String? channelId = data?['channel_id']?.toString();
    if (channelId == null || channelId != openChannelId) return;
    final bool typing = data?['typing'] != false && data?['typing'] != 0;
    _typingTimer?.cancel();
    peerTyping = typing;
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 6), () {
        peerTyping = false;
        update();
      });
    }
    update();
  }

  /// A chat push that reached the app while it is in the foreground.
  void onForegroundPush(Map<String, dynamic> data) {
    final String channelId = ChatNotificationHelper.conversationOf(data);
    if (channelId.isEmpty) return;
    _deliver(
      id: int.tryParse('${data['message_id']}'),
      channelId: channelId,
      tripId: data['ride_request_id']?.toString() ?? '',
      senderId: data['sender_id']?.toString(),
      senderName: ((data['sender_name'] ?? data['user_name']) ?? '').toString().trim(),
      preview: ((data['chat_body'] ?? '').toString().trim().isNotEmpty ? data['chat_body'] : data['body'] ?? '').toString(),
      imagePath: null,
      message: null,
    );
  }

  // ---------------------------------------------------------------- delivery
  final List<int> _recentIds = [];
  // Pushes from an older backend carry no message id; these pair such a push
  // with the websocket copy of the same message (they arrive within moments).
  final Map<String, DateTime> _lastSocketAt = {};
  final Map<String, DateTime> _lastAnonymousPushAt = {};
  static const Duration _pairWindow = Duration(seconds: 8);

  bool _isPairedDuplicate(String channelId, {required bool fromSocket, required bool hasId}) {
    final DateTime now = DateTime.now();
    if (fromSocket) {
      _lastSocketAt[channelId] = now;
      final DateTime? push = _lastAnonymousPushAt.remove(channelId);
      return push != null && now.difference(push) < _pairWindow;
    }
    if (hasId) return false;
    final DateTime? socket = _lastSocketAt[channelId];
    if (socket != null && now.difference(socket) < _pairWindow) {
      _lastSocketAt.remove(channelId);
      return true;
    }
    _lastAnonymousPushAt[channelId] = now;
    return false;
  }

  void _deliver({
    required int? id,
    required String channelId,
    required String tripId,
    required String? senderId,
    required String senderName,
    required String preview,
    required String? imagePath,
    required Message? message,
    bool fromSocket = false,
  }) {
    if (_isPairedDuplicate(channelId, fromSocket: fromSocket, hasId: id != null)) {
      if (message != null && channelId == openChannelId) {
        Get.find<ChatController>().insertIncoming(message);
      } else if (fromSocket) {
        ChatBanner.updateBody(senderName.isNotEmpty ? senderName : 'customer'.tr, preview);
      }
      return;
    }
    if (id != null) {
      if (_recentIds.contains(id)) return; // already delivered by the other path
      _recentIds.add(id);
      if (_recentIds.length > 200) _recentIds.removeAt(0);
    }
    if (senderId != null && senderId == _myId) return;
    if (tripId.isNotEmpty) _tripByChannel[channelId] = tripId;

    final bool chatOnScreen = channelId == openChannelId && _foreground;
    if (chatOnScreen) {
      peerTyping = false;
      final ChatController chat = Get.find<ChatController>();
      if (message != null) {
        chat.insertIncoming(message);
      } else {
        chat.getConversation(channelId, 1);
      }
      _scheduleMarkRead(channelId);
      HapticFeedback.selectionClick();
      _playPop();
      update();
      return;
    }

    _unreadByChannel[channelId] = (_unreadByChannel[channelId] ?? 0) + 1;
    update();

    if (Get.currentRoute == '/ChatScreen') {
      Get.find<ChatController>().getChannelList(1);
    }
    if (_foreground) {
      _playPop();
      ChatBanner.show(
        title: senderName.isNotEmpty ? senderName : 'customer'.tr,
        subtitle: 'your_customer'.tr,
        body: preview.isNotEmpty ? preview : 'sent_you_a_message'.tr,
        imageUrl: _imageUrl(imagePath),
        onTap: () => openChat(channelId: channelId, tripId: tripId, peerName: senderName),
      );
    }
  }

  void openChat({required String channelId, required String tripId, required String peerName}) {
    if (openChannelId == channelId && Get.currentRoute == '/MessageScreen') return;
    Get.to(() => MessageScreen(channelId: channelId, tripId: tripId, userName: peerName));
  }

  void openInbox() {
    Get.to(() => const ChatScreen());
  }

  // ---------------------------------------------------------------- outgoing signals
  Timer? _readTimer;

  void _scheduleMarkRead(String channelId) {
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 500), () {
      messageServiceInterface.markChatRead(channelId);
    });
  }

  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// Call on every keystroke; sends at most one "typing" signal per 3 s.
  void userTyping(String channelId) {
    final DateTime now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(seconds: 3)) return;
    _lastTypingSent = now;
    messageServiceInterface.sendTyping(channelId);
  }

  void userStoppedTyping(String channelId) {
    if (DateTime.now().difference(_lastTypingSent) > const Duration(seconds: 6)) return;
    _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
    messageServiceInterface.sendTyping(channelId, typing: false);
  }

  // ---------------------------------------------------------------- lifecycle
  bool _foreground = true;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    stopWatching();
    _player?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _ensureLive();
      refreshUnread();
      final String? open = openChannelId;
      if (open != null) {
        // Catch up on anything that arrived while the app was away.
        ChatNotificationHelper.cancelConversation(open, flutterLocalNotificationsPlugin);
        Get.find<ChatController>().getConversation(open, 1);
      }
    }
  }

  // ---------------------------------------------------------------- helpers
  static void _log(String message) {
    if (kDebugMode) debugPrint('[chat] $message');
  }

  /// Runs [action] outside a build or dispose (opening and closing a chat
  /// happen there, and other screens' badges listen to this controller).
  static void _afterFrame(VoidCallback action) {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      action();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => action());
    }
  }

  AudioPlayer? _player;

  Future<void> _playPop() async {
    try {
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.notificationEvent,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ));
      await player.stop();
      await player.setVolume(0.7);
      await player.play(AssetSource('sound/chat_pop.wav'));
    } catch (_) {}
  }

  bool get _signedIn {
    try {
      return Get.find<AuthController>().isLoggedIn();
    } catch (_) {
      return false;
    }
  }

  String? get _myId {
    try {
      return Get.find<ProfileController>().profileInfo?.id;
    } catch (_) {
      return null;
    }
  }

  String? _imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final String? base = Get.find<SplashController>().config?.imageBaseUrl?.profileImageCustomer;
    return base == null ? null : '$base/$path';
  }

  static String _previewOf(Message message) {
    final String text = (message.message ?? '').trim();
    if (text.isNotEmpty) return text;
    final List<ConversationFiles> files = message.conversationFiles ?? const [];
    if (files.isEmpty) return '';
    final String type = (files.first.fileType ?? '').toLowerCase();
    if (const ['m4a', 'mp3', 'aac', 'wav', 'ogg', 'opus', 'amr', '3gp'].contains(type)) return '🎤 ${'voice_message'.tr}';
    if (const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'].contains(type)) return '📷 ${'photo'.tr}';
    return '📎 ${'attachment'.tr}';
  }

  static Map<String, dynamic>? _decode(dynamic raw) {
    try {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is String && raw.isNotEmpty) return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    return null;
  }
}
