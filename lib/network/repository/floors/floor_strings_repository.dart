import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../../../constants/app_config.dart';
import '../../responses/floors/floor_string_item.dart';

class FloorStringsRepository {

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Map<int, FloorStringItem>? _cachedFloorMap;
  DateTime? _lastFetch;

  /// Default fallback mapping in case network is offline
  static final Map<int, FloorStringItem> defaultFloorMap = {
    0: FloorStringItem(floorId: 0, floorName: 'Ground Floor', stringValue: 'FLR0-QFPH-HEYE'),
    1: FloorStringItem(floorId: 1, floorName: 'Floor 1', stringValue: 'FLR1-X7FS-WTSQ'),
    2: FloorStringItem(floorId: 2, floorName: 'Floor 2', stringValue: 'FLR2-YZWP-2SF2'),
    3: FloorStringItem(floorId: 3, floorName: 'Floor 3', stringValue: 'FLR3-GEQR-C43R'),
    4: FloorStringItem(floorId: 4, floorName: 'Floor 4', stringValue: 'FLR4-Z5BP-HCCH'),
    5: FloorStringItem(floorId: 5, floorName: 'Floor 5', stringValue: 'FLR5-44MZ-5TUZ'),
    6: FloorStringItem(floorId: 6, floorName: 'Floor 6', stringValue: 'FLR6-LPYW-KCMP'),
    7: FloorStringItem(floorId: 7, floorName: 'Floor 7', stringValue: 'FLR7-5ZNH-DH5U'),
    8: FloorStringItem(floorId: 8, floorName: 'Floor 8', stringValue: 'FLR8-AMZA-4K9R'),
    9: FloorStringItem(floorId: 9, floorName: 'Floor 9', stringValue: 'FLR9-64QN-XHW5'),
  };

  /// Resolves the student's floor id from an explicit floorId or room number string.
  /// Examples:
  /// - explicitFloorId: 3 -> 3
  /// - room: "311" -> 3
  /// - room: "504" -> 5
  /// - room: "1002" -> 10
  /// - room: "12" -> 1
  /// - room: "G01" -> 0
  static int resolveFloorId({int? explicitFloorId, String? room}) {
    if (explicitFloorId != null && explicitFloorId >= 0) {
      return explicitFloorId;
    }
    if (room != null && room.isNotEmpty) {
      final digits = room.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 3) {
        final floorPrefix = digits.substring(0, digits.length - 2);
        final parsed = int.tryParse(floorPrefix);
        if (parsed != null) return parsed;
      } else if (digits.length == 2) {
        final parsed = int.tryParse(digits.substring(0, 1));
        if (parsed != null) return parsed;
      } else if (digits.length == 1) {
        final parsed = int.tryParse(digits);
        if (parsed != null) return parsed;
      }
    }
    return 0; // Default ground floor
  }

  /// Fetches all dynamic floor strings from https://attendentsnews.hpys.in/api/floors/strings
  Future<Map<int, FloorStringItem>> fetchFloorStrings({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedFloorMap != null &&
        _cachedFloorMap!.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 5)) {
      return _cachedFloorMap!;
    }

    try {
      final res = await _dio.get(AppConfig.floorStringsUrl);
      final body = res.data;
      if (body is Map && body['data'] is List) {
        final list = (body['data'] as List)
            .whereType<Map>()
            .map((e) => FloorStringItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        final map = <int, FloorStringItem>{};
        for (final item in list) {
          map[item.floorId] = item;
        }
        if (map.isNotEmpty) {
          _cachedFloorMap = map;
          _lastFetch = DateTime.now();
          return map;
        }
      }
    } catch (e) {
      developer.log('fetchFloorStrings error: $e', name: 'FloorStringsRepo');
    }

    _cachedFloorMap ??= Map.from(defaultFloorMap);
    return _cachedFloorMap!;
  }

  /// Gets the specific service UUID string value for a given floor id
  Future<String> getStringForFloor(int floorId, {bool forceRefresh = false}) async {
    final map = await fetchFloorStrings(forceRefresh: forceRefresh);
    return map[floorId]?.stringValue ??
        defaultFloorMap[floorId]?.stringValue ??
        'FLR$floorId';
  }

  /// Gets the full item for a given floor id
  Future<FloorStringItem> getFloorItem(int floorId, {bool forceRefresh = false}) async {
    final map = await fetchFloorStrings(forceRefresh: forceRefresh);
    return map[floorId] ??
        defaultFloorMap[floorId] ??
        FloorStringItem(
          floorId: floorId,
          floorName: floorId == 0 ? 'Ground Floor' : 'Floor $floorId',
          stringValue: 'FLR$floorId',
        );
  }

  /// Returns synchronous floor name or fallback
  String getFloorNameSync(int floorId) {
    return _cachedFloorMap?[floorId]?.floorName ??
        defaultFloorMap[floorId]?.floorName ??
        (floorId == 0 ? 'Ground Floor' : 'Floor $floorId');
  }

  /// Returns a map of all active floor strings (useful for rejecting beacons of other floors)
  Map<int, String> getAllKnownFloorStrings() {
    final result = <int, String>{};
    for (final entry in defaultFloorMap.entries) {
      result[entry.key] = entry.value.stringValue;
    }
    if (_cachedFloorMap != null) {
      for (final entry in _cachedFloorMap!.entries) {
        result[entry.key] = entry.value.stringValue;
      }
    }
    return result;
  }
}