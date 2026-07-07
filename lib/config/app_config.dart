class AppConfig {
  AppConfig._();

  static const String springBaseUrl = 'http://100.105.235.94:8082';
  static const String directusBaseUrl = 'http://100.110.197.61:8056';
  static const String directusStaticToken = 'AAKv73dkIV8DfAIA5vEt3eXVdIebzmBW';

  static const int gpsIntervalSeconds = 60;
  static const int connectionTimeoutMs = 5000;
  static const int receiveTimeoutMs = 30000;
  static const int gpsQueueBatchSize = 50;
  static const int syncRetryDelayMs = 5000;

  static const String mapStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';
}
