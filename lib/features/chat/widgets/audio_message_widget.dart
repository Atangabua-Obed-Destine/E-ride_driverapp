import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ride_sharing_user_app/common_widgets/snackbar_widget.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  final String fileName;
  final bool isMe;

  const AudioMessageWidget({super.key, required this.audioUrl, required this.fileName, required this.isMe});

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioPlayer _player = AudioPlayer();
  late final List<double> _waveformLevels;
  bool _isPlaying = false;
  bool _hasStarted = false;
  bool _isDownloading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _waveformLevels = List.generate(26, (index) {
      final Random random = Random(widget.audioUrl.hashCode + index);
      return 0.25 + random.nextDouble() * 0.75;
    });

    _player.setReleaseMode(ReleaseMode.stop);
    _player.setSourceUrl(widget.audioUrl);
    _player.onDurationChanged.listen((Duration duration) {
      if(mounted) setState(() => _duration = duration);
    });
    _player.onPositionChanged.listen((Duration position) {
      if(mounted) setState(() => _position = position);
    });
    _player.onPlayerComplete.listen((_) {
      if(mounted){
        setState(() {
          _isPlaying = false;
          _hasStarted = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if(_isPlaying){
      await _player.pause();
      if(mounted) setState(() => _isPlaying = false);
    }else{
      if(_hasStarted){
        await _player.resume();
      }else{
        _hasStarted = true;
        await _player.play(UrlSource(widget.audioUrl));
      }
      if(mounted) setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _download() async {
    if(_isDownloading) return;
    setState(() => _isDownloading = true);

    final PermissionStatus status = await Permission.storage.status;
    if(!status.isGranted){
      await Permission.storage.request();
    }

    try{
      if(GetPlatform.isIOS){
        final HttpClient client = HttpClient();
        final HttpClientResponse response = await client.getUrl(Uri.parse(widget.audioUrl)).then((HttpClientRequest request) => request.close());
        if(response.statusCode == 200){
          final Directory downloadDirectory = await getApplicationDocumentsDirectory();
          final String filePathName = '${downloadDirectory.path}/${widget.fileName}';
          final File savedFile = File(filePathName);
          if(await savedFile.exists()){
            snackBarWidget('file_already_downloaded'.tr, isError: false);
            await OpenFile.open(filePathName);
          }else{
            final List<int> downloadData = [];
            await response.forEach(downloadData.addAll);
            await savedFile.writeAsBytes(downloadData);
            snackBarWidget('downloaded_successfully'.tr, isError: false);
          }
        }else{
          snackBarWidget('download_failed'.tr, isError: true);
        }
      }else{
        Directory downloadDirectory = Directory('/storage/emulated/0/Download');
        if(!await downloadDirectory.exists()){
          downloadDirectory = (await getExternalStorageDirectory())!;
        }
        final String filePathName = '${downloadDirectory.path}/${widget.fileName}';
        final File savedFile = File(filePathName);
        if(await savedFile.exists()){
          snackBarWidget('file_already_downloaded'.tr, isError: false);
          await OpenFile.open(filePathName);
        }else{
          final String? task = await FlutterDownloader.enqueue(
            url: widget.audioUrl,
            savedDir: downloadDirectory.path,
            fileName: widget.fileName,
            showNotification: true,
            saveInPublicStorage: true,
            openFileFromNotification: true,
          );
          snackBarWidget(task != null ? 'downloaded_successfully'.tr : 'download_failed'.tr, isError: task == null);
        }
      }
    }finally{
      if(mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _duration.inMilliseconds == 0 ? 0 : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1);
    final int highlightedBars = (progress * _waveformLevels.length).round();
    final Color idleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha: widget.isMe ? 0.20 : 0.08),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: _togglePlay,
          child: Container(
            height: 32, width: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPlaying ? idleColor : Colors.transparent,
              border: Border.all(color: idleColor, width: 1.4),
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: _isPlaying ? Theme.of(context).cardColor : idleColor,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        Text(
          _formatDuration(_hasStarted ? _position : _duration),
          style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: idleColor),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        ClipRect(child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_waveformLevels.length, (int index) => Container(
            width: 2.5, height: 6 + (_waveformLevels[index] * 16),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: index < highlightedBars ? Colors.teal : idleColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        )),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        InkWell(
          onTap: _download,
          child: _isDownloading ?
          const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) :
          Icon(Icons.file_download_outlined, color: Theme.of(context).primaryColor, size: 20),
        ),
      ]),
    );
  }
}
