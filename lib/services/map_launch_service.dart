import 'package:url_launcher/url_launcher.dart';

class MapLaunchService {
  static const List<String> supportedApps = [
    'google_maps',
    'waze',
    'apple_maps',
    'here_we_go',
    'sygic',
  ];

  static Future<bool> openInGoogleMaps({
    double? lat,
    double? lng,
    String? query,
  }) async {
    final q = _composeQuery(lat: lat, lng: lng, query: query);
    final googleUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
    );
    if (lat != null && lng != null) {
      final native = Uri.parse(
        'geo:0,0?q=$lat,$lng(${Uri.encodeComponent(query ?? '')})',
      );
      if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
        return true;
      }
    }
    return launchUrl(googleUri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openInWaze({
    double? lat,
    double? lng,
    String? query,
  }) async {
    if (lat != null && lng != null) {
      final native = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
        return true;
      }
      final fallback = Uri.parse(
        'https://waze.com/ul?ll=$lat%2C$lng&navigate=yes',
      );
      return launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
    final q = _composeQuery(lat: null, lng: null, query: query);
    final native = Uri.parse('waze://?q=${Uri.encodeComponent(q)}');
    if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
      return true;
    }
    final fallback = Uri.parse(
      'https://www.waze.com/?q=${Uri.encodeComponent(q)}',
    );
    return launchUrl(fallback, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openInAppleMaps({
    double? lat,
    double? lng,
    String? query,
  }) async {
    final q = _composeQuery(lat: lat, lng: lng, query: query);
    final uri = Uri.parse(
      'maps://?q=${Uri.encodeComponent(q)}${lat != null && lng != null ? '&ll=$lat,$lng' : ''}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openGeneric({
    double? lat,
    double? lng,
    String? query,
  }) async {
    final q = _composeQuery(lat: lat, lng: lng, query: query);
    final uri = Uri.parse(
      'https://maps.google.com/?q=${Uri.encodeComponent(q)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openAddress(String address) async {
    return openGeneric(query: address);
  }

  static String _composeQuery({double? lat, double? lng, String? query}) {
    if (lat != null && lng != null) return '$lat,$lng';
    return (query ?? '').trim();
  }
}
