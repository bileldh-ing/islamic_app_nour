import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/format.dart';
import 'prayer_calc.dart';
import 'storage.dart';

class UserLocation {
  const UserLocation({required this.lat, required this.lng, required this.city, this.country = '', this.countryCode = '', this.manual = false});
  final double lat;
  final double lng;
  final String city;
  final String country;

  /// ISO-3166 alpha-2 (e.g. TN). Empty when unknown; [isoCode] falls back to the country name.
  final String countryCode;

  /// Picked by the user (search or manual) rather than read from GPS.
  final bool manual;

  String get isoCode => countryCode.isNotEmpty ? countryCode.toUpperCase() : PrayerCalc.countryCodeFromName(country);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'city': city, 'country': country, 'countryCode': countryCode, 'manual': manual};
  factory UserLocation.fromJson(Map<String, dynamic> j) => UserLocation(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        city: j['city'] ?? '',
        country: j['country'] ?? '',
        countryCode: j['countryCode'] ?? '',
        manual: j['manual'] ?? false,
      );

  /// Makkah — used until the device reports a real position.
  static const makkah = UserLocation(lat: 21.4225, lng: 39.8262, city: 'مكة المكرمة', country: 'السعودية', countryCode: 'SA');
}

class LocationService {
  LocationService._();
  static final _geo = Geocoding();
  static final ValueNotifier<UserLocation?> current = ValueNotifier(null);
  static final ValueNotifier<String?> error = ValueNotifier(null);
  static final ValueNotifier<bool> busy = ValueNotifier(false);

  /// Nominatim usage policy requires an identifying User-Agent (browsers send their own + Referer).
  static const userAgent = 'NoorIslamicApp/2.0 (Flutter; prayer times city search)';

  static void loadCached() {
    final j = Store.getJson('location');
    if (j != null) current.value = UserLocation.fromJson(j);
  }

  /// Ask for permission, read GPS and reverse-geocode the city in Arabic.
  static Future<UserLocation?> refresh() async {
    error.value = null;
    busy.value = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error.value = 'خدمة الموقع متوقفة. فعّلها لحساب أوقات الصلاة بدقة.';
        return current.value;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        error.value = 'لم يتم منح إذن الموقع. يمكنك البحث عن مدينتك بالاسم.';
        return current.value;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      var city = '';
      var country = '';
      var code = '';
      if (!kIsWeb) {
        try {
          final marks = await _geo.placemarkFromCoordinates(pos.latitude, pos.longitude, locale: const Locale('ar'));
          if (marks.isNotEmpty) {
            final m = marks.first;
            city = <String?>[m.locality, m.subAdministrativeArea, m.administrativeArea]
                    .firstWhere((e) => e != null && e.trim().isNotEmpty, orElse: () => '') ??
                '';
            country = m.country ?? '';
            code = m.isoCountryCode ?? '';
          }
        } catch (_) {}
      }
      if (city.isEmpty) {
        final r = await reverse(pos.latitude, pos.longitude);
        if (r != null) {
          city = r.city;
          country = r.country;
          code = r.countryCode;
        }
      }
      if (city.isEmpty) city = '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
      final loc = UserLocation(lat: pos.latitude, lng: pos.longitude, city: Fmt.western(city), country: country, countryCode: code);
      await setManual(loc);
      return loc;
    } catch (_) {
      error.value = 'تعذّر تحديد الموقع. تأكد من تفعيل GPS أو ابحث عن مدينتك.';
      return current.value;
    } finally {
      busy.value = false;
    }
  }

  static Future<void> setManual(UserLocation loc) async {
    current.value = loc;
    await Store.setJson('location', loc.toJson());
  }

  static Map<String, String> get _headers => kIsWeb ? const {} : const {'User-Agent': userAgent};

  /// City search by name via OpenStreetMap Nominatim (Arabic names preferred).
  /// Throws on network failure so the UI can show an error state.
  static Future<List<UserLocation>> searchCities(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '10',
      'accept-language': 'ar,en',
    });
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('nominatim ${res.statusCode}');
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    final out = <UserLocation>[];
    final seen = <String>{};
    for (final e in list.cast<Map<String, dynamic>>()) {
      final a = (e['address'] as Map?)?.cast<String, dynamic>() ?? const {};
      final city = (a['city'] ?? a['town'] ?? a['village'] ?? a['municipality'] ?? a['county'] ?? a['state'] ?? e['name'] ?? '') as String;
      if (city.isEmpty) continue;
      final country = (a['country'] ?? '') as String;
      if (!seen.add('$city|$country')) continue;
      out.add(UserLocation(
        lat: double.parse('${e['lat']}'),
        lng: double.parse('${e['lon']}'),
        city: Fmt.western(city),
        country: Fmt.western(country),
        countryCode: ((a['country_code'] ?? '') as String).toUpperCase(),
        manual: true,
      ));
    }
    return out;
  }

  /// Reverse-geocodes coordinates via Nominatim. Returns null when offline.
  static Future<UserLocation?> reverse(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'zoom': '10',
        'accept-language': 'ar,en',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? const {};
      final city = (a['city'] ?? a['town'] ?? a['village'] ?? a['municipality'] ?? a['county'] ?? a['state'] ?? '') as String;
      return UserLocation(
        lat: lat,
        lng: lng,
        city: Fmt.western(city),
        country: Fmt.western((a['country'] ?? '') as String),
        countryCode: ((a['country_code'] ?? '') as String).toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Forward-geocode a city name typed by the user (first match).
  static Future<UserLocation?> search(String query) async {
    try {
      final r = await searchCities(query);
      return r.isEmpty ? null : r.first;
    } catch (_) {
      return null;
    }
  }
}
