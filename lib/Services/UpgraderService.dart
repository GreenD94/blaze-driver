import 'dart:developer';
import 'dart:io';
import 'package:html/dom.dart';
import 'package:upgrader/upgrader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

String packageName = '';
String version = '';
String buildNumber = '';
String appId = '6445899965';

init() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  packageName = packageInfo.packageName;
  version = packageInfo.version;
  buildNumber = packageInfo.buildNumber;
}

Future<String?> getStoreVersion() async {
  await init();
  String? storeVersion;
  String? myAppBundleId = packageName;
  if (Platform.isAndroid) {
    PlayStoreSearchAPI playStoreSearchAPI = PlayStoreSearchAPI();
    Document? result = await playStoreSearchAPI.lookupById(myAppBundleId, country: 'VE');
    if (result != null) storeVersion = playStoreSearchAPI.version(result);
    log('PlayStore version: $storeVersion}');
  } else if (Platform.isIOS) {
    ITunesSearchAPI iTunesSearchAPI = ITunesSearchAPI();
    Map<dynamic, dynamic>? result = await iTunesSearchAPI.lookupByBundleId(myAppBundleId, country: 'US');
    if (result != null) storeVersion = iTunesSearchAPI.version(result);
    log('AppStore version: $storeVersion}');
  } else {
    storeVersion = null;
  }
  return storeVersion;
}

void compareVersion() {
  String versionInstalled = "1.2.3"; // Versión instalada
  String versionLatest = "1.3.0"; // Versión más reciente

  int comparisonResult = versionInstalled.compareTo(versionLatest);

  if (comparisonResult < 0) {
    // La versión instalada es anterior a la más reciente
    print('La versión instalada es anterior a la más reciente');
  } else if (comparisonResult > 0) {
    // La versión instalada es posterior a la más reciente
    print('La versión instalada es posterior a la más reciente');
  } else {
    // Ambas versiones son iguales
    print('Ambas versiones son iguales');
  }
}

Future<bool> isOutdated() async {
  await init();
  String versionInstalled = version; // Versión instalada
  String? versionLatest = await getStoreVersion(); // Versión más reciente
  int comparisonResult = versionInstalled.compareTo(versionLatest!);

  log('[version] Version installed: $versionInstalled - Version latest: $versionLatest');
  log('[version] $comparisonResult');

  return comparisonResult < 0;
}

Future<String> getCurrentVersion() async {
  await init();
  return version;
}

void openPlayStore() async {
  await init();
  final url = 'market://details?id=$packageName';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw 'No se pudo abrir la aplicación de Google Play Store.';
  }
}

void openAppStore() async {
  final url = 'itms-apps://itunes.apple.com/app/id$appId';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw 'No se pudo abrir la aplicación de App Store.';
  }
}

void openStore() async {
  if (Platform.isAndroid) {
    openPlayStore();
  } else if (Platform.isIOS) {
    openAppStore();
  } else {
    log('[UPGRADER] invalid platform');
  }
}


// Future<String> checkIfAppUpdated() async {
//   await init();
//   return version;
// }


