import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import 'kma_grid.dart';

class AddressSearchResult {
  final String address;
  final double latitude;
  final double longitude;

  const AddressSearchResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  KmaGrid get grid =>
      KmaGrid.fromCoordinates(latitude: latitude, longitude: longitude);
}

abstract class AddressSearchService {
  const AddressSearchService();

  Future<List<AddressSearchResult>> search(String address);
}

class PlatformAddressSearchService extends AddressSearchService {
  final Geocoding Function()? createGeocoding;
  final Duration timeout;

  const PlatformAddressSearchService({
    this.createGeocoding,
    this.timeout = const Duration(seconds: 10),
  });

  @override
  Future<List<AddressSearchResult>> search(String address) async {
    final query = address.trim();
    if (query.isEmpty) return [];
    if (createGeocoding == null &&
        (kIsWeb ||
            ![
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.macOS,
            ].contains(defaultTargetPlatform))) {
      throw UnsupportedError('Address search is unavailable');
    }
    return _search(query).timeout(timeout);
  }

  Future<List<AddressSearchResult>> _search(String query) async {
    final geocoding = createGeocoding?.call() ?? Geocoding();
    const locale = Locale('ko', 'KR');
    final deadline = DateTime.now().add(timeout);
    final locations =
        await geocoding.locationFromAddress(query, locale: locale);
    final results = <AddressSearchResult>[];
    final coordinates = <String>{};
    for (final location in locations.take(5)) {
      final lat = location.latitude;
      final lon = location.longitude;
      // 국내 주소만 확인하며 잘못된 좌표를 임의의 격자로 변환하지 않는다.
      if (!lat.isFinite ||
          !lon.isFinite ||
          lat < 32 ||
          lat > 39 ||
          lon < 124 ||
          lon > 132 ||
          !coordinates
              .add('${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}')) {
        continue;
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      final placemarks = await geocoding
          .placemarkFromCoordinates(lat, lon, locale: locale)
          .timeout(remaining);
      final placemark = placemarks
          .where((p) => p.isoCountryCode?.trim().toUpperCase() == 'KR')
          .firstOrNull;
      if (placemark == null) continue;
      final label = _addressLabel(placemark);
      if (label.isEmpty) continue;
      results.add(
          AddressSearchResult(address: label, latitude: lat, longitude: lon));
    }
    return results;
  }
}

String _addressLabel(Placemark placemark) {
  final parts = <String>[];
  for (final value in [
    placemark.administrativeArea,
    placemark.subAdministrativeArea,
    placemark.locality,
    placemark.subLocality,
  ]) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
  }
  final road = [placemark.thoroughfare, placemark.subThoroughfare]
      .whereType<String>()
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .join(' ');
  final street = road.isNotEmpty ? road : placemark.street?.trim() ?? '';
  final prefix = parts.join(' ');
  if (street.isEmpty || prefix.endsWith(street)) return prefix;
  if (parts.isNotEmpty && street.contains(parts.first)) return street;
  return [prefix, street].where((v) => v.isNotEmpty).join(' ');
}
