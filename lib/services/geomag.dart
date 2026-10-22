import 'dart:math' as math;

/// World Magnetic Model 2025 (WMM2025, NOAA NCEI / BGS), degree and order 12.
/// Coefficients copied verbatim from WMM2025.COF (epoch 2025.0, released 11/13/2024),
/// https://www.ncei.noaa.gov/products/world-magnetic-model — valid 2025.0 to 2030.0.
/// Verified against the official WMM2025_TestValues.txt (see scripts/verify/).
///
/// Used to convert the device's magnetic heading into a true heading so the
/// Qibla bearing (which is relative to true north) lines up correctly.
class MagneticModel {
  MagneticModel._();

  static const epoch = 2025.0;

  // n, m, g, h, dg/dt, dh/dt (nT, nT/year)
  static const List<List<num>> _cof = [
  [1, 0, -29351.8, 0.0, 12.0, 0.0],
  [1, 1, -1410.8, 4545.4, 9.7, -21.5],
  [2, 0, -2556.6, 0.0, -11.6, 0.0],
  [2, 1, 2951.1, -3133.6, -5.2, -27.7],
  [2, 2, 1649.3, -815.1, -8.0, -12.1],
  [3, 0, 1361.0, 0.0, -1.3, 0.0],
  [3, 1, -2404.1, -56.6, -4.2, 4.0],
  [3, 2, 1243.8, 237.5, 0.4, -0.3],
  [3, 3, 453.6, -549.5, -15.6, -4.1],
  [4, 0, 895.0, 0.0, -1.6, 0.0],
  [4, 1, 799.5, 278.6, -2.4, -1.1],
  [4, 2, 55.7, -133.9, -6.0, 4.1],
  [4, 3, -281.1, 212.0, 5.6, 1.6],
  [4, 4, 12.1, -375.6, -7.0, -4.4],
  [5, 0, -233.2, 0.0, 0.6, 0.0],
  [5, 1, 368.9, 45.4, 1.4, -0.5],
  [5, 2, 187.2, 220.2, 0.0, 2.2],
  [5, 3, -138.7, -122.9, 0.6, 0.4],
  [5, 4, -142.0, 43.0, 2.2, 1.7],
  [5, 5, 20.9, 106.1, 0.9, 1.9],
  [6, 0, 64.4, 0.0, -0.2, 0.0],
  [6, 1, 63.8, -18.4, -0.4, 0.3],
  [6, 2, 76.9, 16.8, 0.9, -1.6],
  [6, 3, -115.7, 48.8, 1.2, -0.4],
  [6, 4, -40.9, -59.8, -0.9, 0.9],
  [6, 5, 14.9, 10.9, 0.3, 0.7],
  [6, 6, -60.7, 72.7, 0.9, 0.9],
  [7, 0, 79.5, 0.0, -0.0, 0.0],
  [7, 1, -77.0, -48.9, -0.1, 0.6],
  [7, 2, -8.8, -14.4, -0.1, 0.5],
  [7, 3, 59.3, -1.0, 0.5, -0.8],
  [7, 4, 15.8, 23.4, -0.1, 0.0],
  [7, 5, 2.5, -7.4, -0.8, -1.0],
  [7, 6, -11.1, -25.1, -0.8, 0.6],
  [7, 7, 14.2, -2.3, 0.8, -0.2],
  [8, 0, 23.2, 0.0, -0.1, 0.0],
  [8, 1, 10.8, 7.1, 0.2, -0.2],
  [8, 2, -17.5, -12.6, 0.0, 0.5],
  [8, 3, 2.0, 11.4, 0.5, -0.4],
  [8, 4, -21.7, -9.7, -0.1, 0.4],
  [8, 5, 16.9, 12.7, 0.3, -0.5],
  [8, 6, 15.0, 0.7, 0.2, -0.6],
  [8, 7, -16.8, -5.2, -0.0, 0.3],
  [8, 8, 0.9, 3.9, 0.2, 0.2],
  [9, 0, 4.6, 0.0, -0.0, 0.0],
  [9, 1, 7.8, -24.8, -0.1, -0.3],
  [9, 2, 3.0, 12.2, 0.1, 0.3],
  [9, 3, -0.2, 8.3, 0.3, -0.3],
  [9, 4, -2.5, -3.3, -0.3, 0.3],
  [9, 5, -13.1, -5.2, 0.0, 0.2],
  [9, 6, 2.4, 7.2, 0.3, -0.1],
  [9, 7, 8.6, -0.6, -0.1, -0.2],
  [9, 8, -8.7, 0.8, 0.1, 0.4],
  [9, 9, -12.9, 10.0, -0.1, 0.1],
  [10, 0, -1.3, 0.0, 0.1, 0.0],
  [10, 1, -6.4, 3.3, 0.0, 0.0],
  [10, 2, 0.2, 0.0, 0.1, -0.0],
  [10, 3, 2.0, 2.4, 0.1, -0.2],
  [10, 4, -1.0, 5.3, -0.0, 0.1],
  [10, 5, -0.6, -9.1, -0.3, -0.1],
  [10, 6, -0.9, 0.4, 0.0, 0.1],
  [10, 7, 1.5, -4.2, -0.1, 0.0],
  [10, 8, 0.9, -3.8, -0.1, -0.1],
  [10, 9, -2.7, 0.9, -0.0, 0.2],
  [10, 10, -3.9, -9.1, -0.0, -0.0],
  [11, 0, 2.9, 0.0, 0.0, 0.0],
  [11, 1, -1.5, 0.0, -0.0, -0.0],
  [11, 2, -2.5, 2.9, 0.0, 0.1],
  [11, 3, 2.4, -0.6, 0.0, -0.0],
  [11, 4, -0.6, 0.2, 0.0, 0.1],
  [11, 5, -0.1, 0.5, -0.1, -0.0],
  [11, 6, -0.6, -0.3, 0.0, -0.0],
  [11, 7, -0.1, -1.2, -0.0, 0.1],
  [11, 8, 1.1, -1.7, -0.1, -0.0],
  [11, 9, -1.0, -2.9, -0.1, 0.0],
  [11, 10, -0.2, -1.8, -0.1, 0.0],
  [11, 11, 2.6, -2.3, -0.1, 0.0],
  [12, 0, -2.0, 0.0, 0.0, 0.0],
  [12, 1, -0.2, -1.3, 0.0, -0.0],
  [12, 2, 0.3, 0.7, -0.0, 0.0],
  [12, 3, 1.2, 1.0, -0.0, -0.1],
  [12, 4, -1.3, -1.4, -0.0, 0.1],
  [12, 5, 0.6, -0.0, -0.0, -0.0],
  [12, 6, 0.6, 0.6, 0.1, -0.0],
  [12, 7, 0.5, -0.1, -0.0, -0.0],
  [12, 8, -0.1, 0.8, 0.0, 0.0],
  [12, 9, -0.4, 0.1, 0.0, -0.0],
  [12, 10, -0.2, -1.0, -0.1, -0.0],
  [12, 11, -1.3, 0.1, -0.0, 0.0],
  [12, 12, -0.7, 0.2, -0.1, -0.1],
  ];

