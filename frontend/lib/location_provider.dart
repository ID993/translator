import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logger/logger.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _subscription;
  bool _tracking = false;
  var logger = Logger();
  String? _locality;
  String? _administrativeArea;
  String? _country;
  String? _language;

  Position? get currentPosition => _currentPosition;
  String? get locality => _locality;
  String? get administrativeArea => _administrativeArea;
  String? get country => _country;
  String? get language => _language;
  bool get isTracking => _tracking;

  Future<void> startTracking() async {
    final detectionMode = Settings.getValue<String>("detection_mode");
    if (detectionMode != "location") {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
    }

    if (_tracking) return;
    _tracking = true;

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _subscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        _currentPosition = position;
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          _locality = place.locality;
          _administrativeArea = place.administrativeArea;
          _country = place.country;
          _language = place.isoCountryCode?.toLowerCase();
        } else {
          logger.d("No address available");
        }
        notifyListeners();
      },
      onError: (error) {
        logger.d("Location error: $error");
      },
    );
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    _tracking = false;
    _currentPosition = null;
    notifyListeners();
  }

  Future<void> updateTracking() async {
    final detectionMode = Settings.getValue<String>("detection_mode");
    if (detectionMode == "location") {
      await startTracking();
    } else {
      await stopTracking();
    }
  }
}
