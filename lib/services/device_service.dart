import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, dynamic>> getDeviceInfo(Size screenSize) async {
    String brand = "Unknown";
    String model = "Unknown";
    String osVersion = "Unknown";
    String deviceId = "Unknown";
    String appVersion = "1.0.0";
    String language = "en";
    String timeZone = "UTC";
    String country = "IN";
    String networkType = "Unknown";

    // 1. Get package info (App Version)
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
    } catch (e) {
      print("Error getting package info: $e");
    }

    // 2. Get hardware device info
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        brand = "Browser";
        model = webInfo.browserName.toString();
        osVersion = webInfo.userAgent ?? "Unknown";
        deviceId = "web_session";
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        brand = androidInfo.brand;
        model = androidInfo.model;
        osVersion = "Android ${androidInfo.version.release}";
        deviceId = androidInfo.id; // Unique hardware fingerprint
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        brand = "Apple";
        model = iosInfo.utsname.machine;
        osVersion = "iOS ${iosInfo.systemVersion}";
        deviceId = iosInfo.identifierForVendor ?? "Unknown";
      }
    } catch (e) {
      print("Error getting device hardware info: $e");
    }

    // 3. Get screen resolution
    final String screenResolution = "${screenSize.width.toInt()}x${screenSize.height.toInt()}";

    // 4. Get Language and Country
    try {
      final locale = Platform.localeName; // e.g. en_US, hi_IN
      final parts = locale.split('_');
      if (parts.isNotEmpty) {
        language = parts[0];
      }
      if (parts.length > 1) {
        country = parts[1];
      }
    } catch (e) {
      print("Error getting locale info: $e");
    }

    // 5. Get Timezone
    try {
      timeZone = DateTime.now().timeZoneName;
    } catch (e) {
      print("Error getting timezone: $e");
    }

    // 6. Get Network Type (WiFi vs Mobile Data)
    try {
      final dynamic connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult is List) {
        if (connectivityResult.contains(ConnectivityResult.wifi)) {
          networkType = "Wi-Fi";
        } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
          networkType = "Mobile Data";
        } else if (connectivityResult.contains(ConnectivityResult.none)) {
          networkType = "Offline";
        } else {
          networkType = "Other/Ethernet";
        }
      } else {
        // Fallback for older connectivity_plus package versions
        if (connectivityResult == ConnectivityResult.wifi) {
          networkType = "Wi-Fi";
        } else if (connectivityResult == ConnectivityResult.mobile) {
          networkType = "Mobile Data";
        } else if (connectivityResult == ConnectivityResult.none) {
          networkType = "Offline";
        } else {
          networkType = "Other/Ethernet";
        }
      }
    } catch (e) {
      print("Error checking connectivity: $e");
    }

    return {
      'device_brand': brand,
      'device_model': model,
      'android_version': osVersion,
      'app_version': appVersion,
      'device_identifier': deviceId,
      'screen_resolution': screenResolution,
      'language': language,
      'time_zone': timeZone,
      'country': country,
      'network_type': networkType,
    };
  }
}
