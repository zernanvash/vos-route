import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gps_service.dart';

class GpsProvider extends ChangeNotifier {
  final GpsService _gpsService = GpsService();
  Position? _lastPosition;
  bool _isTracking = false;

  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;

  Future<void> startTracking(int tripId) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    await _gpsService.startTracking(tripId);
    _isTracking = true;
    notifyListeners();
  }

  Future<void> stopTracking() async {
    await _gpsService.stopTracking();
    _isTracking = false;
    notifyListeners();
  }

  Future<void> updateLastPosition() async {
    _lastPosition = await _gpsService.getLastKnownPosition();
    notifyListeners();
  }
}