  static const _maxN = 12;
  static List<List<double>>? _g, _h, _gd, _hd;

  static void _load() {
    if (_g != null) return;
    List<List<double>> z() => List.generate(_maxN + 1, (_) => List.filled(_maxN + 1, 0.0));
    final g = z(), h = z(), gd = z(), hd = z();
    // Schmidt semi-normalisation factors, folded into the coefficients.
    final s = z();
    s[0][0] = 1;
    for (var n = 1; n <= _maxN; n++) {
      s[n][0] = s[n - 1][0] * (2 * n - 1) / n;
      for (var m = 1; m <= n; m++) {
        s[n][m] = s[n][m - 1] * math.sqrt((n - m + 1) * (m == 1 ? 2 : 1) / (n + m));
      }
    }
    for (final r in _cof) {
      final n = r[0].toInt(), m = r[1].toInt();
      g[n][m] = r[2] * s[n][m];
      h[n][m] = r[3] * s[n][m];
      gd[n][m] = r[4] * s[n][m];
      hd[n][m] = r[5] * s[n][m];
    }
    _g = g;
    _h = h;
    _gd = gd;
    _hd = hd;
  }

  /// Decimal year of [t] (e.g. 2026.81).
  static double decimalYear(DateTime t) {
    final u = t.toUtc();
    final start = DateTime.utc(u.year);
    final end = DateTime.utc(u.year + 1);
    return u.year + u.difference(start).inSeconds / end.difference(start).inSeconds;
  }

