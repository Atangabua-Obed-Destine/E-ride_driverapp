import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ride_sharing_user_app/common_widgets/chat_kit.dart';
import 'package:ride_sharing_user_app/common_widgets/popup_banner/popup_banner.dart';
import 'package:ride_sharing_user_app/helper/date_converter.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/chat/domain/models/message_model.dart';
import 'package:ride_sharing_user_app/features/chat/widgets/audio_message_widget.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class ConversationBubbleWidget extends StatefulWidget {
  final Message message;
  final Message? previousMessage;
  final int index;
  final int length;
  /// Called when a message that failed to send is tapped.
  final VoidCallback? onRetry;
  const ConversationBubbleWidget({super.key,  required this.message,  this.previousMessage, required this.index, required this.length, this.onRetry});
  @override
  State<ConversationBubbleWidget> createState() => _ConversationBubbleWidgetState();
}

class _ConversationBubbleWidgetState extends State<ConversationBubbleWidget> {
  List<String> images = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<ConversationFiles> audioFiles = widget.message.conversationFiles!.where((ConversationFiles file) => _isAudioFile(file.fileType)).toList();
    final List<ConversationFiles> nonAudioFiles = widget.message.conversationFiles!.where((ConversationFiles file) => !_isAudioFile(file.fileType)).toList();

    images = [];
     for (var element in nonAudioFiles) {
      images.add('${Get.find<SplashController>().config!.imageBaseUrl!.conversation}/${element.fileName ?? ''}');
     }
    return Column(crossAxisAlignment: (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
     CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Padding(padding: (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
      const EdgeInsets.fromLTRB(20, 5, 5, 5) : const EdgeInsets.fromLTRB(5, 5, 20, 5),
        child: Column(
          crossAxisAlignment: (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
          CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            SizedBox(height:Dimensions.fontSizeExtraSmall),

           if((widget.length-1 == widget.index))...[
             Center(child: Text("${DateConverter.stringToLocalDateOnly(widget.message.createdAt??DateTime.now().toString())}, ${'trip'.tr}# ${widget.index==0 ? widget.message.tripId : widget.previousMessage?.tripId}",
               style: textRegular.copyWith(color: Theme.of(context).hintColor),)),

             const SizedBox(height: Dimensions.paddingSizeDefault,)
           ],


            Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
              MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
                const SizedBox() :
                Column(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(50),
                      child: ImageWidget(height: 30, width: 30,
                          image: '${Get.find<SplashController>().config!.imageBaseUrl!.profileImageCustomer}/${widget.message.user!.profileImage}',
                      placeholder: Images.personPlaceholder,)
                  )]),



                const SizedBox(width: Dimensions.paddingSizeSmall,),
                Flexible(child: Column(crossAxisAlignment: (widget.message.user!.id! == Get.find<ProfileController>().driverId)?
                  CrossAxisAlignment.end:CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                      if(widget.message.message != null)
                      Flexible(child: Padding(padding: (widget.message.user!.id! == Get.find<ProfileController>().driverId) ? EdgeInsets.only(left:Get.width *0.15 ) :  EdgeInsets.only(right:Get.width *0.1),
                        child: Builder(builder: (context) {
                          final bool isMe = widget.message.user!.id! == Get.find<ProfileController>().driverId;
                          return GestureDetector(
                            onTap: widget.message.isFailed ? widget.onRetry : null,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: widget.message.isPending ? 0.75 : 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isMe ? Theme.of(context).primaryColor : (Get.isDarkMode ? const Color(0xFF2C2C2E) : Colors.white),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMe ? 18 : 6),
                                    bottomRight: Radius.circular(isMe ? 6 : 18),
                                  ),
                                  boxShadow: isMe ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(widget.message.message??'', style: TextStyle(
                                    color: isMe ? Colors.white : (Get.isDarkMode ? Colors.white : const Color(0xFF1C1C1E)),
                                    fontSize: 15,
                                    height: 1.3,
                                  )),
                                ),
                              ),
                            ),
                          );
                        }),
                      )),


                      if( widget.message.message != null) const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                      if(audioFiles.isNotEmpty)
                      Column(
                        crossAxisAlignment: (widget.message.user!.id! == Get.find<ProfileController>().driverId) ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: audioFiles.map((ConversationFiles file) => Padding(
                          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
                          child: AudioMessageWidget(
                            audioUrl: '${Get.find<SplashController>().config!.imageBaseUrl!.conversation}/${file.fileName ?? ''}',
                            fileName: file.fileName ?? 'audio.m4a',
                            isMe: widget.message.user!.id! == Get.find<ProfileController>().driverId,
                          ),
                        )).toList(),
                      ),

                      if(audioFiles.isNotEmpty && nonAudioFiles.isNotEmpty) const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                      nonAudioFiles.isNotEmpty?
                      SizedBox(width: nonAudioFiles.length < 4 ? context.width : context.width *0.53,
                        child: Directionality(textDirection:Get.find<LocalizationController>().isLtr ? (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
                          TextDirection.rtl: TextDirection.ltr : (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?TextDirection.ltr : TextDirection.rtl,
                          child: GridView.builder(padding: EdgeInsets.zero,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              childAspectRatio: 1,
                              crossAxisCount: nonAudioFiles.length < 4 ? 3 : 2,
                              mainAxisSpacing: Dimensions.paddingSizeSmall,
                              crossAxisSpacing: Dimensions.paddingSizeSmall),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: nonAudioFiles.length < 4 ? nonAudioFiles.length : 4,
                            itemBuilder: (BuildContext context, index){
                              return nonAudioFiles[index].fileType == 'png' || nonAudioFiles[index].fileType == 'jpg'?
                               Padding( padding: const EdgeInsets.only(right: 5,top: 0,bottom: 5),
                                  child: InkWell(onTap: ()=> PopupBanner(
                                      context: context, images: images,useDots: false,useArrowButton: true,
                                      initIndex: index,dotsAlignment: Alignment.bottomCenter,
                                      onClick: (index){},autoSlide: false,fit: BoxFit.contain,
                                    showDownloadButton: false
                                  ).show(),
                                    child: Stack(children: [
                                          ClipRRect(borderRadius: BorderRadius.circular(5),
                                              child:ImageWidget(height: 100, width: 100, fit: BoxFit.cover,
                                                  image: '${Get.find<SplashController>().config!.imageBaseUrl!.conversation!}/${nonAudioFiles[index].fileName ?? ''}')),

                                          (nonAudioFiles.length > 4 && index == 3) ?
                                          Container(height: 100,width: 100,color: Colors.transparent.withValues(alpha: 0.5,),child: Center(child: Text('+${nonAudioFiles.length - 4}',style: textRegular.copyWith(color: Theme.of(context).cardColor, fontSize: 16),)),):
                                              const SizedBox()
                                        ]),
                                  )) :


                              InkWell(onTap : () async {
                                  final status = await Permission.storage.request();
                                  if(status.isGranted){
                                    Directory? directory = Directory('/storage/emulated/0/Download');
                                    if (!await directory.exists()) {
                                      directory = Platform.isAndroid
                                          ? await getExternalStorageDirectory() //FOR ANDROID
                                          : await getApplicationSupportDirectory();
                                    }
                                  }
                                },
                                child: Container(height: 50,width: 50,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).hoverColor),
                                  child: Stack(children: [
                                      Center(child: SizedBox(width: 50, child: Image.asset(Images.folder))),
                                      Center(child: Text('${nonAudioFiles[index].fileName}'.substring(nonAudioFiles[index].fileName!.length-7),
                                          maxLines: 5, overflow: TextOverflow.clip)),
                                    ])));

                            },),
                        ),
                      ):

