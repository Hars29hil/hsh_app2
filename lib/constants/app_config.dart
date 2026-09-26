/// App-wide runtime config.
class AppConfig {
  AppConfig._();

  /// Dev backend on the LAN — reachable from a real device on the same
  /// Wi-Fi and from the Android emulator (which routes host-machine IPs
  /// through normally, unlike `localhost`/`10.0.2.2` special-casing).
  /// Swap this for a real host before release.
  static const String host = 'http://10.240.101.189:3001';
  static const String baseUrl = 'http://10.240.101.189:3001/api';
  static const String healthUrl = 'http://10.240.101.189:3001/health';

  /// Server origin without the `/api` prefix — statically served uploads
  /// (e.g. complaint photos, mounted at `/uploads` — see server.ts) live
  /// here, not under `/api`.
  static String get mediaBaseUrl => baseUrl.endsWith('/api')
      ? baseUrl.substring(0, baseUrl.length - 4)
      : baseUrl;

  static const String appName = 'Hari Saurabh Hostel App';
  static const Duration mockNetworkDelay = Duration(milliseconds: 600);
}
