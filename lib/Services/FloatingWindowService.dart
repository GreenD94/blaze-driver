import 'package:flutter/material.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'package:taxi_driver/main.dart';
import 'package:taxi_driver/model/CurrentRequestModel.dart';
import 'package:taxi_driver/utils/Colors.dart';
import 'package:taxi_driver/utils/Common.dart';
import 'package:taxi_driver/utils/Constants.dart';

class FloatingWindowService {
  bool _isShowingWindow = false;
  bool _isUpdatedWindow = false;
  SystemWindowPrefMode prefMode = SystemWindowPrefMode.OVERLAY;

  Future<void> requestPermissions() async {
    await SystemAlertWindow.requestPermissions(prefMode: prefMode);
  }

  void showOverlayWindow(OnRideRequest rideRequest) {
    if (!_isShowingWindow) {
      SystemWindowHeader header = SystemWindowHeader(
        title: SystemWindowText(text: language.appName, fontSize: 10, textColor: Colors.black45),
        padding: SystemWindowPadding.setSymmetricPadding(12, 12),
        subTitle: SystemWindowText(
            text: language.newRideRequested, fontSize: 14, fontWeight: FontWeight.BOLD, textColor: Colors.black87),
        decoration: SystemWindowDecoration(startColor: primaryColor),
        // button:
        //     SystemWindowButton(text: SystemWindowText(text: "Spam", fontSize: 10, textColor: Colors.black45), tag: "spam_btn"),
        // buttonPosition: ButtonPosition.TRAILING
      );

      SystemWindowBody body = SystemWindowBody(
        rows: [
          EachRow(
            columns: [
              EachColumn(
                text: SystemWindowText(
                    text: "Desde: ${rideRequest.startAddress.toString()}", fontSize: 12, textColor: Colors.black45),
              ),
              // EachColumn(
              //   text: SystemWindowText(text: rideRequest.endAddress.toString(), fontSize: 12, textColor: Colors.black45),
              // ),
            ],
            gravity: ContentGravity.CENTER,
          ),
          EachRow(columns: [
            EachColumn(
              text:
                  SystemWindowText(text: "Hasta: ${rideRequest.endAddress.toString()}", fontSize: 12, textColor: Colors.black45),
            ),
            // EachColumn(
            //     text: SystemWindowText(
            //         text: "Long data of the body", fontSize: 12, textColor: Colors.black87, fontWeight: FontWeight.BOLD),
            //     padding: SystemWindowPadding.setSymmetricPadding(6, 8),
            //     decoration: SystemWindowDecoration(startColor: Colors.black12, borderRadius: 25.0),
            //     margin: SystemWindowMargin(top: 4)),
          ], gravity: ContentGravity.CENTER),
          EachRow(
            columns: [
              EachColumn(
                text: SystemWindowText(text: "Tarifa Propuesta", fontSize: 10, textColor: Colors.black45),
              ),
            ],
            gravity: ContentGravity.LEFT,
            margin: SystemWindowMargin(top: 8),
          ),
          EachRow(
            columns: [
              EachColumn(
                text: SystemWindowText(
                    text: toCurrency(rideRequest.proposedFee!),
                    fontSize: 13,
                    textColor: Colors.black54,
                    fontWeight: FontWeight.BOLD),
              ),
            ],
            gravity: ContentGravity.LEFT,
          ),
        ],
        padding: SystemWindowPadding(left: 16, right: 16, bottom: 12, top: 12),
      );

      SystemWindowFooter footer = SystemWindowFooter(
          buttons: [
            SystemWindowButton(
              text: SystemWindowText(text: "Cerrar", fontSize: 12, textColor: Colors.black87),
              tag: "simple_button",
              padding: SystemWindowPadding(left: 10, right: 10, bottom: 10, top: 10),
              width: 0,
              height: SystemWindowButton.WRAP_CONTENT,
              decoration:
                  SystemWindowDecoration(startColor: Colors.white, endColor: Colors.white, borderWidth: 0, borderRadius: 0.0),
            ),
            SystemWindowButton(
              text: SystemWindowText(text: "Ver", fontSize: 12, textColor: Colors.white),
              tag: "focus_button",
              width: 0,
              padding: SystemWindowPadding(left: 10, right: 10, bottom: 10, top: 10),
              height: SystemWindowButton.WRAP_CONTENT,
              decoration:
                  SystemWindowDecoration(startColor: primaryColor, endColor: primaryColor, borderWidth: 0, borderRadius: 10),
            )
          ],
          padding: SystemWindowPadding(left: 16, right: 16, bottom: 12, top: 10),
          decoration: SystemWindowDecoration(startColor: Colors.white),
          buttonsPosition: ButtonPosition.CENTER);

      SystemAlertWindow.showSystemWindow(
          height: 230,
          header: header,
          body: body,
          footer: footer,
          margin: SystemWindowMargin(left: 8, right: 8, top: 10, bottom: 0),
          gravity: SystemWindowGravity.TOP,
          // notificationTitle: "Incoming Call",
          // notificationBody: "+1 646 980 4741",
          prefMode: prefMode,
          backgroundColor: Colors.white,
          isDisableClicks: false);
      // setState(() {
      //   _isShowingWindow = true;
      // });
    } else if (!_isUpdatedWindow) {
      SystemWindowHeader header = SystemWindowHeader(
          title: SystemWindowText(text: "Outgoing Call", fontSize: 10, textColor: Colors.black45),
          padding: SystemWindowPadding.setSymmetricPadding(12, 12),
          subTitle: SystemWindowText(text: "8989898989", fontSize: 14, fontWeight: FontWeight.BOLD, textColor: Colors.black87),
          decoration: SystemWindowDecoration(startColor: Colors.grey[100]),
          button:
              SystemWindowButton(text: SystemWindowText(text: "Spam", fontSize: 10, textColor: Colors.black45), tag: "spam_btn"),
          buttonPosition: ButtonPosition.TRAILING);
      SystemWindowBody body = SystemWindowBody(
        rows: [
          EachRow(
            columns: [
              EachColumn(
                text: SystemWindowText(text: "Updated body", fontSize: 12, textColor: Colors.black45),
              ),
            ],
            gravity: ContentGravity.CENTER,
          ),
          EachRow(columns: [
            EachColumn(
                text: SystemWindowText(
                    text: "Updated long data of the body", fontSize: 12, textColor: Colors.black87, fontWeight: FontWeight.BOLD),
                padding: SystemWindowPadding.setSymmetricPadding(6, 8),
                decoration: SystemWindowDecoration(startColor: Colors.black12, borderRadius: 25.0),
                margin: SystemWindowMargin(top: 4)),
          ], gravity: ContentGravity.CENTER),
          EachRow(
            columns: [
              EachColumn(
                text: SystemWindowText(text: "Description", fontSize: 10, textColor: Colors.black45),
              ),
            ],
            gravity: ContentGravity.LEFT,
            margin: SystemWindowMargin(top: 8),
          ),
          EachRow(
            columns: [
              EachColumn(
                text: SystemWindowText(
                    text: "Updated random description.", fontSize: 13, textColor: Colors.black54, fontWeight: FontWeight.BOLD),
              ),
            ],
            gravity: ContentGravity.LEFT,
          ),
        ],
        padding: SystemWindowPadding(left: 16, right: 16, bottom: 12, top: 12),
      );
      SystemWindowFooter footer = SystemWindowFooter(
          buttons: [
            SystemWindowButton(
              text: SystemWindowText(text: "Updated Simple button", fontSize: 12, textColor: Colors.blue),
              tag: "updated_simple_button",
              padding: SystemWindowPadding(left: 10, right: 10, bottom: 10, top: 10),
              width: 0,
              height: SystemWindowButton.WRAP_CONTENT,
              decoration:
                  SystemWindowDecoration(startColor: Colors.white, endColor: Colors.white, borderWidth: 0, borderRadius: 0.0),
            ),
            SystemWindowButton(
              text: SystemWindowText(text: "Focus button", fontSize: 12, textColor: Colors.white),
              tag: "focus_button",
              width: 0,
              padding: SystemWindowPadding(left: 10, right: 10, bottom: 10, top: 10),
              height: SystemWindowButton.WRAP_CONTENT,
              decoration: SystemWindowDecoration(
                  startColor: Colors.blueAccent, endColor: Colors.blue, borderWidth: 0, borderRadius: 30.0),
            )
          ],
          padding: SystemWindowPadding(left: 16, right: 16, bottom: 12, top: 10),
          decoration: SystemWindowDecoration(startColor: Colors.white),
          buttonsPosition: ButtonPosition.CENTER);
      SystemAlertWindow.updateSystemWindow(
          height: 230,
          header: header,
          body: body,
          footer: footer,
          margin: SystemWindowMargin(left: 8, right: 8, top: 200, bottom: 0),
          gravity: SystemWindowGravity.TOP,
          notificationTitle: "Outgoing Call",
          notificationBody: "+1 646 980 4741",
          prefMode: prefMode,
          backgroundColor: Colors.black12,
          isDisableClicks: true);
      // setState(() {
      //   _isUpdatedWindow = true;
      // });
    } else {
      // setState(() {
      //   _isShowingWindow = false;
      //   _isUpdatedWindow = false;
      // });
      SystemAlertWindow.closeSystemWindow(prefMode: prefMode);
    }
  }

  //close overlay window
  void closeOverlayWindow() {
    SystemAlertWindow.closeSystemWindow(prefMode: prefMode);
  }

  String _toCurrency(num amount) {
    return appStore.currencyPosition == LEFT
        ? '${appStore.currencyCode} ${amount.toStringAsFixed(2)}'
        : '${amount.toStringAsFixed(2)} ${appStore.currencyCode}';
  }
}
