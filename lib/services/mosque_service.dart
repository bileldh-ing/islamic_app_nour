import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/format.dart';
import 'prayer_calc.dart';
import 'storage.dart';

class Mosque {
  const Mosque({required this.id, required this.name, required this.lat, required this.lng, required this.distanceKm, this.address = ''});
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double distanceKm;
  final String address;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'lat': lat, 'lng': lng, 'd': distanceKm, 'address': address};
  factory Mosque.fromJson(Map<String, dynamic> j) => Mosque(
        id: '${j['id']}',
        name: j['name'] ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        distanceKm: (j['d'] as num).toDouble(),
        address: j['address'] ?? '',
      );
}

/// Nearby mosques from OpenStreetMap via the Overpass API
/// (amenity=place_of_worship + religion=muslim). Results are cached for offline use.
class MosqueService {
  MosqueService._();

  static const radiusMeters = 5000;
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const _cacheKey = 'mosques_cache';

  /// Last cached result if it was fetched within 1.5 km of ([lat],[lng]).
  static List<Mosque>? cached(double lat, double lng) {
    final j = Store.getJson(_cacheKey);
    if (j == null) return null;
    final cl = (j['lat'] as num?)?.toDouble(), cg = (j['lng'] as num?)?.toDouble();
    if (cl == null || cg == null || PrayerCalc.distanceKm(lat, lng, cl, cg) > 1.5) return null;
    return (j['items'] as List).cast<Map<String, dynamic>>().map(Mosque.fromJson).toList();
  }

  /// Throws when every endpoint fails (offline, rate-limited).
  static Future<List<Mosque>> nearby(double lat, double lng) async {
    final q = '[out:json][timeout:25];('
        'node["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);'
        'relation["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);'
        ');out center tags;';
    Object? lastError;
    for (final ep in _endpoints) {
      try {
        final res = await http
            .post(Uri.parse(ep), body: {'data': q}, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        final list = _parse(utf8.decode(res.bodyBytes), lat, lng);
        await Store.setJson(_cacheKey, {'lat': lat, 'lng': lng, 'items': list.map((e) => e.toJson()).toList()});
        return list;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('overpass unavailable: $lastError');
  }

  static List<Mosque> _parse(String body, double lat, double lng) {
    final els = ((jsonDecode(body) as Map<String, dynamic>)['elements'] as List).cast<Map<String, dynamic>>();
    final out = <Mosque>[];
    for (final e in els) {
      final center = e['center'] as Map<String, dynamic>?;
      final la = (e['lat'] ?? center?['lat']) as num?;
      final lo = (e['lon'] ?? center?['lon']) as num?;
      if (la == null || lo == null) continue;
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final name = (tags['name:ar'] ?? tags['name'] ?? tags['name:en'] ?? '') as String;
      final street = (tags['addr:street'] ?? '') as String;
      final city = (tags['addr:city'] ?? '') as String;
      out.add(Mosque(
        id: '${e['type']}/${e['id']}',
        name: name.isEmpty ? 'مسجد' : Fmt.western(name),
        lat: la.toDouble(),
        lng: lo.toDouble(),
        distanceKm: PrayerCalc.distanceKm(lat, lng, la.toDouble(), lo.toDouble()),
        address: Fmt.western([street, city].where((s) => s.isNotEmpty).join('، ')),
      ));
    }
    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return out;
  }

  /// Walking/driving directions link (Google Maps universal URL works on every platform).
  static Uri directionsUri(Mosque m) =>
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}');

  /// Native geo: URI (Android) for opening in the default maps app.
  static Uri geoUri(Mosque m) => Uri.parse('geo:${m.lat},${m.lng}?q=${m.lat},${m.lng}(${Uri.encodeComponent(m.name)})');
}
