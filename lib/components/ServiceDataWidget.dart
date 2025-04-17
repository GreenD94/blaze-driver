import 'dart:async';

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:taxi_driver/main.dart';
import 'package:taxi_driver/model/CurrentRequestModel.dart';
import 'package:taxi_driver/network/RestApis.dart';
import 'package:taxi_driver/utils/Colors.dart';
import 'package:taxi_driver/utils/Extensions/AppButtonWidget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_common.dart';

class ServiceDataWidget extends StatefulWidget {
  final OnRideRequest serviceData;
  // final String iconData;
  final Function? onClose;
  final Function? onSelect;

  ServiceDataWidget({required this.serviceData, this.onClose, this.onSelect});

  @override
  ServiceDataState createState() => ServiceDataState();
}

class ServiceDataState extends State<ServiceDataWidget> {
  TextEditingController feeController = TextEditingController();
  Timer? timerData;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    feeController.text = widget.serviceData.proposedFee.toString();
  }

  Future<void> rideRequestAccept({bool deCline = false}) async {
    appStore.setLoading(true);
    // appStore.setLoading(false);

    Map req = {
      "id": widget.serviceData.id,
      if (!deCline) "driver_id": sharedPref.getInt(USER_ID),
      "is_accept": deCline ? "0" : "1",
      "proposed_fee": double.parse(feeController.text.trim()),
    };

    await rideRequestResPond(request: req).then((value) async {
      appStore.setLoading(false);

      if (widget.serviceData.status != DRIVERS_OFFERING) {
        // getCurrentRequest();
      }

      if (deCline) {
        // widget.serviceData = null;
        // _polyLines.clear();
        sharedPref.remove(ON_RIDE_MODEL);
        sharedPref.remove(IS_TIME2);
        // setMapPins();
        //setState(() {});
      }
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius)),
        ),
        child: SingleChildScrollView(
          // controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Align(
              //   alignment: Alignment.center,
              //   child: Container(
              //     // margin: EdgeInsets.only(top: 16),
              //     height: 6,
              //     // width: 60,
              //     decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
              //     alignment: Alignment.center,
              //   ),
              // ),
              // SizedBox(height: 8),
              Container(
                // margin: EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
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
                            child: commonCachedNetworkImage(widget.serviceData.riderProfileImage,
                                height: 35, width: 35, fit: BoxFit.cover),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${widget.serviceData.riderName}', style: boldTextStyle(size: 14)),
                                SizedBox(height: 4),
                                Text('${widget.serviceData.riderEmail}', style: secondaryTextStyle()),
                              ],
                            ),
                          ),
                          // Container(
                          //   decoration:
                          //       BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                          //   padding: EdgeInsets.all(6),
                          //   child: Text("$duration", style: boldTextStyle(color: Colors.white)),
                          // )
                        ],
                      ),
                      SizedBox(height: 16),
                      Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                      InkWell(
                          onTap: () {
                            openMaps(widget.serviceData.startLatitude.toString(), widget.serviceData.startLongitude.toString(),
                                widget.serviceData.endLatitude.toString(), widget.serviceData.endLongitude.toString());
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
                                      Text(widget.serviceData.startAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2),
                                      SizedBox(height: 8),
                                      Text(widget.serviceData.endAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2),
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
                      Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                      SizedBox(height: 8),
                      Column(
                        children: [
                          SizedBox(height: 8),
                          Text(toCurrency(widget.serviceData.proposedFee!), style: primaryTextStyle(size: 18)),
                          if (widget.serviceData.modality == 'express') Text('Express', style: primaryTextStyle(size: 12)),
                          // SizedBox(height: 8),
                          // Text('Proponer Tarifa', style: primaryTextStyle(size: 14)),
                          // SizedBox(height: 12),
                          // AppTextField(
                          //   controller: feeController,
                          //   // nextFocus: passFocus,
                          //   autoFocus: false,
                          //   textFieldType: TextFieldType.PHONE,
                          //   keyboardType: TextInputType.number,
                          //   errorThisFieldRequired: language.thisFieldRequired,
                          //   decoration: inputDecoration(context, label: 'Tarifa'),
                          // ),
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
                                // widget.serviceData = null;
                                if (widget.onClose != null) {
                                  widget.onClose!(context);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(defaultRadius), border: Border.all(color: Colors.white)),
                                child: Text('Cerrar', style: boldTextStyle(color: Colors.black), textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: AppButtonWidget(
                              padding: EdgeInsets.zero,
                              text: language.accept,
                              shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius)),
                              color: primaryColor,
                              textStyle: boldTextStyle(color: Colors.white),
                              onTap: () {
                                if (widget.onSelect != null) {
                                  widget.onSelect!(widget.serviceData);
                                  Navigator.pop(context);
                                }

                                // showConfirmDialogCustom(
                                //     primaryColor: primaryColor,
                                //     dialogType: DialogType.ACCEPT,
                                //     positiveText: language.yes,
                                //     negativeText: language.no,
                                //     title: language.areYouSureYouWantToAcceptThisRequest,
                                //     context, onAccept: (v) {
                                //   timerData!.cancel();
                                //   sharedPref.remove(IS_TIME2);
                                //   sharedPref.remove(ON_RIDE_MODEL);
                                //   rideRequestAccept();
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
      ),
    );
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
