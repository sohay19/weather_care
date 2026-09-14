import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import 'current_location_service.dart';

abstract class GpsRegionNameService {
  const GpsRegionNameService();

  Future<String?> resolve(DeviceCoordinates coordinates);
}

class PlatformGpsRegionNameService extends GpsRegionNameService {
  final Duration timeout;

  const PlatformGpsRegionNameService({
    this.timeout = const Duration(seconds: 4),
  });

  @override
  Future<String?> resolve(DeviceCoordinates coordinates) async {
    try {
      final placemarks = await Geocoding()
          .placemarkFromCoordinates(
            coordinates.latitude,
            coordinates.longitude,
            locale: const Locale('ko', 'KR'),
          )
          .timeout(timeout);
      for (final placemark in placemarks) {
        final countryCode = placemark.isoCountryCode?.trim().toUpperCase();
        if (countryCode != null &&
            countryCode.isNotEmpty &&
            countryCode != 'KR') {
          continue;
        }
        final name = koreanAdministrativeDisplayName(
          administrativeArea: placemark.administrativeArea,
          subAdministrativeArea: placemark.subAdministrativeArea,
          locality: placemark.locality,
          subLocality: placemark.subLocality,
          name: placemark.name,
        );
        if (name != null) return name;
      }
    } catch (_) {
      // The platform geocoder is best-effort and may be unavailable or rate-limited.
    }
    return null;
  }
}

String? koreanAdministrativeDisplayName({
  String? administrativeArea,
  String? subAdministrativeArea,
  String? locality,
  String? subLocality,
  String? name,
}) {
  final topLevel = _administrativeTokens(administrativeArea)
      .where(_isTopLevelRegion)
      .firstOrNull;
  final details = <String>[];

  void addDetails(String? value, {bool neighborhoodOnly = false}) {
    for (final token in _administrativeTokens(value)) {
      if (_isTopLevelRegion(token)) continue;
      if (neighborhoodOnly && !_isNeighborhood(token)) continue;
      if (!_isDisplayRegion(token) || details.contains(token)) continue;
      details.add(token);
    }
  }

  addDetails(locality);
  addDetails(subAdministrativeArea);
  addDetails(subLocality);
  if (!details.any(_isNeighborhood)) {
    addDetails(name, neighborhoodOnly: true);
  }

  final result = <String>[];
  final topLevelLabel = _topLevelDisplayName(topLevel);
  if (topLevelLabel != null &&
      (_isMetropolitanRegion(topLevel) || details.isEmpty)) {
    result.add(topLevelLabel);
  }
  result.addAll(details);
  return result.isEmpty ? null : result.join(' ');
}

Iterable<String> _administrativeTokens(String? value) sync* {
  if (value == null) return;
  final normalized = value
      .trim()
      .replaceAll(RegExp(r'[,()]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return;

  for (final rawToken in normalized.split(' ')) {
    final token = rawToken.trim();
    if (token.isEmpty || token == '대한민국') continue;
    final combined = RegExp(r'^(.+?시)(.+구)$').firstMatch(token);
    if (combined != null && !_isTopLevelRegion(token)) {
      yield combined.group(1)!;
      yield combined.group(2)!;
    } else {
      yield token;
    }
  }
}

bool _isDisplayRegion(String value) =>
    RegExp(r'(시|군|구|읍|면|동)$').hasMatch(value);

bool _isNeighborhood(String value) => RegExp(r'(읍|면|동)$').hasMatch(value);

bool _isTopLevelRegion(String value) =>
    value.endsWith('특별시') ||
    value.endsWith('광역시') ||
    value.endsWith('특별자치시') ||
    value.endsWith('특별자치도') ||
    (value.endsWith('도') && !value.endsWith('동'));

bool _isMetropolitanRegion(String? value) =>
    value?.endsWith('특별시') == true ||
    value?.endsWith('광역시') == true ||
    value?.endsWith('특별자치시') == true;

String? _topLevelDisplayName(String? value) => switch (value) {
      '서울특별시' => '서울',
      '부산광역시' => '부산',
      '대구광역시' => '대구',
      '인천광역시' => '인천',
      '광주광역시' => '광주',
      '대전광역시' => '대전',
      '울산광역시' => '울산',
      '세종특별자치시' => '세종시',
      null => null,
      _ => value,
    };

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
