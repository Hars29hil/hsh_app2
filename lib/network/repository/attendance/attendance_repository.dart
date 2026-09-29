import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../common_enums/attendance_type.dart';
import '../../../constants/app_config.dart';
import '../../../storage/session_store.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/attendance/mark_attendance_request.dart';
import '../../request/operator/operator_requests.dart';
import '../../responses/attendance/attendance_models.dart';

class AttendanceRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  // In-memory cache & fallback when running in offline/mock mode
  final Map<AttendanceType, DateTime> _mockMarkedToday = {};
  final List<AttendanceRecord> _mockHistory = [];
  final List<SabhaSession> _mockSabhas = [];

  AttendanceRepository() {
    _initMockData();
  }

  Future<Options> _authOptions([Options? base]) async {
    final token = SessionStore.instance.currentToken ?? await SessionStore.instance.token;
    final headers = Map<String, dynamic>.from(base?.headers ?? {});
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return (base ?? Options()).copyWith(headers: headers);
  }

  void _initMockData() {
    final now = DateTime.now().toUtc();
    _mockSabhas.addAll([
      SabhaSession(
        id: 'sabha-1',
        date: now.add(const Duration(days: 2)),
        description: 'Weekly Youth Sabha',
        current: true,
        startTime: now.add(const Duration(days: 2, hours: 18)),
        endTime: now.add(const Duration(days: 2, hours: 20)),
      ),
      SabhaSession(
        id: 'sabha-2',
        date: now.add(const Duration(days: 9)),
        description: 'Special Satsang Sabha',
        current: false,
        startTime: now.add(const Duration(days: 9, hours: 18)),
        endTime: now.add(const Duration(days: 9, hours: 20)),
      ),
    ]);
  }

  /// Extracts descriptive error message from backend DioException envelope
  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
      if (data['error'] is String && (data['error'] as String).isNotEmpty) {
        return data['error'] as String;
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not connect to host at ${AppConfig.baseUrl}. Please verify Wi-Fi and server status.';
    }
    return e.message ?? 'Attendance request failed. Please try again.';
  }

  /// Generate dynamic rotating QR token for display kiosk
  /// `GET /api/attendance/qr-token?type={type}`
  Future<QrTokenResponse> generateQrToken(String type) async {
    try {
      final response = await _dio.get(
        '/attendance/qr-token',
        queryParameters: {'type': type},
        options: await _authOptions(),
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return QrTokenResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
      }
      developer.log('generateQrToken connection error, using local fallback token', name: 'AttendanceRepo');
      final now = DateTime.now().toUtc();
      return QrTokenResponse(
        token: 'local_mock_token_${type}_${now.millisecondsSinceEpoch}',
        type: type,
        date: DateFormat('yyyy-MM-dd').format(now),
        expiresIn: 30,
        expiresAt: now.add(const Duration(seconds: 30)),
      );
    }
  }

  static const List<Map<String, String>> defaultSessionConfigs = [
    {
      'key': 'aarti',
      'name': 'Aarti Attendance',
      'icon': 'fire',
      'defaultStart': '18:45',
      'defaultEnd': '19:20',
    },
    {
      'key': 'morning',
      'name': 'Morning Attendance',
      'icon': 'fire',
      'defaultStart': '06:00',
      'defaultEnd': '07:00',
    },
    {
      'key': 'lunch',
      'name': 'Lunch Attendance',
      'icon': 'lunch',
      'defaultStart': '11:00',
      'defaultEnd': '16:00',
    },
    {
      'key': 'dinner',
      'name': 'Dinner Attendance',
      'icon': 'dinner',
      'defaultStart': '16:00',
      'defaultEnd': '21:00',
    },
    {
      'key': 'night',
      'name': 'Night Attendance',
      'icon': 'moon',
      'defaultStart': '22:30',
      'defaultEnd': '23:05',
    },
    {
      'key': 'sabha',
      'name': 'Sabha Attendance',
      'icon': 'groups',
      'defaultStart': '18:00',
      'defaultEnd': '20:00',
    },
  ];

  /// Fetch all live attendance session schedules directly from
  /// https://attendentsnews.hpys.in/api/schedule-data
  Future<List<AttendanceScheduleItem>> fetchAttendanceSchedules({
    List<AttendanceScheduleItem>? existingSchedules,
  }) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final res = await dio.get(AppConfig.attendanceScheduleUrl);

      List<dynamic>? rawList;
      if (res.data is List) {
        rawList = res.data as List;
      } else if (res.data is Map && res.data['data'] is List) {
        rawList = res.data['data'] as List;
      }

      if (rawList != null && rawList.isNotEmpty) {
        final items = <AttendanceScheduleItem>[];
        for (final entry in rawList) {
          final map = entry is Map<String, dynamic>
              ? entry
              : (entry is Map ? Map<String, dynamic>.from(entry) : null);
          if (map == null) continue;

          final isActive = map['is_active'];
          if (isActive == false || isActive == 0 || isActive == '0') {
            continue;
          }

          items.add(AttendanceScheduleItem.fromJson(map));
        }

        if (items.isNotEmpty) {
          items.sort((a, b) => a.startTime.compareTo(b.startTime));
          return items;
        }
      }
    } catch (e) {
      developer.log('fetchAttendanceSchedules from schedule-data error: $e', name: 'AttendanceRepo');
    }

    // Fallback: try per-type query if endpoint accepts query parameters
    final configsMap = <String, Map<String, String>>{};
    for (final cfg in defaultSessionConfigs) {
      configsMap[cfg['key']!] = Map<String, String>.from(cfg);
    }

    if (existingSchedules != null && existingSchedules.isNotEmpty) {
      for (final item in existingSchedules) {
        configsMap[item.sessionKey] = {
          'key': item.sessionKey,
          'name': item.sessionName,
          'icon': item.iconName,
          'defaultStart': item.startTime,
          'defaultEnd': item.endTime,
        };
      }
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      final schedules = await Future.wait(
        configsMap.values.map((cfg) async {
          final key = cfg['key']!;
          final name = cfg['name']!;
          final icon = cfg['icon']!;
          String start = cfg['defaultStart']!;
          String end = cfg['defaultEnd']!;
          bool hasValidApiTiming = false;

          try {
            final res = await dio.get(
              AppConfig.attendanceScheduleUrl,
              queryParameters: {'type': key},
            );

            if (res.data is Map && res.data['success'] == true && res.data['data'] is Map) {
              final data = res.data['data'] as Map;
              final sTime = data['start_time']?.toString();
              final eTime = data['end_time']?.toString();

              if (sTime != null && sTime.isNotEmpty && sTime != '00:00' && sTime != '00:00:00') {
                start = sTime.length >= 5 ? sTime.substring(0, 5) : sTime;
                hasValidApiTiming = true;
              }
              if (eTime != null && eTime.isNotEmpty && eTime != '00:00' && eTime != '00:00:00') {
                end = eTime.length >= 5 ? eTime.substring(0, 5) : eTime;
                hasValidApiTiming = true;
              }
            }
          } catch (_) {}

          if (!hasValidApiTiming) {
            return null;
          }

          return AttendanceScheduleItem(
            sessionKey: key,
            sessionName: name,
            iconName: icon,
            startTime: start,
            endTime: end,
          );
        }),
      );

      final activeSchedules = schedules.whereType<AttendanceScheduleItem>().toList();
      if (activeSchedules.isNotEmpty) {
        activeSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));
        return activeSchedules;
      }
    } catch (e) {
      developer.log('fetchAttendanceSchedules fallback error: $e', name: 'AttendanceRepo');
    }

    return const [
      AttendanceScheduleItem(
        sessionKey: 'aarti',
        sessionName: 'Aarti',
        iconName: 'users',
        startTime: '18:45',
        endTime: '19:20',
        lateTime: '19:10',
      ),
      AttendanceScheduleItem(
        sessionKey: 'weekly_assembly',
        sessionName: 'Weekly Assembly',
        iconName: 'users',
        startTime: '20:50',
        endTime: '21:20',
        lateTime: '21:16',
      ),
      AttendanceScheduleItem(
        sessionKey: 'night',
        sessionName: 'Night',
        iconName: 'moon',
        startTime: '22:30',
        endTime: '23:05',
      ),
    ];
  }

  /// Get student's live attendance status & all daily session schedules
  /// `GET /api/attendance/my-status`
  Future<StudentAttendanceStatus> getStudentStatus() async {
    try {
      final response = await _dio.get(
        '/attendance/my-status',
        options: await _authOptions(),
      );
      final rawData = response.data['data'];
      if (rawData is Map) {
        final status = StudentAttendanceStatus.fromJson(Map<String, dynamic>.from(rawData));
        if (status.alreadyMarked && status.activeType != null) {
          _mockMarkedToday[status.activeType!] = DateTime.now();
        }
        return status;
      }
    } catch (e) {
      developer.log('Error fetching student status: $e', name: 'AttendanceRepo');
    }

    // Fallback default schedules matching actual configured sessions
    final fallbackSchedules = [
      const AttendanceScheduleItem(
        sessionKey: 'aarti',
        sessionName: 'Aarti Attendance',
        iconName: 'fire',
        startTime: '07:00',
        endTime: '19:30',
      ),
      const AttendanceScheduleItem(
        sessionKey: 'morning',
        sessionName: 'Morning Attendance',
        iconName: 'fire',
        startTime: '06:00',
        endTime: '07:00',
      ),
      const AttendanceScheduleItem(
        sessionKey: 'night',
        sessionName: 'Night Attendance',
        iconName: 'moon',
        startTime: '22:30',
        endTime: '23:05',
      ),
    ];

    return StudentAttendanceStatus(
      alreadyMarked: false,
      attendanceActive: true,
      activeSessionType: 'night',
      sessionName: 'Night Attendance',
      startTime: '22:30',
      endTime: '23:05',
      allSchedules: fallbackSchedules,
    );
  }

  /// Student self-mark attendance via dynamic QR scan, BLE proximity, or direct button
  /// `POST /api/attendance/mark`
  Future<AttendanceRecord> mark(MarkAttendanceRequest request) async {
    try {
      final response = await _dio.post(
        '/attendance/mark',
        data: request.toJson(),
        options: await _authOptions(),
      );
      final rawData = response.data['data'];
      final record = AttendanceRecord.fromJson(
        rawData is Map<String, dynamic>
            ? rawData
            : {
                'type': request.sessionKey ?? request.type.apiValue,
                'session_key': request.sessionKey ?? request.type.apiValue,
                'session_type': request.sessionKey ?? request.type.apiValue,
                'viaCode': request.viaCode,
              },
      );
      _mockMarkedToday[request.type] = record.time;
      return record;
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
      }
      developer.log('mark attendance connection error, recording locally', name: 'AttendanceRepo');
      final now = DateTime.now().toUtc();
      final record = AttendanceRecord(
        id: DateTime.now().millisecondsSinceEpoch,
        date: now,
        time: now,
        type: request.type,
        sessionKey: request.sessionKey ?? request.type.apiValue,
        viaCode: request.viaCode,
      );
      _mockMarkedToday[request.type] = now;
      _mockHistory.insert(0, record);
      return record;
    }
  }

  /// Admin/Warden manual attendance on behalf of a student
  /// `POST /api/attendance`
  Future<AttendanceRecord> markAdminAttendance(
    MarkAttendanceOnBehalfRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/attendance',
        data: request.toJson(),
        options: await _authOptions(),
      );
      final rawData = response.data['data'];
      return AttendanceRecord.fromJson(
        rawData is Map<String, dynamic> ? rawData : request.toJson(),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
      }
      developer.log('markAdminAttendance connection error, saving locally', name: 'AttendanceRepo');
      final record = AttendanceRecord(
        id: DateTime.now().millisecondsSinceEpoch,
        aadhar: request.studentAadhar,
        date: request.date,
        time: request.date,
        type: request.type,
        viaCode: false,
      );
      _mockHistory.insert(0, record);
      return record;
    }
  }

  /// Query today's attendance status across all events
  Future<Map<AttendanceType, DateTime?>> todayStatus() async {
    final statusMap = <AttendanceType, DateTime?>{
      for (final t in AttendanceType.values) t: _mockMarkedToday[t],
    };

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final logs = await history(
        from: DateTime.parse(todayStr),
        to: DateTime.now(),
      );
      for (final log in logs) {
        statusMap[log.type] = log.time;
        _mockMarkedToday[log.type] = log.time;
      }
    } catch (_) {
      // Keep mock or cached status if network error
    }

    return statusMap;
  }

  /// Fetch attendance history with filters
  /// `GET /api/attendance?type={type}&startDate={YYYY-MM-DD}&endDate={YYYY-MM-DD}&limit=50&offset=0`
  Future<List<AttendanceRecord>> history({
    DateTime? from,
    DateTime? to,
    AttendanceType? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (type != null) query['type'] = type.apiValue;
      if (from != null) query['startDate'] = DateFormat('yyyy-MM-dd').format(from);
      if (to != null) query['endDate'] = DateFormat('yyyy-MM-dd').format(to);

      final response = await _dio.get(
        '/attendance',
        queryParameters: query,
        options: await _authOptions(),
      );

      final body = response.data;
      final data = body is Map ? body['data'] : null;
      List list = [];
      if (data is Map) {
        if (data['logs'] is List) {
          list = data['logs'] as List;
        } else if (data['attendance'] is List) {
          list = data['attendance'] as List;
        } else if (data['records'] is List) {
          list = data['records'] as List;
        } else if (data['history'] is List) {
          list = data['history'] as List;
        }
      } else if (data is List) {
        list = data;
      } else if (body is Map) {
        if (body['logs'] is List) {
          list = body['logs'] as List;
        } else if (body['attendance'] is List) {
          list = body['attendance'] as List;
        } else if (body['records'] is List) {
          list = body['records'] as List;
        }
      }

      final records = list
          .map((item) {
            if (item is Map) {
              return AttendanceRecord.fromJson(Map<String, dynamic>.from(item));
            }
            return null;
          })
          .whereType<AttendanceRecord>()
          .toList();

      return records;
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
      }
    } catch (_) {}

    // Return filtered local history when offline or empty
    return _mockHistory.where((e) {
      if (type != null && e.type != type) return false;
      if (from != null && e.date.isBefore(from)) return false;
      if (to != null && e.date.isAfter(to)) return false;
      return true;
    }).toList();
  }

  /// List scheduled Sabhas
  /// `GET /api/attendance/sabhas`
  Future<List<SabhaSession>> upcomingSabhas() async {
    try {
      final response = await _dio.get(
        '/attendance/sabhas',
        options: await _authOptions(),
      );
      final data = response.data['data'];
      List list = [];
      if (data is Map && data['sabhas'] is List) {
        list = data['sabhas'] as List;
      } else if (data is List) {
        list = data;
      }
      final items = list
          .map((item) => SabhaSession.fromJson(item as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    } catch (_) {}
    return List.unmodifiable(_mockSabhas);
  }

  /// Schedule a new Sabha (Admin/Warden)
  /// `POST /api/attendance/admin/sabhas`
  Future<SabhaSession> scheduleSabha(ScheduleSabhaRequest request) async {
    try {
      final response = await _dio.post(
        '/attendance/admin/sabhas',
        data: request.toJson(),
        options: await _authOptions(),
      );
      final rawData = response.data['data'];
      final session = SabhaSession.fromJson(
        rawData is Map<String, dynamic> ? rawData : request.toJson(),
      );
      _mockSabhas.add(session);
      return session;
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
      }
      final session = SabhaSession(
        id: 'sabha-${DateTime.now().millisecondsSinceEpoch}',
        date: request.date,
        description: request.title,
        current: request.current,
        startTime: request.startTime,
        endTime: request.endTime,
      );
      _mockSabhas.add(session);
      return session;
    }
  }

  /// Delete a scheduled Sabha (Admin/Warden)
  /// `DELETE /api/attendance/admin/sabhas/:id`
  Future<void> deleteSabha(String id) async {
    try {
      await _dio.delete(
        '/attendance/admin/sabhas/$id',
        options: await _authOptions(),
      );
      _mockSabhas.removeWhere((s) => s.id == id);
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
      }
      _mockSabhas.removeWhere((s) => s.id == id);
    }
  }

  /// Get active attendance dates
  /// `GET /api/attendance/dates`
  Future<List<String>> getActiveDates() async {
    try {
      final response = await _dio.get(
        '/attendance/dates',
        options: await _authOptions(),
      );
      final data = response.data['data'];
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return [today];
  }
}