                      const SizedBox.shrink(),
                    ],
                  ),
                ),

                const SizedBox(width: Dimensions.paddingSizeSmall,),
                (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
                ClipRRect(borderRadius: BorderRadius.circular(50),
                    child: ImageWidget(height: 30, width: 30,
                        image: '${Get.find<SplashController>().config!.imageBaseUrl!.profileImage!}/${widget.message.user!.profileImage}',
                      placeholder: Images.personPlaceholder,
                    )
                )
                    : const SizedBox(),
              ],
            ),


          ],
        ),
      ),

      Padding(padding: (widget.message.user!.id! == Get.find<ProfileController>().driverId) ?
      const EdgeInsets.fromLTRB(5, 0, 12, 12) : const EdgeInsets.fromLTRB(50, 0, 5, 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.message.isFailed)
              GestureDetector(
                onTap: widget.onRetry,
                child: Text('not_sent_tap_to_retry'.tr,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).colorScheme.error)),
              )
            else
              Text(
                widget.message.isPending ? 'sending'.tr : DateConverter.isoDateTimeStringToDifferentWithCurrentTime(widget.message.createdAt ?? DateTime.now().toString()),
                textDirection: TextDirection.ltr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall,color: Theme.of(context).hintColor)),
            if (widget.message.user!.id! == Get.find<ProfileController>().driverId) ...[
              const SizedBox(width: 4),
              MessageTicks(
                pending: widget.message.isPending,
                failed: widget.message.isFailed,
                read: widget.message.isRead,
                color: Theme.of(context).hintColor,
              ),
            ],
          ])),

      if(widget.previousMessage != null && widget.previousMessage?.tripId != null && widget.message.tripId != widget.previousMessage?.tripId)
          Center(child: Text("${DateConverter.stringToLocalDateOnly(widget.previousMessage?.createdAt??DateTime.now().toString())}, ${'trip'.tr}# ${widget.index==0 ? widget.message.tripId : widget.previousMessage?.tripId}",
            style: textRegular.copyWith(color: Theme.of(context).hintColor),)),
    ],
    );
  }
}

bool _isAudioFile(String? fileType) => fileType != null && AppConstants.audioFileExtensions.contains(fileType.toLowerCase());

