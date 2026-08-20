enum LocationMode { gps, manual }

extension LocationModeLabel on LocationMode {
  String get label => this == LocationMode.gps ? 'GPS' : 'MANUAL';
}
