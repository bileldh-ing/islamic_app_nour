import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'storage.dart';

class UserLocation {
  const UserLocation({required this.lat, required this.lng, required this.city, this.country = ''});
  final double lat;
  final double lng;
  final String city;
  final String country;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'city': city, 'country': country};
  factory UserLocation.fromJson(Map<String, dynamic> j) => UserLocation(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        city: j['city'] ?? '',
        country: j['country'] ?? '',
      );

  /// Makkah — used until the device reports a real position.
  static const makkah = UserLocation(lat: 21.4225, lng: 39.8262, city: 'مكة المكرمة', country: 'السعودية');
}

class LocationService {
  LocationService._();
  static final _geo = Geocoding();
  static final ValueNotifier<UserLocation?> current = ValueNotifier(null);
  static final ValueNotifier<String?> error = ValueNotifier(null);

  static void loadCached() {
    final j = Store.getJson('location');
    if (j != null) current.value = UserLocation.fromJson(j);
  }

  /// Ask for permission, read GPS and reverse-geocode the city in Arabic.
  static Future<UserLocation?> refresh() async {
    error.value = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error.value = 'خدمة الموقع متوقفة. فعّلها لحساب أوقات الصلاة بدقة.';
        return current.value;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        error.value = 'لم يتم منح إذن الموقع.';
        return current.value;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      var city = '';
      var country = '';
      try {
        final marks = await _geo.placemarkFromCoordinates(pos.latitude, pos.longitude, locale: const Locale('ar'));
        if (marks.isNotEmpty) {
          final m = marks.first;
          city = <String?>[m.locality, m.subAdministrativeArea, m.administrativeArea]
                  .firstWhere((e) => e != null && e.trim().isNotEmpty, orElse: () => '') ??
              '';
          country = m.country ?? '';
        }
      } catch (_) {}
      if (city.isEmpty) city = '${pos.latitude.toStringAsFixed(3)}، ${pos.longitude.toStringAsFixed(3)}';
      final loc = UserLocation(lat: pos.latitude, lng: pos.longitude, city: city, country: country);
      await setManual(loc);
      return loc;
    } catch (e) {
      error.value = 'تعذّر تحديد الموقع.';
      return current.value;
    }
  }

  static Future<void> setManual(UserLocation loc) async {
    current.value = loc;
    await Store.setJson('location', loc.toJson());
  }

  /// Forward-geocode a city name typed by the user.
  static Future<UserLocation?> search(String query) async {
    try {
      final res = await _geo.locationFromAddress(query);
      if (res.isEmpty) return null;
      return UserLocation(lat: res.first.latitude, lng: res.first.longitude, city: query);
    } catch (_) {
      return null;
    }
  }
}
