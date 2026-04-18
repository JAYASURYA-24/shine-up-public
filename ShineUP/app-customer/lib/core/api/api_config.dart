class ApiConfig {
  // Toggle this for local vs production testing
  static const bool useLocalBackend = false;

  // For Android Emulator, use 10.0.2.2
  // For iOS Simulator or physical device on same WiFi, use your machine's IP (e.g., 192.168.1.5)
  static const String localIp = '10.0.2.2'; 
  
  static const String prodBaseUrl = 'https://shine-up-public-production.up.railway.app/api/v1';
  static const String localBaseUrl = 'http://$localIp:8080/api/v1';

  static String get baseUrl => useLocalBackend ? localBaseUrl : prodBaseUrl;

  // WebSocket URLs
  static const String prodWsUrl = 'wss://shine-up-public-production.up.railway.app/ws';
  static const String localWsUrl = 'ws://$localIp:8080/ws';

  static String get wsUrl => useLocalBackend ? localWsUrl : prodWsUrl;
}
