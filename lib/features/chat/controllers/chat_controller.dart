import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/chat/controllers/chat_inbox_controller.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/chat/domain/services/chat_service_interface.dart';
import 'package:ride_sharing_user_app/features/chat/screens/message_screen.dart';
import 'package:ride_sharing_user_app/features/chat/domain/models/channel_model.dart';
import 'package:ride_sharing_user_app/features/chat/domain/models/message_model.dart';
import 'package:ride_sharing_user_app/common_widgets/snackbar_widget.dart';
import 'package:ride_sharing_user_app/helper/file_validation_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class ChatController extends GetxController implements GetxService{
  final ChatServiceInterface chatServiceInterface;

  ChatController({required this.chatServiceInterface});


  List <XFile>? _pickedImageFiles =[];
  List <XFile>? get pickedImageFile => _pickedImageFiles;
  FilePickerResult? _otherFile;
  FilePickerResult? get otherFile => _otherFile;
  File? _file;
  PlatformFile? objFile;
  File? get file=> _file;
  List<MultipartBody> _selectedImageList = [];
  List<MultipartBody> get selectedImageList => _selectedImageList;
  final List<dynamic> _conversationList=[];
  List<dynamic> get conversationList => _conversationList;
  final bool _paginationLoading = true;
  bool get paginationLoading => _paginationLoading;
  int? _messagePageSize;
  final int _messageOffset = 1;
  int? get messagePageSize => _messagePageSize;
  int? get messageOffset => _messageOffset;
  int? _pageSize;
  final int _offset = 1;
  bool isLoading = false;
  final String _name='';
  String get name => _name;
  final String _image='';
  String get image => _image;
  int? get pageSize => _pageSize;
  int? get offset => _offset;
  var conversationController = TextEditingController();
  final GlobalKey<FormState> conversationKey  = GlobalKey<FormState>();
  bool _isPickedImage = false;
  bool get isPickedImage => _isPickedImage;

  @override
  void onInit(){
    super.onInit();
    conversationController.text = '';
  }


  void pickMultipleImage(bool isRemove,{int? index}) async {
    if(isRemove) {
      if(index != null){
        _pickedImageFiles!.removeAt(index);
        _selectedImageList.removeAt(index);
      }
    }else {
      _isPickedImage = true;
      Future.delayed(const Duration(seconds: 1)).then((value) {
        update();
      });

      _pickedImageFiles = await FileValidationHelper.validateAndPickMultipleImages();
      if (_pickedImageFiles != null) {
        for(int i =0; i< _pickedImageFiles!.length; i++){
          _selectedImageList.add(MultipartBody('files[$i]',_pickedImageFiles![i]));
        }
      }
      _isPickedImage = false;
    }
    update();
  }


  void pickOtherFile(bool isRemove) async {
    if(isRemove){
      _otherFile=null;
      _file = null;
    }else{
      _otherFile = (await FilePicker.pickFiles(
        type: FileType.custom,
        withReadStream: true,
        allowedExtensions: AppConstants.allowedImageExtensionsForFile,
      ))!;
      if (_otherFile != null) {
        if(await FileValidationHelper.validatePlatformFileSizeAsync(file: _otherFile!.files.single)){
          objFile = _otherFile!.files.single;
        }
      }
    }
    update();
  }

  void removeFile() async {
    _otherFile=null;
    update();
  }

  void cleanOldData(){
    _pickedImageFiles = [];
    _selectedImageList = [];
    _otherFile = null;
    _file = null;
  }

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  bool get isRecordingVoice => _isRecordingVoice;
  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;
  Timer? _recordingTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final List<double> _waveformLevels = [];
  List<double> get waveformLevels => _waveformLevels;

  Future<void> startVoiceRecording() async {
    if(!await _audioRecorder.hasPermission()){
      snackBarWidget('you_must_allow_permission_for_further_use'.tr);
      return;
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String filePath = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);

    _isRecordingVoice = true;
    _recordingDuration = Duration.zero;
    _waveformLevels.clear();
    update();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDuration += const Duration(seconds: 1);
      update();
    });

    _amplitudeSubscription = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((Amplitude amplitude) {
      final double normalized = ((amplitude.current + 45) / 45).clamp(0.05, 1.0);
      _waveformLevels.add(normalized);
      if(_waveformLevels.length > 40){
        _waveformLevels.removeAt(0);
      }
      update();
    });
  }

  Future<void> _stopVoiceRecordingTracking() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _isRecordingVoice = false;
    _recordingDuration = Duration.zero;
    _waveformLevels.clear();
  }

  Future<void> cancelVoiceRecording() async {
    await _stopVoiceRecordingTracking();
    await _audioRecorder.cancel();
    update();
  }

  Future<void> stopAndSendVoiceRecording(String channelId, String tripId) async {
    await _stopVoiceRecordingTracking();
    final String? recordedFilePath = await _audioRecorder.stop();
    update();

    if(recordedFilePath != null){
      final File recordedFile = File(recordedFilePath);
      final int size = await recordedFile.length();
      objFile = PlatformFile(
        path: recordedFilePath,
        name: path_helper.basename(recordedFilePath),
        size: size,
        readStream: recordedFile.openRead(),
      );
      await sendMessage(channelId, tripId);
    }
  }

  @override
  void onClose() {
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    conversationController.dispose();
    super.onClose();
  }

  ChannelModel? channelModel;

  Future<void> getChannelList(int offset) async{
    Response response = await chatServiceInterface.getChannelList(offset);
    if(response.statusCode == 200){
      if(offset == 1 ){
        channelModel = ChannelModel.fromJson(response.body);
      }else{
        channelModel!.totalSize =  ChannelModel.fromJson(response.body).totalSize;
        channelModel!.offset =  ChannelModel.fromJson(response.body).offset;
        channelModel!.data!.addAll(ChannelModel.fromJson(response.body).data!);
      }
      isLoading = false;
    }else{
      ApiChecker.checkApi(response);
    }
    update();
  }


  Future<void> createChannel(String userId, {required tripId}) async{
    isLoading = true;
    Response response = await chatServiceInterface.createChannel(userId,tripId);
    if(response.statusCode == 200){
      isLoading = false;
      Map map = response.body;
      String channelId = map['data']['channel']['id'];
      String tripId = map['data']['channel']['trip_id'];
      Get.to(()=> MessageScreen(channelId : channelId, tripId: tripId,userName:  '${map['data']['user']['first_name']} ${map['data']['user']['last_name']}'));
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
  }



  MessageModel? messageModel;
  Future<Response> getConversation(String channelId, int offset) async{
    isLoading = true;
    Response response = await chatServiceInterface.getConversation(channelId, offset);
    if(response.statusCode == 200){
      if(offset == 1 ){
        messageModel = MessageModel.fromJson(response.body);

      }else{
        messageModel!.totalSize =  MessageModel.fromJson(response.body).totalSize;
        messageModel!.offset =  MessageModel.fromJson(response.body).offset;
        messageModel!.data!.addAll(MessageModel.fromJson(response.body).data!);
      }
      isLoading = false;
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }


  bool isSending = false;
  Future<void> sendMessage(String channelId, String tripId) async{
    final String pendingText = conversationController.value.text.trim();
    final bool textOnly = pendingText.isNotEmpty && _selectedImageList.isEmpty && objFile == null;
    Message? pending;
    if (textOnly && messageModel?.data != null) {
      pending = Message(
        message: pendingText,
        tripId: messageModel!.data!.isNotEmpty ? messageModel!.data!.first.tripId : null,
        user: User(id: Get.find<ProfileController>().profileInfo?.id),
        isPending: true,
        conversationFiles: [],
      )..createdAt = DateTime.now().toUtc().toIso8601String();
      messageModel!.data!.insert(0, pending);
    }
    isSending = true;
    update();
    Response response = await chatServiceInterface.sendMessage(conversationController.value.text, channelId , tripId,_selectedImageList, objFile);
    if(response.statusCode == 200){
      isSending = false;
      getConversation(channelId, 1);
      conversationController.text='';
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile=null;
      objFile =null;
      _file=null;
    }
    else if(response.statusCode == 400){
      isSending = false;
      _markFailed(pending);
      String message = response.body['errors'][0]['message'];
      if(message.contains("png  jpg  jpeg  csv  txt  xlx  xls  pdf")){
        message = "the_files_types_must_be";
      }
      if(message.contains("failed to upload")){
        message = "failed_to_upload";
      }
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile=null;
      objFile =null;
      _file=null;
      snackBarWidget(message.tr);
    }
    else{
      isSending = false;
      _markFailed(pending);
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile=null;
      objFile =null;
      _file=null;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
  }

   /// Kept for existing callers: the trip chat is now kept live by
  /// [ChatInboxController], which also survives reconnects.
  void subscribeMessageChannel(String tripId){
    Get.find<ChatInboxController>().watchTrip(tripId);
  }

  /// A message that arrived over the websocket while this chat is open.
  void insertIncoming(Message message) {
    final List<Message>? list = messageModel?.data;
    if (list == null) return;
    if (message.id != null && list.any((m) => m.id == message.id)) return;
    list.insert(0, message);
    messageModel!.totalSize = (messageModel!.totalSize ?? 0) + 1;
    update();
  }

  /// The other party read the chat: every message I sent is now "seen".
  void markMineRead() {
    final List<Message>? list = messageModel?.data;
    final String? me = Get.find<ProfileController>().profileInfo?.id;
    if (list == null || me == null) return;
    for (final Message m in list) {
      if ((m.user?.id ?? m.userId) == me && !m.isPending) m.isRead = true;
    }
    update();
  }

  void _markFailed(Message? pending) {
    if (pending == null) return;
    pending
      ..isPending = false
      ..isFailed = true;
  }

  /// Sends a failed text message again.
  Future<void> retryMessage(Message failed, String channelId, String tripId) async {
    messageModel?.data?.remove(failed);
    conversationController.text = failed.message ?? '';
    // sendMessage reads the text before its first await, so the box can be
    // cleared straight away.
    final Future<void> sending = sendMessage(channelId, tripId);
    conversationController.clear();
    update();
    await sending;
  }

  /// Sends a quick reply chip as a message.
  Future<void> sendQuickReply(String text, String channelId, String tripId) async {
    if (isSending) return;
    conversationController.text = text;
    final Future<void> sending = sendMessage(channelId, tripId);
    conversationController.clear();
    update();
    await sending;
  }

  bool _channelRideStatus = true;
  bool get channelRideStatus => _channelRideStatus;
  void findChannelRideStatus(String channelId) async{
    Response response = await chatServiceInterface.findChannelRideStatus(channelId);
     if(response.body['data'] == "cancelled" || response.body['data'] == 'completed'){
       _channelRideStatus = false;
     }else{
       _channelRideStatus = true;
     }
     update();
  }



}