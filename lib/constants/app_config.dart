/// App-wide runtime config.
class AppConfig {
  AppConfig._();

  /// Dev backend on the LAN — reachable from a real device on the same
  /// Wi-Fi and from the Android emulator (which routes host-machine IPs
  /// through normally, unlike `localhost`/`10.0.2.2` special-casing).
  /// Swap this for a real host before release.
  static const String host = 'https://hshbackend.hpys.in';
  static const String baseUrl = 'https://hshbackend.hpys.in/api';
  static const String healthUrl = 'https://hshbackend.hpys.in/';

  /// Live hosted attendance schedule endpoint
  static const String attendanceScheduleUrl =
      'https://attendentsnews.hpys.in/api/schedule-data';

  /// Live external student basic details endpoint
  static const String studentBasicDetailsUrl =
      'https://api.avdvvn.org/public/getStudentBasicDetails';
  static const String studentBasicDetailsAuthToken =
      'aF92Kx7QmN4Lp8Vz';

  /// Server origin without the `/api` prefix — statically served uploads
  /// (e.g. complaint photos, mounted at `/uploads` — see server.ts) live
  /// here, not under `/api`.
  static String get mediaBaseUrl => baseUrl.endsWith('/api')
      ? baseUrl.substring(0, baseUrl.length - 4)
      : baseUrl;

  static const String appName = 'Hari Saurabh Hostel App';
  static const Duration mockNetworkDelay = Duration(milliseconds: 600);
}