  /// Magnetic declination in degrees (east positive) at geodetic [lat]/[lng] (degrees),
  /// altitude [altKm] above the WGS-84 ellipsoid, for decimal year [year].
  /// Unreliable within about 2000 km of the magnetic poles (the compass itself is too).
  static double declination(double lat, double lng, {double altKm = 0, double? year}) {
    final f = field(lat, lng, altKm: altKm, year: year);
    return math.atan2(f.$2, f.$1) * 180 / math.pi;
  }

  /// Geodetic north (X), east (Y) and down (Z) field components in nT.
  static (double, double, double) field(double lat, double lng, {double altKm = 0, double? year}) {
    _load();
    final t = (year ?? decimalYear(DateTime.now())) - epoch;
    const a = 6378.137; // WGS-84 semi-major axis (km)
    const fl = 1 / 298.257223563;
    const e2 = fl * (2 - fl);
    const re = 6371.2; // geomagnetic reference radius (km)
    final phi = lat * math.pi / 180;
    final lam = lng * math.pi / 180;
    final sinPhi = math.sin(phi), cosPhi = math.cos(phi);
    final rc = a / math.sqrt(1 - e2 * sinPhi * sinPhi);
    final p = (rc + altKm) * cosPhi;
    final zc = (rc * (1 - e2) + altKm) * sinPhi;
    final r = math.sqrt(p * p + zc * zc);
    final phiC = math.asin(zc / r); // geocentric latitude
    final ct = math.sin(phiC); // cos(colatitude)
    final st = math.cos(phiC); // sin(colatitude)

    // Gauss-normalised associated Legendre functions and their theta-derivatives.
    final pp = List.generate(_maxN + 1, (_) => List.filled(_maxN + 1, 0.0));
    final dp = List.generate(_maxN + 1, (_) => List.filled(_maxN + 1, 0.0));
    pp[0][0] = 1;
    for (var n = 1; n <= _maxN; n++) {
      for (var m = 0; m <= n; m++) {
        if (n == m) {
          pp[n][m] = st * pp[n - 1][m - 1];
          dp[n][m] = st * dp[n - 1][m - 1] + ct * pp[n - 1][m - 1];
        } else if (n == 1 && m == 0) {
          pp[n][m] = ct * pp[n - 1][m];
          dp[n][m] = ct * dp[n - 1][m] - st * pp[n - 1][m];
        } else {
          final k = n > 1 ? ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3)) : 0.0;
          final p2 = n >= 2 && m <= n - 2 ? pp[n - 2][m] : 0.0;
          final d2 = n >= 2 && m <= n - 2 ? dp[n - 2][m] : 0.0;
          pp[n][m] = ct * pp[n - 1][m] - k * p2;
          dp[n][m] = ct * dp[n - 1][m] - st * pp[n - 1][m] - k * d2;
        }
      }
    }

    var br = 0.0, bt = 0.0, bp = 0.0;
    final g = _g!, h = _h!, gd = _gd!, hd = _hd!;
    for (var n = 1; n <= _maxN; n++) {
      final ar = math.pow(re / r, n + 2).toDouble();
      for (var m = 0; m <= n; m++) {
        final gnm = g[n][m] + t * gd[n][m];
        final hnm = h[n][m] + t * hd[n][m];
        final cm = math.cos(m * lam), sm = math.sin(m * lam);
        br += (n + 1) * ar * (gnm * cm + hnm * sm) * pp[n][m];
        bt -= ar * (gnm * cm + hnm * sm) * dp[n][m];
        bp += ar * m * (gnm * sm - hnm * cm) * pp[n][m];
      }
    }
    // Avoid division by zero exactly at the geographic poles.
    bp = st.abs() < 1e-10 ? 0 : bp / st;

    final xp = -bt, yp = bp, zp = -br;
    final psi = phiC - phi;
    final x = xp * math.cos(psi) - zp * math.sin(psi);
    final z = xp * math.sin(psi) + zp * math.cos(psi);
    return (x, yp, z);
  }
}
