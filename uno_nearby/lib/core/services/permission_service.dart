import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

enum PermissionOutcome { granted, denied, permanentlyDenied }

/// Requests only the permission actually required for local Wi-Fi device
/// discovery — nothing else. On Android 13+ (API 33+) that's
/// NEARBY_WIFI_DEVICES; on older versions, the platform still ties Wi-Fi
/// scanning to ACCESS_FINE_LOCATION, so we request that instead.
class PermissionService {
  PermissionService._();

  static Future<PermissionOutcome> requestNearbyPermission() async {
    if (!Platform.isAndroid) return PermissionOutcome.granted;

    // permission_handler resolves nearbyWifiDevices to a no-op on OS
    // versions where it doesn't apply, so it's safe to request both and
    // let the platform decide which one is actually needed.
    final results = await [
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
    ].request();

    if (results.values.any((s) => s.isGranted)) return PermissionOutcome.granted;
    if (results.values.any((s) => s.isPermanentlyDenied)) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }
}
