import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:taxi_driver/Services/UpgraderService.dart';
import 'package:taxi_driver/utils/Colors.dart';
import 'package:taxi_driver/utils/Extensions/AppButtonWidget.dart';

import '../utils/Extensions/app_common.dart';

class UpgradeScreen extends StatefulWidget {
  @override
  _UpgradeScreenState createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    //
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Feather.alert_triangle, size: 100),
            SizedBox(height: 16),
            Text('Actualización Disponible', style: boldTextStyle(size: 20)),
            Text('Es necesario actualizar', style: TextStyle(fontSize: 12)),
            SizedBox(height: 20),
            AppButtonWidget(
                // width: MediaQuery.of(context).size.width,
                color: primaryColor,
                text: "Abrir ${Platform.isAndroid ? 'Play Store' : 'App Store'}",
                textStyle: boldTextStyle(color: Colors.white),
                onTap: () {
                  openStore();
                })
          ],
        ),
      ),
    );
  }
}
