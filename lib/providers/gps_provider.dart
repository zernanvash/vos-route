import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gps_service.dart';

class GpsProvider extends ChangeNotifier {
  final GpsService _gpsService = GpsService();
  Position? _lastPosition;
  bool _isTracking = false;

  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;

  void startTracking(int tripId) {
    _gpsService.startTracking(tripId);
    _isTracking = true;
    notifyListeners();
  }

  void stopTracking() {
    _gpsService.stopTracking();
    _isTracking = false;
    notifyListeners();
  }

  Future<void> updateLastPosition() async {
    _lastPosition = await _gpsService.getLastKnownPosition();
    notifyListeners();
  }
}
