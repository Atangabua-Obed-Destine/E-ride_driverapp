import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/verification_from_enum.dart';
import 'package:ride_sharing_user_app/features/auth/screens/biometric_login_screen.dart';
import 'package:ride_sharing_user_app/features/auth/screens/otp_log_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_up_screen.dart';
import 'package:ride_sharing_user_app/features/html/domain/html_enum_types.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/auth/screens/forgot_password_screen.dart';
import 'package:ride_sharing_user_app/features/html/screens/policy_viewer_screen.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/text_field_widget.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/auth_scaffold.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {

  TextEditingController passwordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  FocusNode phoneNode = FocusNode();
  FocusNode passwordNode = FocusNode();

  @override
  void initState() {
    if(Get.find<AuthController>().getUserNumber().isNotEmpty){
      phoneController.text =  Get.find<AuthController>().getUserNumber();
    }
    passwordController.text = Get.find<AuthController>().getUserPassword();
    if(passwordController.text != ''){
      Get.find<AuthController>().setRememberMe();
    }
    if(Get.find<AuthController>().getLoginCountryCode().isNotEmpty){
      Get.find<AuthController>().countryDialCode = Get.find<AuthController>().getLoginCountryCode();
    }else{
      Get.find<AuthController>().countryDialCode = Get.find<SplashController>().countryDialCode;
    }
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (res, val) async {
        Get.find<BottomMenuController>().exitApp();
        return;
      },
      child: GetBuilder<AuthController>(builder: (authController){
            return GetBuilder<ProfileController>(builder: (profileController) {
              return GetBuilder<RideController>(builder: (rideController) {
                return GetBuilder<LocationController>(builder: (locationController) {
                  return AuthScaffold(
                    title: 'login'.tr,
                    subtitle: 'log_in_message'.tr,
                    showBack: false,
                    showLockup: true,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TextFieldWidget(
                          hintText: 'enter_your_phone'.tr,
                          inputType: TextInputType.number,
                          countryDialCode: authController.countryDialCode,
                          controller: phoneController,
                          focusNode: phoneNode,
                          autoFocus: phoneController.text.isEmpty,
                          onCountryChanged: (CountryCode countryCode){
                            authController.countryDialCode = countryCode.dialCode!;
                            authController.setCountryCode(countryCode.dialCode!);
                            FocusScope.of(context).requestFocus(phoneNode);
                          },
                        ),
                        const SizedBox(height: Dimensions.paddingSizeDefault),

                        TextFieldWidget(
                          hintText: 'enter_your_password'.tr,
                          inputType: TextInputType.text,
                          prefixIcon: Images.lock,
                          inputAction: TextInputAction.done,
                          focusNode: passwordNode,
                          isPassword: true,
                          controller: passwordController,
                        ),

                        Row(children: [
                          InkWell(
                            onTap: () => authController.toggleRememberMe(),
                            child: Row(children: [
                              SizedBox(width: 20.0, child: Checkbox(
                                checkColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                activeColor: Theme.of(context).primaryColor.withValues(alpha: .125),
                                value: authController.isActiveRememberMe,
                                side: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: 0.5)),
                                onChanged: (bool? isChecked) => authController.toggleRememberMe(),
                              )),
                              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                              Text(
                                'remember'.tr,
                                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                              ),
                            ]),
                          ),

                          const Spacer(),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Get.to(()=>const ForgotPasswordScreen(from: VerificationForm.resetPassword)),
                              child: Text(
                                'forgot_password'.tr,
                                style: textMedium.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ]),

                        (authController.isLoading || authController.updateFcm ||
                            profileController.isLoading || rideController.isLoading ||
                            locationController.lastLocationLoading) ?
                        Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0)) :
                        ButtonWidget(
                          buttonText: 'login'.tr,
                          onPressed: (){
                            String phone = phoneController.text;
                            String password = passwordController.text;
                            if(phone.isEmpty){
                              showCustomSnackBar('phone_is_required'.tr);
                              FocusScope.of(context).requestFocus(phoneNode);
                            }else if(!GetUtils.isPhoneNumber(authController.countryDialCode + phone)){
                              showCustomSnackBar('phone_number_is_not_valid'.tr);
                              FocusScope.of(context).requestFocus(phoneNode);
                            }else if(password.isEmpty){
                              showCustomSnackBar('password_is_required'.tr);
                              FocusScope.of(context).requestFocus(passwordNode);
                            }else if(password.length<8){
                              showCustomSnackBar('minimum_password_length_is_8'.tr);
                              FocusScope.of(context).requestFocus(passwordNode);
                            }else{
                              authController.login(authController.countryDialCode,phone, password);
                            }
                          }, radius: 16, height: 52,
                        ),

                          if(Get.find<SplashController>().config?.driverLoginOptions?.otpLogin ?? false)...[
                            Center(child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 8),
                              child: Text('or'.tr , style: textRegular.copyWith(color: Theme.of(context).hintColor),
                              ),
                            )),

                            ButtonWidget(
                              showBorder: true,
                              borderWidth: 1,
                              transparent: true,
                              buttonText: 'login_with_otp'.tr,
                              onPressed: () => Get.to(() => const OtpLoginScreen(fromSignIn: true)),
                              radius: 16, height: 52,
                            )
                          ],

                        if(authController.isBiometricEnable && (Get.find<SplashController>().config?.driverLoginOptions?.biometricLogin ?? false))...[
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          ButtonWidget(
                            showBorder: true,
                            borderWidth: 1,
                            transparent: true,
                            buttonText: 'biometric_login'.tr,
                            onPressed: () => Get.to(() => const BiometricLoginScreen()),
                            radius: 16, height: 52,
                          ),
                        ],

                        const SizedBox(height: Dimensions.paddingSizeDefault),

                        Get.find<SplashController>().selfRegistrationEnabled ?
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(
                            '${'do_not_have_an_account'.tr} ',
                            style: textMedium.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).hintColor,
                            ),
                          ),

                          TextButton(
                            onPressed: () =>  Get.to(()=> const SignUpScreen()),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero, minimumSize: const Size(50,30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'sign_up'.tr,
                              style: textMedium.copyWith(
                                decoration: TextDecoration.underline,
                                color: Theme.of(context).primaryColor,
                                decorationColor: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ]) :
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text("${'to_create_account'.tr} "),

                          InkWell(
                            onTap: ()=>
                                Get.find<SplashController>().sendMailOrCall(
                                  "tel:${Get.find<SplashController>().config?.businessContactPhone}",
                                  false,
                                ),
                            child: Text(
                              "${'contact_support'.tr} ",
                              style: textRegular.copyWith(
                                color: Theme.of(context).primaryColor,
                                decoration: TextDecoration.underline,
                                decorationColor: Theme.of(context).primaryColor
                              ),
                            ),
                          ),
                        ]),
                        SizedBox(height: Dimensions.paddingSizeSmall),

                        Center(
                          child: InkWell(
                            onTap: ()=> Get.to(()=> const PolicyViewerScreen(htmlType: HtmlType.termsAndConditions)),
                            child: Padding(
                              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                              child: Text(
                                "terms_and_condition".tr,
                                style: textMedium.copyWith(
                                  decoration: TextDecoration.underline,
                                  color: Theme.of(context).primaryColor,
                                  decorationColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),

                      ]),
                  );
                });
              });
            });
          }),
    );
  }
}
