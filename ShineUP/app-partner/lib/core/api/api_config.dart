class ApiConfig {
  static const bool useLocalBackend = false;
  static const String localIp = '10.0.2.2'; 
  
  static const String prodBaseUrl = 'https://shine-up-public-production.up.railway.app/api/v1';
  static const String localBaseUrl = 'http://$localIp:8080/api/v1';

  static String get baseUrl => useLocalBackend ? localBaseUrl : prodBaseUrl;

  static const String prodWsUrl = 'wss://shine-up-public-production.up.railway.app/ws';
  static const String localWsUrl = 'ws://$localIp:8080/ws';

  static String get wsUrl => useLocalBackend ? localWsUrl : prodWsUrl;
}
