import 'dart:async';
import 'dart:convert';
//import 'dart:ui';
import 'dart:math';

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' hide AndroidResource;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'package:taxi_driver/Services/FloatingWindowService.dart';
import 'package:taxi_driver/components/ServiceDataWidget.dart';
import 'package:taxi_driver/screens/ChatScreen.dart';
import 'package:taxi_driver/screens/DetailScreen.dart';
import 'package:taxi_driver/screens/EditProfileScreen.dart';
import 'package:taxi_driver/screens/ReviewScreen.dart';
import 'package:taxi_driver/screens/VerifyDeliveryPersonScreen.dart';
import 'package:taxi_driver/utils/Extensions/StringExtensions.dart';
import 'package:taxi_driver/utils/Extensions/app_textfield.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soundpool/soundpool.dart';
import 'package:flutter_background/flutter_background.dart';

import '../components/AlertScreen.dart';
import '../components/DrawerWidget.dart';
import '../components/ExtraChargesWidget.dart';
import '../main.dart';
import '../model/CurrentRequestModel.dart';
import '../model/ExtraChargeRequestModel.dart';
import '../model/RiderModel.dart';
import '../model/UserDetailModel.dart';
import '../model/WalletDetailModel.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Images.dart';
import 'BankInfoScreen.dart';
import 'EmergencyContactScreen.dart';
import 'LocationPermissionScreen.dart';
import 'MyRidesScreen.dart';
import 'MyWalletScreen.dart';
import 'NotificationScreen.dart';
import 'SettingScreen.dart';
import 'VehicleScreen.dart';

@pragma('vm:entry-point')
void callBack(String tag) {
  WidgetsFlutterBinding.ensureInitialized();
  print(tag);
  switch (tag) {
    case "simple_button":
    case "updated_simple_button":
      SystemAlertWindow.closeSystemWindow(prefMode: SystemWindowPrefMode.OVERLAY);
      break;
    case "focus_button":
      FlutterForegroundTask.launchApp();
      SystemAlertWindow.closeSystemWindow(prefMode: SystemWindowPrefMode.OVERLAY);
      print("Focus button has been called");
      break;
    default:
      print("OnClick event of $tag");
  }
}

class DriverDashboardScreen extends StatefulWidget {
  @override
  DriverDashboardScreenState createState() => DriverDashboardScreenState();
}

class DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Completer<GoogleMapController> _controller = Completer();
  OtpFieldController otpController = OtpFieldController();
  late StreamSubscription<ServiceStatus> serviceStatusStream;

  List<RiderModel> riderList = [];
  OnRideRequest? servicesListData;
  List<OnRideRequest> rideRequests = [];

  UserData? riderData;
  WalletDetailModel? walletDetailModel;

  LatLng? userLatLong;
  final Set<Marker> markers = {};
  Set<Polyline> _polyLines = Set<Polyline>();
  late PolylinePoints polylinePoints;
  List<LatLng> polylineCoordinates = [];

  List<ExtraChargeRequestModel> extraChargeList = [];
  num extraChargeAmount = 0;
  late StreamSubscription<Position> positionStream;
  LocationPermission? permissionData;

  LatLng? driverLocation;
  LatLng? sourceLocation;
  LatLng? destinationLocation;

  bool isOffLine = false;
  String? otpCheck;
  String endLocationAddress = '';
  double totalDistance = 0.0;

  late BitmapDescriptor driverIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor sourceIcon;

  Timer? timerData;
  int startTime = 60;
  int end = 0;
  int duration = 0;
  int riderId = 0;

  bool locationEnable = true;
  Timer? timerUpdateLocation;

  TextEditingController feeController = TextEditingController();

  bool isInProgress = false;

  final StreamController<List<OnRideRequest>> _requestsStreamController = StreamController<List<OnRideRequest>>();
  Stream<List<OnRideRequest>> get requestsStream => _requestsStreamController.stream;

  BuildContext? dialogContext;
  OverlayEntry? entry;

  FloatingWindowService windowService = FloatingWindowService();

  bool isOffering = false;
  List<OnRideRequest> rejectedRides = [];

  double? usdRate;

  double? driverMarkerRotation;
  LatLng? driverLatitudeLocation;

  @override
  void initState() {
    super.initState();
    init();
    locationPermission();

    log(servicesListData);
    if (sharedPref.getInt(IS_ONLINE) == 1) {
      isOffLine = true;
    }
  }

  void init() async {
    walletCheckApi();
    driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    mqttForUser();
    setTimeData();
    polylinePoints = PolylinePoints();

    // await initBackground();

    await getAppSetting().then((value) {
      if (value.walletSetting!.isNotEmpty) {
        appStore.setWalletPresetTopUpAmount(
            value.walletSetting!.firstWhere((element) => element.key == PRESENT_TOPUP_AMOUNT).value ?? '10|20|30');
      }
      if (value.rideSetting!.isNotEmpty) {
        appStore.setWalletTipAmount(
            value.rideSetting!.firstWhere((element) => element.key == PRESENT_TIP_AMOUNT).value ?? '10|20|30');
      }

      startTime = int.parse(value.rideSetting!.firstWhere((element) => element.key == MAX_TIME_FOR_DRIVER_SECOND).value ?? '60');

      if (value.currencySetting != null) {
        appStore.setCurrencyCode(value.currencySetting!.symbol ?? currencySymbol);
        appStore.setCurrencyName(value.currencySetting!.code ?? currencyNameConst);
        appStore.setCurrencyPosition(value.currencySetting!.position ?? LEFT);
      }

      if (value.walletSetting!.firstWhere((element) => element.key == MIN_AMOUNT_TO_ADD).value != null)
        appStore
            .setMinAmountToAdd(int.parse(value.walletSetting!.firstWhere((element) => element.key == MIN_AMOUNT_TO_ADD).value!));
      if (value.walletSetting!.firstWhere((element) => element.key == MAX_AMOUNT_TO_ADD).value != null)
        appStore
            .setMaxAmountToAdd(int.parse(value.walletSetting!.firstWhere((element) => element.key == MAX_AMOUNT_TO_ADD).value!));

      appStore.setExchangeRate(value.usdRate ?? 0.0);
      usdRate = appStore.exchangeRate?.toDouble();
    }).catchError((error) {
      log('${error.toString()}');
    });
    driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
    destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);
    getCurrentRequest();
    if (appStore.isLoggedIn) {
      startLocationTracking();
    }
    setSourceAndDestinationIcons();
    await getAppSetting().then((value) {
      appStore.setWalletPresetTopUpAmount(
          value.walletSetting!.firstWhere((element) => element.key == "preset_topup_amount").value ?? '10|20|30');
      markers.add(
        Marker(
          markerId: MarkerId("DeliveryBoy"),
          position: driverLocation!,
          icon: driverIcon,
          infoWindow: InfoWindow(title: ''),
        ),
      );
    }).catchError((error) {
      log('${error.toString()}');
    });

    await windowService.requestPermissions();

    SystemAlertWindow.registerOnClickListener(callBack);

    await initBackground();
  }

  Future<void> locationPermission() async {
    serviceStatusStream = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        locationEnable = false;
        launchScreen(navigatorKey.currentState!.overlay!.context, LocationPermissionScreen());
      } else if (status == ServiceStatus.enabled) {
        locationEnable = true;
        startLocationTracking();

        if (Navigator.canPop(navigatorKey.currentState!.overlay!.context)) {
          Navigator.pop(navigatorKey.currentState!.overlay!.context);
        }
      }
    });
  }

  Future<void> setTimeData() async {
    if (sharedPref.getString(IS_TIME2) == null) {
      duration = startTime;
      sharedPref.setString(IS_TIME2, DateTime.now().add(Duration(seconds: startTime)).toString());
    } else {
      duration = DateTime.parse(sharedPref.getString(IS_TIME2)!).difference(DateTime.now()).inSeconds;
      if (duration > 0) {
        if (sharedPref.getString(ON_RIDE_MODEL) != null) {
          servicesListData = OnRideRequest.fromJson(jsonDecode(sharedPref.getString(ON_RIDE_MODEL)!));

          setState(() {});
        }

        startTimer();
      } else {
        //timerData!.cancel();
        sharedPref.remove(IS_TIME2);
        duration = startTime;
        setState(() {});
      }
    }
  }

  Future<void> startTimer() async {
    const oneSec = const Duration(seconds: 1);
    timerData = new Timer.periodic(
      oneSec,
      (Timer timer) {
        if (duration == 0) {
          duration = startTime;
          timer.cancel();
          sharedPref.remove(ON_RIDE_MODEL);
          sharedPref.remove(IS_TIME2);
          servicesListData = null;
          _polyLines.clear();
          setMapPins();
          setState(() {});
          Future.delayed(Duration(seconds: 4)).then((value) {
            Map req = {
              "id": riderId,
            };
            rideRequestResPond(request: req).then((value) {}).catchError((error) {
              log(error.toString());
            });
          });
        } else {
          setState(() {
            duration--;
          });
        }
      },
    );
  }

  Future<void> setSourceAndDestinationIcons() async {
    driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    if (servicesListData != null)
      servicesListData!.status != IN_PROGRESS
          ? sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), SourceIcon)
          : destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);
  }

  onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  Future<void> driverStatus({int? status}) async {
    appStore.setLoading(true);
    Map req = {
      "status": "active",
      "is_online": status,
    };
    await updateStatus(req).then((value) {
      sharedPref.setInt(IS_ONLINE, value.data!.isOnline!);
      setState(() {});
      appStore.setLoading(false);
    }).catchError((error) {
      appStore.setLoading(false);

      log(error.toString());
    });
  }

  Future<void> getCurrentRequest() async {
    appStore.setLoading(true);
    await getCurrentRideRequest().then((value) async {
      appStore.setLoading(false);
      if (value.onRideRequest != null) {
        servicesListData = value.onRideRequest;

        userDetail(driverId: value.onRideRequest!.riderId);

        setState(() {});

        if (servicesListData != null) {
          if (servicesListData!.status == COMPLETED && servicesListData!.isDriverRated == 0) {
            launchScreen(context, ReviewScreen(rideId: value.onRideRequest!.id!, currentData: value),
                pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
          } else if (value.payment != null && value.payment!.paymentStatus == PENDING) {
            launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
          } else if (servicesListData!.status != DRIVERS_OFFERING) {
            isOffering = false;
          } else if (servicesListData!.status == DRIVERS_OFFERING) {
            isOffering = true;
          }
        }
      } else {
        if (value.payment != null && value.payment!.paymentStatus == PENDING) {
          launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
        }
      }
      await changeStatus();
    }).catchError((error) {
      toast(error.toString());

      appStore.setLoading(false);

      // servicesListData = null;
      setState(() {});
    });
  }

  Future<void> rideRequest({String? status}) async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData?.id,
      "status": status,
    };
    await rideRequestUpdate(request: req, rideId: servicesListData?.id).then((value) async {
      appStore.setLoading(false);
      getCurrentRequest().then((value) async {
        _polyLines.clear();
        setMapPins();
        setState(() {});
      });
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> rideRequestAccept({bool deCline = false, bool isExpress = false}) async {
    appStore.setLoading(true);
    // appStore.setLoading(false);

    if (servicesListData != null) {
      Map req = {
        "id": servicesListData?.id,
        if (!deCline) "driver_id": sharedPref.getInt(USER_ID),
        "is_accept": deCline ? "0" : "1",
        "is_express": isExpress ? "1" : "0",
        "proposed_fee": feeController.text != "" ? double.parse(feeController.text.trim()) : 0.0,
      };

      await rideRequestResPond(request: req).then((value) async {
        appStore.setLoading(false);

        if (servicesListData != null && servicesListData?.status != DRIVERS_OFFERING) {
          getCurrentRequest();
        }

        if (!isExpress) {
          isOffering = true;
        }

        if (deCline) {
          servicesListData = null;
          _polyLines.clear();
          sharedPref.remove(ON_RIDE_MODEL);
          sharedPref.remove(IS_TIME2);
          setMapPins();
          //setState(() {});
        }
      }).catchError((error) {
        appStore.setLoading(false);
        log(error.toString());
        toast(
            'Estamos experimentando dificultades técnicas relacionadas a la conexión a Internet. Verifique su conexión he intente de nuevo más tarde.');
      });
    } else {
      toast('Solicitud no disponible');
    }
  }

  Future<void> completeRideRequest() async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData!.id,
      "service_id": servicesListData!.serviceId,
      "end_latitude": driverLocation!.latitude,
      "end_longitude": driverLocation!.longitude,
      "end_address": endLocationAddress,
      "distance": totalDistance,
      if (extraChargeList.isNotEmpty) "extra_charges": extraChargeList,
      if (extraChargeList.isNotEmpty) "extra_charges_amount": extraChargeAmount,
    };
    log(req);
    await completeRide(request: req).then((value) async {
      sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
      appStore.setLoading(false);
      getCurrentRequest();
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> setPolyLines() async {
    if (servicesListData != null) _polyLines.clear();
    polylineCoordinates.clear();
    // var result = await polylinePoints.getRouteBetweenCoordinates(
    //   googleMapAPIKey,
    //   PointLatLng(driverLocation!.latitude, driverLocation!.longitude),
    //   servicesListData!.status != IN_PROGRESS
    //       ? PointLatLng(
    //           double.parse(servicesListData!.startLatitude.validate()), double.parse(servicesListData!.startLongitude.validate()))
    //       : PointLatLng(
    //           double.parse(servicesListData!.endLatitude.validate()), double.parse(servicesListData!.endLongitude.validate())),
    // );
    // if (result.points.isNotEmpty) {
    //   result.points.forEach((element) {
    //     polylineCoordinates.add(LatLng(element.latitude, element.longitude));
    //   });
    //   _polyLines.add(
    //     Polyline(
    //       visible: true,
    //       width: 5,
    //       polylineId: PolylineId('poly'),
    //       color: Color.fromARGB(255, 40, 122, 198),
    //       points: polylineCoordinates,
    //     ),
    //   );
    //   setState(() {});
    // }
  }

  Future<void> setMapPins() async {
    markers.clear();

    ///source pin
    MarkerId id = MarkerId("DeliveryBoy");
    markers.remove(id);
    // markers.add(
    //   Marker(
    //     markerId: id,
    //     position: driverLocation!,
    //     icon: driverIcon,
    //     infoWindow: InfoWindow(title: ''),
    //   ),
    // );

    //

    // if (rideRequest!.status == ACCEPTED || rideRequest!.status == ARRIVING || rideRequest!.status == ARRIVED) {
    //   _centerMap(newDriverLocation, widget.sourceLatLog);
    // } else {
    //   _centerMap(newDriverLocation, widget.destinationLatLog);
    // }

    //

    if (servicesListData != null)
      servicesListData!.status != IN_PROGRESS
          ? markers.add(
              Marker(
                markerId: MarkerId('sourceLocation'),
                position: LatLng(double.parse(servicesListData!.startLatitude!), double.parse(servicesListData!.startLongitude!)),
                icon: sourceIcon,
                infoWindow: InfoWindow(title: servicesListData!.startAddress),
              ),
            )
          : markers.add(
              Marker(
                markerId: MarkerId('destinationLocation'),
                position: LatLng(double.parse(servicesListData!.endLatitude!), double.parse(servicesListData!.endLongitude!)),
                icon: destinationIcon,
                infoWindow: InfoWindow(title: servicesListData!.endAddress),
              ),
            );
  }

  /// Get Current Location
  Future<void> startLocationTracking() async {
    _polyLines.clear();
    polylineCoordinates.clear();
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((value) async {
      await Geolocator.isLocationServiceEnabled().then((value) async {
        if (locationEnable) {
          positionStream = Geolocator.getPositionStream().listen((event) async {
            if (appStore.isLoggedIn) {

              Future.delayed(Duration(seconds: 12)).then((value) async {

                LatLng newDriverLocation = LatLng(event.latitude, event.longitude);

                if (driverLatitudeLocation != null) {
                  await animateMarkerSmoothly(driverLatitudeLocation!, newDriverLocation, Duration(seconds: 10));
                } else {
                  driverLatitudeLocation = newDriverLocation;
                }

                if (servicesListData!=null) {
                  if (servicesListData!.status == ACCEPTED || servicesListData!.status == ARRIVING || servicesListData!.status == ARRIVED) {
                    _centerMap(newDriverLocation, LatLng(servicesListData!.startLatitude.toDouble(), servicesListData!.startLongitude.toDouble()));
                  } else {
                    _centerMap(newDriverLocation, LatLng(servicesListData!.endLatitude.toDouble(), servicesListData!.endLongitude.toDouble()));
                  }  
                } else {
                  CameraUpdate cameraUpdate = CameraUpdate.newLatLngZoom(newDriverLocation, 20);
                  final GoogleMapController mapController = await _controller.future;
                  await mapController.animateCamera(cameraUpdate);
                }

                // CameraUpdate cameraUpdate = CameraUpdate.newLatLngZoom(newDriverLocation, 14);
                //   final GoogleMapController mapController = await _controller.future;
                //   await mapController.animateCamera(cameraUpdate);

              });

              driverLocation = LatLng(event.latitude, event.longitude);
              Map req = {
                "status": "active",
                "latitude": driverLocation!.latitude.toString(),
                "longitude": driverLocation!.longitude.toString(),
              };

              await updateStatus(req).then((value) {
                setState(() {});
              }).catchError((error) {
                log(error);
              });

              await getPendingRideRequests(req).then((values) {
                List<OnRideRequest> rides = values.data!;
                rejectedRides.forEach((rejectedRide) {
                  rides.removeWhere(
                    (ride) => ride.id == rejectedRide.id,
                  );
                });
                rideRequests.clear();
                rideRequests.addAll(rides);
                setState(() {});
              }).catchError((error) {
                log(error);
              });

              setMapPins();
              _polyLines.clear();
              polylineCoordinates.clear();
              if (servicesListData != null) setMapPins();
              if (servicesListData != null) setPolyLines();
            }
          }, onError: (error) {
            positionStream.cancel();
          });
        }
      });
    }).catchError((error) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LocationPermissionScreen()));
    });
  }

  Future<void> userDetail({int? driverId}) async {
    await getUserDetail(userId: driverId).then((value) {
      appStore.setLoading(false);
      riderData = value.data!;
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

  mqttForUser() async {
    client.setProtocolV311();
    client.logging(on: true);
    client.keepAlivePeriod = 120;
    client.autoReconnect = true;

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      debugPrint(e.toString());
      client.connect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.onSubscribed = onSubscribed;

      log('connected');
      debugPrint('connected');
    } else {
      client.connect();
    }

    void onconnected() {
      debugPrint('connected');
    }

    client.subscribe('new_ride_request_' + sharedPref.getInt(USER_ID).toString(), MqttQos.atLeastOnce);
    client.subscribe('ride_request_status_' + sharedPref.getInt(USER_ID).toString(), MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) async {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      OnRideRequest rideRequest = OnRideRequest.fromJson(jsonDecode(pt)['result']);

      log('${jsonDecode(pt)['result']}');
      // log('MQTT_BACKGROUND: recibido');

      if (jsonDecode(pt)['success_type'] == "new_ride_requested") {
        servicesListData = OnRideRequest.fromJson(jsonDecode(pt)['result']);

        _playNotificationSound();

        addOrUpdateRideRequests(rideRequest);

        sharedPref.setString(ON_RIDE_MODEL, jsonEncode(servicesListData));
        riderId = servicesListData!.id!;
        sharedPref.remove(IS_TIME2);
        setTimeData();
        startTimer();

      } else if (jsonDecode(pt)['success_type'] == "canceled") {

        sharedPref.remove(ON_RIDE_MODEL);
        sharedPref.remove(IS_TIME2);

        servicesListData = null;
        rideRequests.removeWhere((element) => element.id == rideRequest.id);
        rejectedRides.add(servicesListData!);

        SystemAlertWindow.closeSystemWindow(prefMode: SystemWindowPrefMode.OVERLAY);

        if (dialogContext != null) {
          Navigator.pop(dialogContext!);
        }

        if (timerData != null) timerData!.cancel();
        _polyLines.clear();
        setMapPins();
        setState(() {});


      } else if (jsonDecode(pt)['success_type'] == 'accepted') {
        servicesListData = OnRideRequest.fromJson(jsonDecode(pt)['result']);
        rideRequests.clear();
        riderId = servicesListData!.id!;
        isInProgress = true;
      } else if (jsonDecode(pt)['success_type'] == 'driver_offer') {
        setTimeData();
        startTimer();
      } else if (jsonDecode(pt)['success_type'] == COMPLETED) {
        launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      }

      if (jsonDecode(pt)['result']['status'] == CANCELED || jsonDecode(pt)['result']['status'] == 'rejected-by-rider') {
        rejectedRides.add(servicesListData!);
        servicesListData = null;
        riderId = 0;
        isInProgress = false;
        isOffering = false;
        rideRequests.removeWhere((element) => element.id == rideRequest.id);
      }

      log('$pt');
    });

    client.onConnected = onconnected;
  }

  void onConnected() {
    log('Connected');
  }

  void onSubscribed(String topic) {
    log('Subscription confirmed for topic $topic');
  }

  Future<void> changeStatus() async {
    if (servicesListData == null) {
      Map req = {
        "is_available": 1,
      };
      updateStatus(req).then((value) {
        //
      });
    } else {
      Map req = {
        "is_available": 1,
      };
      updateStatus(req).then((value) {
        //
      });
    }
  }

  /// WalletCheck
  Future<void> walletCheckApi() async {
    await walletDetailApi().then((value) async {
      if (value.totalAmount! >= value.minAmountToGetRide!) {
        //
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
              content: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(walletGIF, height: 150, fit: BoxFit.contain),
                    SizedBox(height: 8),
                    Text(language.walletLessAmountMsg, style: primaryTextStyle(), textAlign: TextAlign.justify),
                    SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: AppButtonWidget(
                            padding: EdgeInsets.zero,
                            color: Colors.red,
                            text: language.no,
                            textColor: Colors.white,
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: AppButtonWidget(
                            padding: EdgeInsets.zero,
                            color: primaryColor,
                            text: language.yes,
                            textColor: Colors.white,
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    if (timerData != null) {
      timerData!.cancel();
    }
    if (timerData == null) {
      sharedPref.getString(IS_TIME2);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Map req = {
          "is_available": 0,
        };
        updateStatus(req).then((value) {
          //
        });
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        key: _scaffoldKey,
        drawer: Drawer(
          backgroundColor: primaryColor,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(left: 16, right: 16, top: 40, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                ),
                Container(
                  padding: EdgeInsets.only(top: 16, bottom: 16, right: 8),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(defaultRadius)),
                  child: Row(
                    children: [
                      Observer(builder: (context) {
                        return Expanded(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: commonCachedNetworkImage(appStore.userProfile.validate(),
                                    height: 60, width: 60, fit: BoxFit.cover),
                              ),
                            ],
                          ),
                        );
                      }),
                      SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            sharedPref.getString(LOGIN_TYPE) != 'mobile' && sharedPref.getString(LOGIN_TYPE) != null
                                ? Text(sharedPref.getString(USER_NAME).validate(), style: boldTextStyle(color: Colors.white))
                                : Text(appStore.firstName, style: boldTextStyle(color: Colors.white)),
                            SizedBox(height: 4),
                            Text(appStore.userEmail, style: secondaryTextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                DrawerWidget(
                    title: language.myProfile,
                    iconData: 'images/ic_my_profile.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EditProfileScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.myRides,
                    iconData: 'images/ic_my_rides.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, MyRidesScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.vehicleInfo,
                    iconData: 'images/ic_vehical_detail.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, VehicleScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.myWallet,
                    iconData: "images/my_wallet.png",
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, MyWalletScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.emergencyContacts,
                    iconData: 'images/ic_emergency_contact.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EmergencyContactScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.verifyDocument,
                    iconData: 'images/ic_verify_document.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, VerifyDeliveryPersonScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.bankInfo,
                    iconData: 'images/ic_update_bank_info.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, BankInfoScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.setting,
                    iconData: 'images/ic_setting.png',
                    onTap: () {
                      launchScreen(context, SettingScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                SizedBox(height: 16),
                Center(
                  child: AppButtonWidget(
                    text: language.logOut,
                    textStyle: boldTextStyle(color: primaryColor),
                    onTap: () async {
                      await showConfirmDialogCustom(_scaffoldKey.currentState!.context,
                          primaryColor: primaryColor,
                          dialogType: DialogType.CONFIRMATION,
                          title: language.areYouSureYouWantToLogoutThisApp,
                          positiveText: language.yes,
                          negativeText: language.no, onAccept: (v) async {
                        await Future.delayed(Duration(milliseconds: 500));
                        await logout(data: _scaffoldKey.currentState!.context);
                      });
                    },
                  ),
                )
              ],
            ),
          ),
        ),
        appBar: AppBar(
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () {
                  launchScreen(context, NotificationScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                },
                icon: Icon(Icons.notifications_active_outlined),
              ),
            ),
          ],
        ),
        body: driverLocation != null
            ? Stack(
                children: [
                  GoogleMap(
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationEnabled: true,
                    onMapCreated: onMapCreated,
                    initialCameraPosition: CameraPosition(target: driverLocation!, zoom: 11.0),
                    markers: markers,
                    mapType: MapType.normal,
                    polylines: _polyLines,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
                    child: FlutterSwitch(
                      value: isOffLine,
                      width: 90,
                      height: 35,
                      toggleSize: 25,
                      borderRadius: 30.0,
                      padding: 4.0,
                      inactiveText: language.offLine,
                      activeText: language.online,
                      showOnOff: true,
                      activeTextColor: Colors.green,
                      inactiveTextColor: Colors.black,
                      activeIcon: ImageIcon(AssetImage('images/ic_green_car.png'), color: Colors.white, size: 40),
                      inactiveIcon: ImageIcon(AssetImage('images/ic_red_car.png'), color: Colors.white, size: 40),
                      activeColor: Colors.white,
                      activeToggleColor: Colors.green,
                      inactiveToggleColor: Colors.red,
                      inactiveColor: Colors.white,
                      onToggle: (value) async {
                        await showConfirmDialogCustom(
                            dialogType: DialogType.CONFIRMATION,
                            primaryColor: primaryColor,
                            title: isOffLine ? language.youAreOfflineNow : language.youAreOnlineNow,
                            context, onAccept: (v) {
                          driverStatus(status: isOffLine ? 0 : 1);
                          isOffLine = value;
                          setState(() {});
                        });
                      },
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    // bottom: 0,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1),
                          ],
                          borderRadius: BorderRadius.circular(defaultRadius),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              alignment: Alignment.center,
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(color: isOffLine ? Colors.green : Colors.grey, shape: BoxShape.circle),
                            ),
                            Text(isOffLine ? language.youAreOnlineNow : language.youAreOfflineNow,
                                style: secondaryTextStyle(color: primaryColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isInProgress)
                    SlidingUpPanel(
                      padding: EdgeInsets.all(8),
                      // padding: EdgeInsets.fromLTRB(8, 8, 16, 16),
                      borderRadius:
                          BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius)),
                      backdropColor: primaryColor,
                      backdropTapClosesPanel: true,
                      minHeight: rideRequests.length == 0 ? 0 : 130,
                      maxHeight: 800,
                      // header: Center(
                      //   child: Container(
                      //     alignment: Alignment.center,
                      //     // margin: EdgeInsets.only(bottom: 16),
                      //     height: 5,
                      //     width: 70,
                      //     decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                      //   ),
                      // ),

                      // header: Container(
                      //   // constraints: BoxConstraints(minHeight: 10, maxHeight: 10),
                      //   child: Column(
                      //       mainAxisAlignment: MainAxisAlignment.center,
                      //       crossAxisAlignment: CrossAxisAlignment.center,
                      //       children: [
                      //         Center(
                      //           child: Container(
                      //             alignment: Alignment.center,
                      //             // margin: EdgeInsets.only(bottom: 16),
                      //             height: 5,
                      //             width: 70,
                      //             decoration:
                      //                 BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                      //           ),
                      //         ),
                      //         Center(
                      //           child: Text('Solicitudes (' + rideRequests.length.toString() + ')'),
                      //         ),
                      //         // SizedBox(height: 30),
                      //       ]),
                      // ),

                      panelBuilder: (ScrollController sc) => ListView.builder(
                        itemCount: rideRequests.length,
                        // prototypeItem: ListTile(
                        //   title: Text('rideRequests.first.riderName.toString()'),
                        // ),
                        itemBuilder: (context, index) {
                          OnRideRequest request = rideRequests[index];
                          return Column(
                            children: [
                              if (index == 0)
                                Column(
                                  children: [
                                    Center(
                                      child: Container(
                                        alignment: Alignment.center,
                                        margin: EdgeInsets.only(bottom: 8),
                                        height: 5,
                                        width: 70,
                                        decoration: BoxDecoration(
                                            color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                      ),
                                    ),
                                    Text('Solicitudes (${rideRequests.length.toString()})')
                                  ],
                                ),
                              //   Container(
                              //     // constraints: BoxConstraints(minHeight: 10, maxHeight: 10),
                              //     child: Column(
                              //         mainAxisAlignment: MainAxisAlignment.center,
                              //         crossAxisAlignment: CrossAxisAlignment.center,
                              //         children: [
                              //           Center(
                              //             child: Container(
                              //               alignment: Alignment.center,
                              //               // margin: EdgeInsets.only(bottom: 16),
                              //               height: 5,
                              //               width: 70,
                              //               decoration: BoxDecoration(
                              //                   color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                              //             ),
                              //           ),
                              //           Center(
                              //             child: Text('Solicitudes (' + rideRequests.length.toString() + ')'),
                              //           ),
                              //           // SizedBox(height: 30),
                              //         ]),
                              //   ),
                              InkWell(
                                  onTap: () {
                                    servicesListData = request;
                                    sharedPref.setString(ON_RIDE_MODEL, jsonEncode(servicesListData));
                                    riderId = servicesListData!.id!;
                                    sharedPref.remove(IS_TIME2);
                                    feeController.text = servicesListData!.proposedFee.toString().validate();
                                    setTimeData();
                                    startTimer();
                                    // openMaps(request.startAddress.toString(), request.endAddress.toString());
                                    // openMaps(request.startLatitude.toString(), request.startLongitude.toString(),
                                    //     request.endLatitude.toString(), request.endLongitude.toString());
                                  },
                                  child: Card(
                                      child: Column(children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(defaultRadius),
                                              child: commonCachedNetworkImage(request.riderProfileImage,
                                                  height: 35, width: 35, fit: BoxFit.cover),
                                            ),
                                            SizedBox(width: 80),
                                            Text('${request.riderName}', style: boldTextStyle(size: 10)),
                                            Text(
                                              toCurrency(request.proposedFee!),
                                              style: TextStyle(fontSize: 20),
                                            ),
                                            if (request.modality == 'express')
                                              Text(
                                                'Express',
                                                style: TextStyle(fontSize: 12),
                                              )
                                          ],
                                        ),
                                        SizedBox(
                                          width: 12,
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Column(
                                            children: [
                                              Icon(Icons.near_me, color: Colors.green),
                                              SizedBox(height: 4),
                                              SizedBox(
                                                height: 30,
                                                child: DottedLine(
                                                  direction: Axis.vertical,
                                                  lineLength: double.infinity,
                                                  lineThickness: 2,
                                                  dashColor: primaryColor,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Icon(Icons.location_on, color: Colors.red),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(bottom: 0, top: 14),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(request.startAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2),
                                                SizedBox(height: 8),
                                                Text(request.endAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2),
                                              ],
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ]))),
                            ],
                          );
                        },
                      ),

                    ),
                  servicesListData != null
                      ? servicesListData!.status != null &&
                              (servicesListData!.status == NEW_RIDE_REQUESTED || servicesListData!.status == 'rejected-by-rider')
                          ? SizedBox.expand(
                              child: Stack(
                                children: [
                                  DraggableScrollableSheet(
                                    initialChildSize: 0.50,
                                    minChildSize: 0.50,
                                    builder: (
                                      BuildContext context,
                                      ScrollController scrollController,
                                    ) {
                                      scrollController.addListener(() {
                                        //
                                      });
                                      return servicesListData != null
                                          ? Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.only(
                                                    topLeft: Radius.circular(defaultRadius),
                                                    topRight: Radius.circular(defaultRadius)),
                                              ),
                                              child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Align(
                                                      alignment: Alignment.center,
                                                      child: Container(
                                                        margin: EdgeInsets.only(top: 16),
                                                        height: 6,
                                                        width: 60,
                                                        decoration: BoxDecoration(
                                                            color: primaryColor,
                                                            borderRadius: BorderRadius.circular(defaultRadius)),
                                                        alignment: Alignment.center,
                                                      ),
                                                    ),
                                                    SizedBox(height: 16),
                                                    Padding(
                                                      padding: EdgeInsets.only(left: 16),
                                                      child: Text(language.requests, style: primaryTextStyle(size: 18)),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Container(
                                                      margin: EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
                                                      width: MediaQuery.of(context).size.width,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(defaultRadius),
                                                        boxShadow: [
                                                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3),
                                                        ],
                                                      ),
                                                      child: Padding(
                                                        padding: EdgeInsets.all(8),
                                                        child: Column(
                                                          children: [
                                                            Row(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                ClipRRect(
                                                                  borderRadius: BorderRadius.circular(defaultRadius),
                                                                  child: commonCachedNetworkImage(
                                                                      servicesListData!.riderProfileImage.validate(),
                                                                      height: 35,
                                                                      width: 35,
                                                                      fit: BoxFit.cover),
                                                                ),
                                                                SizedBox(width: 12),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text('${servicesListData!.riderName}',
                                                                          style: boldTextStyle(size: 14)),
                                                                      SizedBox(height: 4),
                                                                      Text('${servicesListData!.riderEmail.validate()}',
                                                                          style: secondaryTextStyle()),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                      color: primaryColor,
                                                                      borderRadius: BorderRadius.circular(defaultRadius)),
                                                                  padding: EdgeInsets.all(6),
                                                                  child: Text("$duration",
                                                                      style: boldTextStyle(color: Colors.white)),
                                                                )
                                                              ],
                                                            ),
                                                            SizedBox(height: 16),
                                                            Divider(
                                                                color: Colors.grey.withOpacity(0.5),
                                                                height: 0,
                                                                indent: 15,
                                                                endIndent: 15),
                                                            InkWell(
                                                                onTap: () {
                                                                  openMaps(
                                                                      servicesListData!.startLatitude.toString(),
                                                                      servicesListData!.startLongitude.toString(),
                                                                      servicesListData!.endLatitude.toString(),
                                                                      servicesListData!.endLongitude.toString());
                                                                },
                                                                child: Row(
                                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    Padding(
                                                                      padding: EdgeInsets.only(top: 8),
                                                                      child: Column(
                                                                        children: [
                                                                          Icon(Icons.near_me, color: Colors.green),
                                                                          SizedBox(height: 4),
                                                                          SizedBox(
                                                                            height: 30,
                                                                            child: DottedLine(
                                                                              direction: Axis.vertical,
                                                                              lineLength: double.infinity,
                                                                              lineThickness: 2,
                                                                              dashColor: primaryColor,
                                                                            ),
                                                                          ),
                                                                          SizedBox(height: 4),
                                                                          Icon(Icons.location_on, color: Colors.red),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    SizedBox(width: 16),
                                                                    Expanded(
                                                                      child: Padding(
                                                                        padding: EdgeInsets.only(bottom: 0, top: 14),
                                                                        child: Column(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(servicesListData!.startAddress ?? '',
                                                                                style: primaryTextStyle(size: 14), maxLines: 2),
                                                                            SizedBox(height: 8),
                                                                            Text(servicesListData!.endAddress ?? '',
                                                                                style: primaryTextStyle(size: 14), maxLines: 2),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Column(
                                                                      children: [
                                                                        Icon(
                                                                          Icons.map,
                                                                          size: 40,
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ],
                                                                )),
                                                            SizedBox(height: 8),
                                                            Divider(
                                                                color: Colors.grey.withOpacity(0.5),
                                                                height: 0,
                                                                indent: 15,
                                                                endIndent: 15),
                                                            SizedBox(height: 8),
                                                            if (servicesListData!.modality == 'auction')
                                                              Column(
                                                                children: [
                                                                  SizedBox(height: 8),
                                                                  Text('Proponer Tarifa', style: primaryTextStyle()),
                                                                  SizedBox(height: 12),
                                                                  AppTextField(
                                                                    controller: feeController,
                                                                    // nextFocus: passFocus,
                                                                    autoFocus: false,
                                                                    textFieldType: TextFieldType.PHONE,
                                                                    keyboardType: TextInputType.number,
                                                                    errorThisFieldRequired: language.thisFieldRequired,
                                                                    decoration: inputDecoration(context, label: 'Tarifa'),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (servicesListData!.modality == 'express')
                                                              Column(
                                                                children: [
                                                                  SizedBox(height: 8),
                                                                  Text('Tarifa', style: primaryTextStyle()),
                                                                  // SizedBox(height: 12),
                                                                  Text(toCurrency(servicesListData!.proposedFee ?? 0),
                                                                      style: primaryTextStyle()),
                                                                ],
                                                              ),
                                                            SizedBox(
                                                              height: 8,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: inkWellWidget(
                                                                    onTap: () {
                                                                      showConfirmDialogCustom(
                                                                          dialogType: DialogType.DELETE,
                                                                          primaryColor: primaryColor,
                                                                          title: language.areYouSureYouWantToCancelThisRequest,
                                                                          positiveText: language.yes,
                                                                          negativeText: language.no,
                                                                          context, onAccept: (v) {
                                                                        timerData!.cancel();
                                                                        sharedPref.remove(ON_RIDE_MODEL);
                                                                        sharedPref.remove(IS_TIME2);
                                                                        rideRequestAccept(deCline: true);
                                                                      });
                                                                    },
                                                                    child: Container(
                                                                      padding: EdgeInsets.all(8),
                                                                      decoration: BoxDecoration(
                                                                          borderRadius: BorderRadius.circular(defaultRadius),
                                                                          border: Border.all(color: Colors.red)),
                                                                      child: Text(language.decline,
                                                                          style: boldTextStyle(color: Colors.red),
                                                                          textAlign: TextAlign.center),
                                                                    ),
                                                                  ),
                                                                ),
                                                                // Expanded(
                                                                //   child: inkWellWidget(
                                                                //     onTap: () {
                                                                //       servicesListData = null;
                                                                //     },
                                                                //     child: Container(
                                                                //       padding: EdgeInsets.all(8),
                                                                //       decoration: BoxDecoration(
                                                                //           borderRadius: BorderRadius.circular(defaultRadius),
                                                                //           border: Border.all(color: Colors.white)),
                                                                //       child: Text('Cerrar',
                                                                //           style: boldTextStyle(color: Colors.black),
                                                                //           textAlign: TextAlign.center),
                                                                //     ),
                                                                //   ),
                                                                // ),
                                                                SizedBox(width: 16),
                                                                Expanded(
                                                                  child: AppButtonWidget(
                                                                    padding: EdgeInsets.zero,
                                                                    text: language.accept,
                                                                    shapeBorder: RoundedRectangleBorder(
                                                                        borderRadius: BorderRadius.circular(defaultRadius)),
                                                                    color: primaryColor,
                                                                    textStyle: boldTextStyle(color: Colors.white),
                                                                    onTap: () async {
                                                                      try {
                                                                        if ((servicesListData!.modality == 'auction' &&
                                                                                feeController.text != '') ||
                                                                            servicesListData!.modality == 'express') {
                                                                          timerData?.cancel();
                                                                          sharedPref.remove(IS_TIME2);
                                                                          sharedPref.remove(ON_RIDE_MODEL);
                                                                          rideRequestAccept(
                                                                              isExpress: servicesListData!.modality == 'express');
                                                                        } else {
                                                                          toast('Proponga su tarifa');
                                                                        }
                                                                      } catch (exception, stackTrace) {
                                                                        toast('Se produjo un error');
                                                                        await Sentry.captureException(
                                                                          exception,
                                                                          stackTrace: stackTrace,
                                                                        );
                                                                      }
                                                                      // showConfirmDialogCustom(
                                                                      //     primaryColor: primaryColor,
                                                                      //     dialogType: DialogType.ACCEPT,
                                                                      //     positiveText: language.yes,
                                                                      //     negativeText: language.no,
                                                                      //     title: language.areYouSureYouWantToAcceptThisRequest,
                                                                      //     context, onAccept: (v) async {
                                                                      //   try {
                                                                      //     timerData?.cancel();
                                                                      //     sharedPref.remove(IS_TIME2);
                                                                      //     sharedPref.remove(ON_RIDE_MODEL);
                                                                      //     rideRequestAccept();
                                                                      //   } catch (exception, stackTrace) {
                                                                      //     await Sentry.captureException(
                                                                      //       exception,
                                                                      //       stackTrace: stackTrace,
                                                                      //     );
                                                                      //   }
                                                                      // });
                                                                    },
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : SizedBox();
                                    },
                                  ),
                                  Observer(builder: (context) {
                                    return appStore.isLoading ? loaderWidget() : SizedBox();
                                  })
                                ],
                              ),
                            )
                          : Positioned(
                              top: (servicesListData!.status == DRIVERS_OFFERING && isOffering) ? 0 : null,
                              bottom: 0,
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(defaultRadius),
                                          child: commonCachedNetworkImage(servicesListData!.riderProfileImage,
                                              height: 35, width: 35, fit: BoxFit.cover),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${servicesListData!.riderName}', style: boldTextStyle(size: 14)),
                                              SizedBox(height: 4),
                                              Text('${servicesListData!.riderEmail.validate()}', style: secondaryTextStyle()),
                                            ],
                                          ),
                                        ),
                                        inkWellWidget(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) {
                                                return AlertDialog(
                                                  contentPadding: EdgeInsets.all(0),
                                                  content: AlertScreen(
                                                      rideId: servicesListData!.id, regionId: servicesListData!.regionId),
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                                color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                            child: Text(language.sos, style: boldTextStyle(color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                                    InkWell(
                                      onTap: () {
                                        openMaps(
                                            servicesListData!.startLatitude.toString(),
                                            servicesListData!.startLongitude.toString(),
                                            servicesListData!.endLatitude.toString(),
                                            servicesListData!.endLongitude.toString());
                                      },
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Column(
                                              children: [
                                                Icon(Icons.near_me, color: Colors.green),
                                                SizedBox(height: 4),
                                                SizedBox(
                                                  height: 30,
                                                  child: DottedLine(
                                                    direction: Axis.vertical,
                                                    lineLength: double.infinity,
                                                    lineThickness: 2,
                                                    dashColor: primaryColor,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Icon(Icons.location_on, color: Colors.red),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(bottom: 0, top: 14),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(servicesListData!.startAddress ?? '',
                                                      style: primaryTextStyle(size: 14), maxLines: 2),
                                                  SizedBox(height: 8),
                                                  Text(servicesListData!.endAddress ?? '',
                                                      style: primaryTextStyle(size: 14), maxLines: 2),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              Icon(
                                                Icons.map,
                                                size: 40,
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: servicesListData!.status != IN_PROGRESS
                                          ? MainAxisAlignment.spaceAround
                                          : MainAxisAlignment.spaceEvenly,
                                      children: [
                                        inkWellWidget(
                                          onTap: () {
                                            launchUrl(Uri.parse('tel:${servicesListData!.riderContactNumber}'),
                                                mode: LaunchMode.externalApplication);
                                          },
                                          child: Column(
                                            children: [
                                              Icon(Icons.call, size: 25, color: primaryColor),
                                              SizedBox(height: 4),
                                              Text(language.call, style: secondaryTextStyle()),
                                            ],
                                          ),
                                        ),
                                        inkWellWidget(
                                          onTap: () {
                                            if (riderData != null) {
                                              log(riderData!.username);
                                              launchScreen(context, ChatScreen(userData: riderData));
                                            }
                                          },
                                          child: Column(
                                            children: [
                                              Icon(Icons.chat, size: 25, color: primaryColor),
                                              SizedBox(height: 4),
                                              Text(language.chat, style: secondaryTextStyle()),
                                            ],
                                          ),
                                        ),
                                        /* if (servicesListData!.status != IN_PROGRESS)
                                          inkWellWidget(
                                            onTap: () {
                                              showConfirmDialogCustom(
                                                  dialogType: DialogType.CONFIRMATION,
                                                  positiveText: language.yes,
                                                  negativeText: language.no,
                                                  primaryColor: primaryColor,
                                                  title: language.areYouSureYouWantToCancelThisRide,
                                                  context, onAccept: (v) {
                                                rideRequest(status: CANCELED);
                                              });
                                            },
                                            child: Column(
                                              children: [
                                                Icon(Icons.close, size: 25, color: primaryColor),
                                                SizedBox(height: 4),
                                                Text(language.cancel, style: secondaryTextStyle()),
                                              ],
                                            ),
                                          )*/
                                      ],
                                    ),
                                    if (servicesListData!.status == IN_PROGRESS) SizedBox(height: 16),
                                    if (servicesListData!.status == IN_PROGRESS)
                                      if (appStore.extraChargeValue != null)
                                        Observer(builder: (context) {
                                          return Visibility(
                                            visible: int.parse(appStore.extraChargeValue!) != 0,
                                            child: inkWellWidget(
                                              onTap: () async {
                                                List<ExtraChargeRequestModel>? extraChargeListData = await showModalBottomSheet(
                                                  context: context,
                                                  builder: (_) {
                                                    return Padding(
                                                      padding: MediaQuery.of(context).viewInsets,
                                                      child: ExtraChargesWidget(data: extraChargeList),
                                                    );
                                                  },
                                                );
                                                if (extraChargeListData != null) {
                                                  extraChargeAmount = 0;
                                                  extraChargeList.clear();
                                                  extraChargeListData.forEach((element) {
                                                    extraChargeAmount = extraChargeAmount + element.value!;
                                                    extraChargeList = extraChargeListData;
                                                  });
                                                }
                                              },
                                              child: Row(
                                                children: [
                                                  Icon(Icons.add),
                                                  SizedBox(width: 16),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(language.applyExtraFree, style: primaryTextStyle()),
                                                      SizedBox(height: 2),
                                                      if (extraChargeAmount != 0)
                                                        Text('${language.extraCharges} ${extraChargeAmount.toString()}',
                                                            style: secondaryTextStyle(color: Colors.green)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                    SizedBox(height: 16),
                                    AppButtonWidget(
                                      width: MediaQuery.of(context).size.width,
                                      text: buttonText(status: servicesListData!.status),
                                      color: primaryColor,
                                      textStyle: boldTextStyle(color: Colors.white),
                                      onTap: () async {
                                        if (await checkPermission()) {
                                          if (servicesListData!.status == ACCEPTED) {
                                            showConfirmDialogCustom(
                                                primaryColor: primaryColor,
                                                positiveText: language.yes,
                                                negativeText: language.no,
                                                dialogType: DialogType.CONFIRMATION,
                                                title: language.areYouSureYouWantToArriving,
                                                context, onAccept: (v) {
                                              rideRequest(status: ARRIVING);
                                            });
                                          } else if (servicesListData!.status == ARRIVING) {
                                            showConfirmDialogCustom(
                                                primaryColor: primaryColor,
                                                positiveText: language.yes,
                                                negativeText: language.no,
                                                dialogType: DialogType.CONFIRMATION,
                                                title: language.areYouSureYouWantToArrived,
                                                context, onAccept: (v) {
                                              rideRequest(status: ARRIVED);
                                            });
                                          } else if (servicesListData!.status == ARRIVED) {
                                            showDialog(
                                              context: context,
                                              builder: (_) {
                                                return AlertDialog(
                                                  content: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Align(
                                                        alignment: Alignment.topRight,
                                                        child: inkWellWidget(
                                                          onTap: () {
                                                            Navigator.pop(context);
                                                          },
                                                          child: Container(
                                                            padding: EdgeInsets.all(4),
                                                            decoration:
                                                                BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                                            child: Icon(Icons.close, size: 20, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Center(
                                                        child: Text(language.enterOtp,
                                                            style: boldTextStyle(), textAlign: TextAlign.center),
                                                      ),
                                                      SizedBox(height: 16),
                                                      Text(
                                                        language.enterTheOtpDisplayInCustomersMobileToStartTheRide,
                                                        style: secondaryTextStyle(size: 12),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      SizedBox(height: 16),
                                                      OTPTextField(
                                                        controller: otpController,
                                                        length: 4,
                                                        width: MediaQuery.of(context).size.width,
                                                        fieldWidth: 40,
                                                        style: primaryTextStyle(),
                                                        textFieldAlignment: MainAxisAlignment.spaceAround,
                                                        fieldStyle: FieldStyle.box,
                                                        onCompleted: (val) {
                                                          otpCheck = val;
                                                        },
                                                        onChanged: (s) {
                                                          //
                                                        },
                                                      ),
                                                      SizedBox(height: 16),
                                                      AppButtonWidget(
                                                        width: MediaQuery.of(context).size.width,
                                                        text: language.confirm,
                                                        color: primaryColor,
                                                        textStyle: boldTextStyle(color: Colors.white),
                                                        onTap: () {
                                                          if (otpCheck == null || otpCheck != servicesListData!.otp) {
                                                            return toast(language.pleaseEnterValidOtp);
                                                          } else {
                                                            Navigator.pop(context);
                                                            rideRequest(status: IN_PROGRESS);
                                                          }
                                                        },
                                                      )
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          } else if (servicesListData!.status == IN_PROGRESS) {
                                            showConfirmDialogCustom(
                                                primaryColor: primaryColor,
                                                dialogType: DialogType.ACCEPT,
                                                title: language.areYouSureYouWantToCompletedThisRide,
                                                context,
                                                positiveText: language.yes,
                                                negativeText: language.no, onAccept: (v) {
                                              appStore.setLoading(true);
                                              getUserLocation().then((value) async {
                                                totalDistance = await calculateDistance(
                                                    double.parse(servicesListData!.startLatitude.validate()),
                                                    double.parse(servicesListData!.startLongitude.validate()),
                                                    driverLocation!.latitude,
                                                    driverLocation!.longitude);
                                                await completeRideRequest();
                                              });
                                            });
                                          } else if (servicesListData!.status == 'drivers_offering') {}
                                        }
                                      },
                                    ),
                                    if (servicesListData!.status == 'drivers_offering' && isOffering)
                                      Column(
                                        children: [
                                          SizedBox(
                                            height: 16,
                                          ),
                                          MaterialButton(
                                            onPressed: (() async => {
                                                  toast('Cancelando propuesta..'),
                                                  rejectedRides.add(servicesListData!),
                                                  await cancelProposal(servicesListData!),
                                                  isOffering = false
                                                }),
                                            child: Text('Cancelar'),
                                          )
                                        ],
                                      )
                                  ],
                                ),
                              ),
                            )
                      : SizedBox(),
                  Visibility(
                    visible: appStore.isLoading,
                    child: loaderWidget(),
                  ),
                ],
              )
            : loaderWidget(),
      ),
    );
  }

  Future<void> getUserLocation() async {
    List<Placemark> placemarks = await placemarkFromCoordinates(driverLocation!.latitude, driverLocation!.longitude);
    Placemark place = placemarks[0];
    endLocationAddress = '${place.street},${place.subLocality},${place.thoroughfare},${place.locality}';
  }

  void addOrUpdateRideRequests(OnRideRequest rideRequest) {
    int index = rideRequests.indexWhere((request) => request.id == rideRequest.id);
    if (index != -1) {
      rideRequests[index] = rideRequest;
    } else {
      // showDialog(
      //     context: context,
      //     barrierDismissible: false,
      //     builder: (BuildContext context) {
      //       dialogContext = context;
      //       return AlertDialog(
      //         title: Text(
      //           language.newRideRequested.toUpperCase(),
      //           textAlign: TextAlign.center,
      //           // style: TextStyle(fontWeight: FontWeight.bold),
      //         ),
      //         backgroundColor: primaryColor,
      //         content: ServiceDataWidget(
      //           serviceData: rideRequest,
      //           onClose: onRideNotificationClose,
      //           onSelect: onRideNotificationSelect,
      //         ),
      //       );
      //     });

      // rideRequests.add(rideRequest);

      if (sharedPref.getString('app_state') == 'inactive' || sharedPref.getString('app_state') == 'paused') {
        _playNotificationSound(type: 'new_service');
        windowService.showOverlayWindow(rideRequest);
        initBackground();
      }

      // Future.delayed(Duration(seconds: 3)).then((value) => Navigator.pop(dialogContext!));
    }
  }

  // String toCurrency(num amount) {
  //   return appStore.currencyPosition == LEFT
  //       ? '${appStore.currencyCode} ${amount.toStringAsFixed(2)}'
  //       : '${amount.toStringAsFixed(2)} ${appStore.currencyCode}';
  // }

  Future<void> openMaps(String originLat, String originLng, String destinyLat, String destinyLng) async {
    final String _url = "https://www.google.com/maps/dir/";
    final _params = {"api": "1", "origin": "$originLat,$originLng", "destination": "$destinyLat,$destinyLng"};

    final Uri _uri = Uri.parse(_url) // parse string
        .replace(queryParameters: _params);

    // toast(_uri.toString());

    if (await canLaunchUrl(_uri)) {
      await launchUrl(_uri);
    } else {
      throw 'No se pudo abrir Google Maps';
    }
  }

  Future<void> _playNotificationSound({String type = 'notification'}) async {
    Soundpool pool = Soundpool(streamType: StreamType.notification);

    int soundId = await rootBundle.load("sounds/$type.wav").then((ByteData soundData) {
      return pool.load(soundData);
    });
    int streamId = await pool.play(soundId);
  }

  Future<bool> initBackground() async {
    bool hasPermissions = await FlutterBackground.hasPermissions;

    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Blaze Driver",
      notificationText:
          "En nuestra app, permitir la ejecución en segundo plano te permitirá recibir solicitudes de viaje de manera más eficiente y en tiempo real. Esto significa que no te perderás ninguna oportunidad de recibir un viaje mientras estás en camino a completar otro",
      notificationImportance: AndroidNotificationImportance.Default,
      showBadge: true,
      // notificationIcon: AndroidResource(
      //     name: '@drawable/ic_launcher_foreground', defType: 'drawable'), // Default is ic_launcher from folder mipmap
    );

    if (!hasPermissions) {
      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
                title: Text('Permisos necesarios'),
                content: Text(
                    'En breve, el sistema operativo le pedirá permiso para ejecutar esta aplicación en segundo plano. Esto te permitirá recibir solicitudes de viaje de manera más eficiente y en tiempo real.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'Continuar'),
                    child: const Text('Continuar'),
                  ),
                ]);
          });
    }

    hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);

    await Future.delayed(Duration(seconds: 1));

    hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);

    // toast("haspermission $hasPermissions");

    if (hasPermissions) {
      await FlutterBackground.enableBackgroundExecution();
    }

    return hasPermissions;
  }

  void onRideNotificationClose(BuildContext context) {
    Navigator.pop(context);
  }

  void onRideNotificationSelect(OnRideRequest rideRequest) {
    servicesListData = rideRequest;
  }

  void showOverlay() {
    entry = OverlayEntry(
        builder: ((context) => Positioned(
            top: 40,
            left: 20,
            child: ElevatedButton.icon(onPressed: (() {}), icon: Icon(Icons.stop_circle_outlined), label: Text('Prueba')))));
  }

  // @pragma("vm:entry-point")
  static void myOverlayMain() {
    WidgetsFlutterBinding.ensureInitialized();
    log('floating: myOverlayMain');
    runApp(
      MaterialApp(home: ElevatedButton.icon(onPressed: (() {}), icon: Icon(Icons.stop_circle_outlined), label: Text('Prueba'))),
    );
    // or simply use `floatwing` method to inject `MaterialApp`
    // runApp(AssistivePannel().floatwing(app: true));
  }

  cancelProposal(OnRideRequest rideRequest) async {
    await cancelRideProposal(rideRequest.id!);
  }

    LatLng interpolate(LatLng start, LatLng end, double fraction) {
    double lat = start.latitude + (end.latitude - start.latitude) * fraction;
    double lng = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lng);
  }

  Future<void> animateMarkerTo(LatLng start, LatLng end, Duration duration) async {
    int steps = 20; // Número de pasos para interpolar
    Duration stepDuration = duration ~/ steps;

    for (int i = 0; i <= steps; i++) {
      double fraction = i / steps;
      LatLng interpolatedPosition = interpolate(start, end, fraction);

      // Actualiza la posición del marcador en el mapa
      setState(() {
        driverLatitudeLocation = interpolatedPosition;
        MarkerId id2 = MarkerId('DriverLocation');
        markers.remove(id2);
        markers.add(
          Marker(
            markerId: id2,
            position: interpolatedPosition,
            icon: driverIcon,
          ),
        );
      });

      await Future.delayed(stepDuration);
    }
  }

  double calculateBearing(LatLng start, LatLng end) {
    double startLat = start.latitude * pi / 180;
    double startLng = start.longitude * pi / 180;
    double endLat = end.latitude * pi / 180;
    double endLng = end.longitude * pi / 180;

    double dLng = endLng - startLng;

    double x = sin(dLng) * cos(endLat);
    double y = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);

    double bearing = atan2(x, y) * 180 / pi;
    return (bearing + 360) % 360; // Asegura un ángulo entre 0 y 360
  }

  double easeOut(double t) {
    return t * t; // La velocidad aumenta conforme avanza la fracción
  }

  double shortestAngle(double start, double end) {
    double delta = (end - start + 360) % 360;
    return delta > 180 ? delta - 360 : delta;
  }

  Future<void> animateMarkerSmoothly(LatLng start, LatLng end, Duration duration) async {
    final int frameRate = 60; // 60 FPS
    final int totalFrames = (duration.inMilliseconds / (1000 / frameRate)).round();
    final Duration frameDuration = Duration(milliseconds: (300 / frameRate).round());

    double startBearing = driverMarkerRotation ?? 0; // Usa la última rotación, o 0 si no existe
    double endBearing = calculateBearing(start, end);

    for (int frame = 0; frame <= totalFrames; frame++) {
      double linearFraction = frame / totalFrames;
      double easedFraction = easeOut(linearFraction); // Aplica la función de interpolación

      LatLng interpolatedPosition = interpolate(start, end, easedFraction);

      // Calcula la rotación usando la fracción interpolada
      double deltaBearing = shortestAngle(startBearing, endBearing);
      double interpolatedRotation = startBearing + deltaBearing * easedFraction;

      // Actualiza la posición y rotación del marcador
      setState(() {
        driverLatitudeLocation = interpolatedPosition;
        driverMarkerRotation = interpolatedRotation;
        MarkerId id2 = MarkerId('DriverLocation');
        markers.remove(id2);
        markers.add(
          Marker(
            markerId: id2,
            position: interpolatedPosition,
            rotation: interpolatedRotation, // Aplica la rotación acelerada
            icon: driverIcon,
          ),
        );
      });

      await Future.delayed(frameDuration);
    }
  }

  Future<void> _centerMap(LatLng driverLocation, LatLng destinationLocation) async {
    final GoogleMapController controller = await _controller.future;
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        min(driverLocation.latitude, destinationLocation.latitude),
        min(driverLocation.longitude, destinationLocation.longitude),
      ),
      northeast: LatLng(
        max(driverLocation.latitude, destinationLocation.latitude),
        max(driverLocation.longitude, destinationLocation.longitude),
      ),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

}