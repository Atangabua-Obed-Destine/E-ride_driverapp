import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/chat_kit.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_pop_scope_widget.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/features/chat/domain/models/message_model.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_controller.dart';
import 'package:ride_sharing_user_app/features/chat/widgets/message_bubble_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/paginated_list_view_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';

class MessageScreen extends StatefulWidget {
  final String channelId;
  final String tripId;
  final String userName;
  const MessageScreen({super.key, required this.channelId, required this.tripId, required this.userName});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  static const List<String> _quickReplyKeys = [
    'qr_driver_on_way',
    'qr_driver_arrived',
    'qr_driver_outside',
    'qr_driver_late',
    'qr_driver_where',
  ];

  final ScrollController scrollController = ScrollController();
  late final ChatInboxController _inbox = Get.find<ChatInboxController>();

  @override
  void initState() {
    super.initState();
    _inbox.chatOpened(channelId: widget.channelId, tripId: widget.tripId, peerName: widget.userName);
    Get.find<ChatController>().findChannelRideStatus(widget.channelId);
    Get.find<ChatController>().getConversation(widget.channelId, 1);
    Get.find<ChatController>().subscribeMessageChannel(widget.tripId);
  }

  @override
  void dispose() {
    _inbox.userStoppedTyping(widget.channelId);
    _inbox.chatClosed(widget.channelId);
    scrollController.dispose();
    super.dispose();
  }

  String _formatRecordingDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// The customer of this chat's trip, when that trip is the one loaded.
  ({String name, String? image, String? phone}) _peer(ChatController chat) {
    final trip = Get.find<RideController>().tripDetail;
    final String? base = Get.find<SplashController>().config?.imageBaseUrl?.profileImageCustomer;
    if (trip != null && trip.id == widget.tripId && trip.customer != null) {
      final customer = trip.customer!;
      final String name = '${customer.firstName ?? ''} ${customer.lastName ?? ''}'.trim();
      return (
        name: name.isNotEmpty ? name : widget.userName,
        image: (customer.profileImage ?? '').isNotEmpty ? '$base/${customer.profileImage}' : null,
        phone: customer.phone,
      );
    }
    final String me = Get.find<ProfileController>().driverId;
    final Message? fromPeer = chat.messageModel?.data?.firstWhereOrNull((m) => m.user?.id != null && m.user?.id != me);
    final String? image = fromPeer?.user?.profileImage;
    return (
      name: widget.userName,
      image: (image ?? '').isNotEmpty ? '$base/$image' : null,
      phone: fromPeer?.user?.phone,
    );
  }

  void _send(ChatController chat) {
    if (chat.conversationController.text.trim().isEmpty && chat.pickedImageFile!.isEmpty && chat.otherFile == null) {
      showCustomSnackBar('write_something'.tr);
    } else if (chat.conversationKey.currentState!.validate()) {
      _inbox.userStoppedTyping(widget.channelId);
      chat.sendMessage(widget.channelId, widget.tripId);
    }
    chat.conversationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Get.isDarkMode;
    final Color canvas = dark ? const Color(0xFF121212) : const Color(0xFFF2F2F5);
    final Color brand = Theme.of(context).primaryColor;

    return CustomPopScopeWidget(
      child: Scaffold(
        backgroundColor: canvas,
        body: GetBuilder<ChatController>(builder: (messageController) {
          final peer = _peer(messageController);
          final bool open = messageController.channelRideStatus;
          final List<Message>? messages = messageController.messageModel?.data;
          final bool voiceChatIsEnable = Get.find<SplashController>().config?.voiceChatIsEnable == true;
          final bool hasDraft = messageController.conversationController.text.trim().isNotEmpty
              || (messageController.pickedImageFile?.isNotEmpty ?? false)
              || messageController.otherFile != null;

          return Column(children: [
            GetBuilder<ChatInboxController>(builder: (inbox) => ChatHeader(
              name: peer.name,
              subtitle: open ? 'your_customer'.tr : 'trip_ended'.tr,
              imageUrl: peer.image,
              online: open,
              typing: inbox.peerTyping && inbox.openChannelId == widget.channelId,
              onBack: () => Get.back(),
              onCall: (open && (peer.phone ?? '').isNotEmpty) ? () => CallOptionsSheet.show(phone: peer.phone, name: peer.name) : null,
            )),

            Expanded(child: messages == null ?
              Center(child: SpinKitCircle(color: brand, size: 40.0)) :
              messages.isEmpty ?
              _EmptyChat(name: peer.name, imageUrl: peer.image) :
              SingleChildScrollView(
                controller: scrollController,
                reverse: true,
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall, bottom: 8),
                child: PaginatedListViewWidget(
                  reverse: true,
                  scrollController: scrollController,
                  totalSize: messageController.messageModel!.totalSize,
                  offset: (messageController.messageModel != null && messageController.messageModel!.offset != null) ?
                  int.parse(messageController.messageModel!.offset.toString()) : null,
                  onPaginate: (int? offset) async => await messageController.getConversation(widget.channelId, offset!),
                  itemView: ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    padding: const EdgeInsets.all(0),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemBuilder: (BuildContext context, int index) {
                      final Message message = messages[index];
                      return ConversationBubbleWidget(
                        key: ValueKey<Object>(message.id ?? message),
                        message: message,
                        previousMessage: index != 0 ? messages[index - 1] : null,
                        index: index,
                        length: messages.length,
                        onRetry: message.isFailed ? () => messageController.retryMessage(message, widget.channelId, widget.tripId) : null,
                      );
                    },
                  ),
                ),
              ),
            ),

            GetBuilder<ChatInboxController>(builder: (inbox) => AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: (inbox.peerTyping && inbox.openChannelId == widget.channelId) ? const TypingBubble() : const SizedBox(width: double.infinity),
            )),

            if (messageController.pickedImageFile != null && messageController.pickedImageFile!.isNotEmpty)
              Container(
                height: 90, width: Get.width,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: messageController.pickedImageFile!.length,
                  itemBuilder: (context, index) => Stack(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(height: 80, width: 80, child: Image.file(File(messageController.pickedImageFile![index].path), fit: BoxFit.cover)),
                      ),
                    ),
                    Positioned(right: 5, child: InkWell(
                      onTap: () => messageController.pickMultipleImage(true, index: index),
                      child: const Icon(Icons.cancel_rounded, color: Colors.red),
                    )),
                  ]),
                ),
              ),

