import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Fetches the device location — only called when the creature needs it for a
/// place search (per-request, opt-in). Never stored or tracked.
class LocationService {
  const LocationService();

  /// Returns (lat, lng) or null if permission denied / unavailable.
  Future<({double lat, double lng})?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      // Hard time limit: this runs inside the chat send, so a slow or blocked
      // fix must not hold up the reply. On timeout we return null and the
      // router simply answers without coordinates.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 7),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      // Indistinguishable from 'permission denied' without this line.
      debugPrint('location lookup failed: $e');
      return null;
    }
  }
}
