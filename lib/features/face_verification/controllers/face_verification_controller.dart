import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/face_verification/domain/services/face_verification_service_interface.dart';
import 'package:ride_sharing_user_app/features/face_verification/screens/face_verification_result_screen.dart';
import 'package:ride_sharing_user_app/features/face_verification/screens/face_verification_screen.dart';
import 'package:ride_sharing_user_app/features/face_verification/widgets/face_verifing_dialog.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/main.dart';

class FaceVerificationController extends GetxController implements GetxService{
  final FaceVerificationServiceInterface faceVerificationServiceInterface;
  FaceVerificationController({required this.faceVerificationServiceInterface});

  bool _isBusy = false;
  set setBusy(bool value)=> _isBusy = value;
  CameraController? controller;
  int _eyeBlink = 0;
  bool _isSuccess = true;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
    ),
  );

  File? _imageFile;
  XFile? compressXFile;
  int get eyeBlink => _eyeBlink;
  bool get isSuccess => _isSuccess;
  File? get getImage => _imageFile;



  Future startLiveFeed() async {
    final camera = cameras[1];
    controller?.dispose();
    controller = null;
    controller = CameraController(
      camera,
      GetPlatform.isIOS ?  ResolutionPreset.medium :  ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // for Android
          : ImageFormatGroup.bgra8888, // f
    );
    controller?.initialize().then((_) {
      controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });

      controller?.startImageStream((CameraImage cameraImage) => _inputImageFromCameraImage(image: cameraImage, camera: camera));

      update();
    });
  }

  Future<void> _inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
  }) async {

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return;
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return;
    final plane = image.planes.first;

    // compose InputImage using bytes
    final inputImage =  InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );

    processImage(inputImage);

  }

  Future<void> processImage(InputImage inputImage) async {

    if (_isBusy) return;
    _isBusy = true;

    try{
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if(faces.length == 1) {
        if((faces[0].rightEyeOpenProbability ?? 1) < 0.1 && (faces[0].leftEyeOpenProbability ?? 1) < 0.1 && _eyeBlink < 3) {
          _eyeBlink++;
        }
      }
    }catch(e) {
      debugPrint('error ===> $e');
    }

    if(_eyeBlink == 3) {
      try{
        await controller?.stopImageStream().then((value)async {
          _faceDetector.close();

          final XFile file =  await controller!.takePicture();
          compressXFile = await compressFile(File(file.path));
          _imageFile =  File(compressXFile!.path);
        });
      }catch(e){
        debugPrint('error is $e');
      }
      if(_imageFile != null) {
        final inputImage = InputImage.fromFilePath(_imageFile!.path);
        processPicture(inputImage);
      }
    }
    update();
    _isBusy = false;
  }

  Future<void> processPicture(InputImage inputImage) async {

    bool hasEyeOpen = false;
    final faces = await _faceDetector.processImage(inputImage);
    try{
      if(faces.length == 1) {
        if(faces[0].rightEyeOpenProbability != null && faces[0].leftEyeOpenProbability != null) {
          if(faces[0].rightEyeOpenProbability! > 0.2 && faces[0].leftEyeOpenProbability! > 0.2){
            hasEyeOpen = true;
          }
        }
      }
    }catch(e){
      debugPrint('error ---> $e');
    }

    if(hasEyeOpen || GetPlatform.isIOS) {
      Future.delayed(const Duration(seconds: 1)).then((value) async {
        await _faceDetector.close();
        Get.dialog(
            const FaceVerifyingDialog(),
            barrierDismissible: false
        );

        Response response = await faceVerificationServiceInterface.verifyDriverIdentity(compressXFile);
        stopLiveFeed();
        Get.find<ProfileController>().getProfileInfo();
        Get.offAll(()=> FaceVerificationResultScreen(
          isSuccess: response.statusCode == 200,
          message: response.body['message'],
        ));

      });


    }else{
      _isSuccess = false;
      update();
    }

  }

  Future<XFile> compressFile(File file) async {
    final filePath = file.absolute.path;

    XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, _generateCompressedFilePath(filePath),
      quality: 50,
    );

    return result!;
  }

  String _generateCompressedFilePath(String filePath) {
    final int lastDotIndex = filePath.lastIndexOf(RegExp(r'\.jp'));
    final String baseFileName = filePath.substring(0, lastDotIndex);
    final String fileExtension = filePath.substring(lastDotIndex);

    return "${baseFileName}_compressed$fileExtension";
  }


  void removeImage(){
    compressXFile = null;
    _imageFile = null;
    update();
  }

  Future stopLiveFeed() async {
    _isBusy = false;
    try{
      try{
        await controller?.stopImageStream();
      }catch(e) {
        debugPrint('error ---> $e');
      }
      await controller?.dispose();
      controller = null;
      valueInitialize();
    }catch(e){
      debugPrint('error is : $e');

    }
  }

  void valueInitialize() {
    _eyeBlink = 0;
    _isSuccess = true;
  }

  Future<void> requestCameraPermission() async {
    var serviceStatus = await Permission.camera.status;

    if(serviceStatus.isGranted && GetPlatform.isAndroid){
      Get.to(()=> FaceVerificationScreen());
    }else{
      if(GetPlatform.isIOS){
        Get.to(()=> FaceVerificationScreen());
      }else{
        final status = await Permission.camera.request();
        if (status == PermissionStatus.granted) {
          Get.to(()=> FaceVerificationScreen());
        } else if (status == PermissionStatus.denied) {
          showDeniedDialog();
        } else if (status == PermissionStatus.permanentlyDenied) {
          showPermanentlyDeniedDialog();
        }
      }

    }
  }

  void showDeniedDialog() {
    Get.defaultDialog(
      barrierDismissible: false,
      title: 'camera_permission'.tr,
      middleText: 'you_must_allow_permission_for_further_use'.tr,
      confirm: TextButton(onPressed: () async{
        Permission.camera.request().then((value) async{
          var status = await Permission.camera.status;
          if (status.isDenied) {
            Get.back();
            Permission.camera.request();

          }
          else if(status.isGranted){
          }
          else if(status.isPermanentlyDenied){
            return showPermanentlyDeniedDialog();
          }
        });


      }, child: Text('allow'.tr)),
    );

  }

  void showPermanentlyDeniedDialog() {
    Get.defaultDialog(
        barrierDismissible: false,
        title: 'camera_permission'.tr,
        middleText: 'you_must_allow_permission_for_further_use'.tr,
        confirm: TextButton(onPressed: () async {
          final serviceStatus = await Permission.camera.status;
          if(serviceStatus.isGranted){
            Get.off(()=> FaceVerificationScreen());
          }
          else{
            await openAppSettings().then((value)async{
              if(serviceStatus.isGranted){
                Get.to(()=> FaceVerificationScreen());
              }
              else{
                Get.back();
                showPermanentlyDeniedDialog();
              }
            });
          }

        }, child: Text('open_setting'.tr))
    );
  }

  void skipFaceVerification({bool fromVarificationScreen = false}) async{
    Response response = await faceVerificationServiceInterface.skipVerification();
    if(response.statusCode == 200){
      if(fromVarificationScreen){
        showCustomSnackBar('your_verification_failed_try_it_later'.tr);
      }
    }else{
      ApiChecker.checkApi(response);
    }
  }

}