            if (messageController.otherFile != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  const Icon(Icons.attach_file_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(messageController.otherFile!.names.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  InkWell(onTap: () => messageController.pickOtherFile(true), child: const Icon(Icons.cancel_rounded, color: Colors.red)),
                ]),
              ),

            if (!open)
              const SafeArea(top: false, child: ChatClosedBar())
            else ...[
              if (!hasDraft && !messageController.isRecordingVoice && !messageController.isSending)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: QuickReplies(
                    replies: _quickReplyKeys.map((k) => k.tr).toList(),
                    onTap: (text) => messageController.sendQuickReply(text, widget.channelId, widget.tripId),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: messageController.isRecordingVoice ?
                  _RecordingRow(
                    duration: _formatRecordingDuration(messageController.recordingDuration),
                    levels: messageController.waveformLevels,
                    onCancel: () => messageController.cancelVoiceRecording(),
                    onSend: () => messageController.stopAndSendVoiceRecording(widget.channelId, widget.tripId),
                  ) :
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Container(
                      constraints: const BoxConstraints(minHeight: 50),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF2C2C2E) : Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))],
                      ),
                      child: Form(
                        key: messageController.conversationKey,
                        child: Row(children: [
                          IconButton(
                            onPressed: () => messageController.pickMultipleImage(false),
                            tooltip: 'photo'.tr,
                            icon: Image.asset(Images.pickImage, width: 22, height: 22, color: Theme.of(context).hintColor),
                          ),
                          Expanded(child: TextField(
                            minLines: 1,
                            maxLines: 4,
                            controller: messageController.conversationController,
                            textCapitalization: TextCapitalization.sentences,
                            style: textMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: dark ? Colors.white : const Color(0xFF1C1C1E)),
                            keyboardType: TextInputType.multiline,
                            cursorColor: brand,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              hintText: 'type_a_message'.tr,
                              hintStyle: textRegular.copyWith(color: Theme.of(context).hintColor, fontSize: 16),
                            ),
                            onChanged: (text) {
                              messageController.update();
                              if (text.trim().isNotEmpty) _inbox.userTyping(widget.channelId);
                            },
                          )),
                          const SizedBox(width: 12),
                        ]),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Material(
                      color: brand,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: (messageController.isSending || messageController.isPickedImage) ? null :
                          (voiceChatIsEnable && !hasDraft) ? () => messageController.startVoiceRecording() : () => _send(messageController),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(
                            child: (messageController.isSending || messageController.isPickedImage) ?
                            const SpinKitCircle(color: Colors.white, size: 22) :
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                              child: (voiceChatIsEnable && !hasDraft) ?
                              const Icon(Icons.mic_rounded, key: ValueKey('mic'), color: Colors.white, size: 24) :
                              Transform(
                                key: const ValueKey('send'),
                                alignment: Alignment.center,
                                transform: Get.find<LocalizationController>().isLtr ? Matrix4.rotationY(0) : Matrix4.rotationY(math.pi),
                                child: Image.asset(Images.sendMessage, width: 22, height: 22, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ]);
        }),
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  final String duration;
  final List<double> levels;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  const _RecordingRow({required this.duration, required this.levels, required this.onCancel, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final Color brand = Theme.of(context).primaryColor;
    return Row(children: [
      IconButton(
        onPressed: onCancel,
        tooltip: 'delete'.tr,
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
      ),
      Expanded(child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(duration, style: textMedium.copyWith(color: brand, fontSize: Dimensions.fontSizeDefault)),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: ClipRect(child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: levels.map((level) => Container(
              width: 3,
              height: 6 + (level.clamp(0.0, 1.0) * 22),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(2)),
            )).toList(),
          ))),
        ]),
      )),
      const SizedBox(width: 8),
      Material(
        color: brand,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onSend,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Center(child: Transform(
              alignment: Alignment.center,
              transform: Get.find<LocalizationController>().isLtr ? Matrix4.rotationY(0) : Matrix4.rotationY(math.pi),
              child: Image.asset(Images.sendMessage, width: 22, height: 22, color: Colors.white),
            )),
          ),
        ),
      ),
    ]);
  }
}

class _EmptyChat extends StatelessWidget {
  final String name;
  final String? imageUrl;
  const _EmptyChat({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ChatAvatar(name: name, imageUrl: imageUrl, size: 76),
          const SizedBox(height: 14),
          Text('say_hello_to_customer'.tr, textAlign: TextAlign.center, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: 6),
          Text('chat_privacy_note'.tr, textAlign: TextAlign.center,
            style: textRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall)),
        ]),
      ),
    );
  }
}
