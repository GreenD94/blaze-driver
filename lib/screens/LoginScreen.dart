import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:taxi_driver/screens/DriverDashboardScreen.dart';
import 'package:taxi_driver/utils/Constants.dart';
import 'package:taxi_driver/utils/Extensions/StringExtensions.dart';

import '../../main.dart';
import '../Services/AuthService.dart';
import '../components/OTPDialog.dart';
import '../model/UserDetailModel.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';
import 'DriverRegisterScreen.dart';
import 'ForgotPasswordScreen.dart';
import 'VerifyDeliveryPersonScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late UserData _userModel;

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  AuthServices authService = AuthServices();
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();

  FocusNode emailFocus = FocusNode();
  FocusNode passFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    // await saveOneSignalPlayerId();
    if (sharedPref.getString(PLAYER_ID).validate().isEmpty) {
      await saveOneSignalPlayerId().then((value) {
        //
      });
    }
  }

  Future<void> logIn() async {
    hideKeyboard(context);
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      appStore.setLoading(true);

      if (sharedPref.getString(PLAYER_ID).validate().isEmpty) {
        await saveOneSignalPlayerId().then((value) {
          //
        });
      }

      Map req = {
        'email': emailController.text.trim(),
        'password': passController.text.trim(),
        "player_id": sharedPref.getString(PLAYER_ID).validate(),
        'user_type': 'driver',
      };
      await logInApi(req).then((value) async {
        _userModel = value.data!;

        _auth.signInWithEmailAndPassword(email: emailController.text, password: passController.text).then((value) {
          if (sharedPref.getInt(IS_Verified_Driver) == 1) {
            launchScreen(context, DriverDashboardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          } else {
            launchScreen(context, VerifyDeliveryPersonScreen(isShow: true),
                isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          }
          appStore.isLoading = false;
        }).catchError((e) {
          if (e.toString().contains('user-not-found')) {
            authService.signUpWithEmailPassword(
              context,
              name: _userModel.firstName,
              mobileNumber: _userModel.contactNumber,
              email: emailController.text,
              fName: _userModel.firstName,
              lName: _userModel.lastName,
              userName: _userModel.username,
              password: passController.text,
              userType: 'driver',
              isExist: false,
              gender: _userModel.gender,
              serviceId: _userModel.serviceId,
              userDetail: UserDetail(
                carModel: '',
                carColor: '',
                carPlateNumber: '',
                carProductionYear: '',
              ),
            );
          } else {
            if (sharedPref.getInt(IS_Verified_Driver) == 1) {
              launchScreen(context, DriverDashboardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
            } else {
              launchScreen(context, VerifyDeliveryPersonScreen(isShow: true),
                  isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
            }
          }
          //toast(e.toString());
          log('${e.toString()}');
          log(e.toString());
        });
      }).catchError((error) {
        appStore.setLoading(false);

        toast(error.toString());
        log('${error.toString()}');
      });
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text(language.welcomeBack, style: boldTextStyle(size: 22)),
                  SizedBox(height: 8),
                  Text(language.signInYourAccount, style: primaryTextStyle()),
                  SizedBox(height: 32),
                  AppTextField(
                    controller: emailController,
                    nextFocus: passFocus,
                    autoFocus: false,
                    textFieldType: TextFieldType.EMAIL,
                    keyboardType: TextInputType.emailAddress,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context, label: language.email),
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: passController,
                    focus: passFocus,
                    autoFocus: false,
                    textFieldType: TextFieldType.PASSWORD,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context, label: language.password),
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.topRight,
                    child: inkWellWidget(
                      onTap: () {
                        hideKeyboard(context);
                        launchScreen(context, ForgotPasswordScreen(), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                      },
                      child: Text(language.forgotPassword, style: boldTextStyle()),
                    ),
                  ),
                  SizedBox(height: 20),
                  AppButtonWidget(
                    width: MediaQuery.of(context).size.width,
                    color: primaryColor,
                    textStyle: boldTextStyle(color: Colors.white),
                    text: language.logIn,
                    onTap: () async {
                      logIn();
                    },
                  ),
                  SizedBox(height: 20),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: primaryColor.withOpacity(0.5))),
                        Padding(
                          padding: EdgeInsets.only(left: 16, right: 16),
                          child: Text(language.orLogInWith, style: primaryTextStyle()),
                        ),
                        Expanded(child: Divider(color: primaryColor.withOpacity(0.5))),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: inkWellWidget(
                      onTap: () async {
                        showDialog(
                          context: context,
                          builder: (_) {
                            return AlertDialog(
                              contentPadding: EdgeInsets.all(16),
                              content: OTPDialog(),
                            );
                          },
                        );
                      },
                      child: Image.asset('images/ic_mobile.png', fit: BoxFit.cover, height: 35, width: 35),
                    ),
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(language.donHaveAnAccount, style: primaryTextStyle()),
                        SizedBox(width: 8),
                        inkWellWidget(
                          onTap: () {
                            hideKeyboard(context);
                            launchScreen(context, DriverRegisterScreen(), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                          },
                          child: Text(language.signUp, style: boldTextStyle(color: primaryColor)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Observer(
            builder: (context) {
              return Visibility(
                visible: appStore.isLoading,
                child: loaderWidgetLogIn(),
              );
            },
          ),
        ],
      ),
    );
  }
}
