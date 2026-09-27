import '../../../common_enums/attendance_type.dart';

/// Single attendance record returned by the backend (spec v2.0.0).
/// Supports both student self-scans and operator/admin manual entries.
class AttendanceRecord {
  final dynamic id;
  final String? aadhar;
  final DateTime date;
  final DateTime time;
  final AttendanceType type;
  final bool viaCode;
  final String? ip;

  const AttendanceRecord({
    required this.id,
    this.aadhar,
    required this.date,
    required this.time,
    required this.type,
    required this.viaCode,
    this.ip,
  });

  /// Convenience getter matching previous `AttendanceLogEntry.markedAt` interface.
  DateTime get markedAt => time;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toUtc();
      if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    final rawType = json['type']?.toString() ?? json['session_type']?.toString() ?? 'aarti';
    final dateVal = parseDate(json['date'] ?? json['session_date'] ?? json['marked_at']);
    DateTime timeVal;
    if (json['time'] != null || json['marked_at'] != null) {
      final parsedTime = parseDate(json['time'] ?? json['marked_at']);
      if (parsedTime.year <= 1970) {
        timeVal = DateTime.utc(
          dateVal.year,
          dateVal.month,
          dateVal.day,
          parsedTime.hour,
          parsedTime.minute,
          parsedTime.second,
          parsedTime.millisecond,
        );
      } else {
        timeVal = parsedTime;
      }
    } else {
      timeVal = dateVal;
    }

    return AttendanceRecord(
      id: json['id'] ?? json['_id'] ?? 0,
      aadhar: json['aadhar']?.toString() ?? json['student_code']?.toString() ?? json['bank_code']?.toString(),
      date: dateVal,
      time: timeVal,
      type: AttendanceTypeX.fromApi(rawType),
      viaCode: json['viaCode'] == true,
      ip: json['ip']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (aadhar != null) 'aadhar': aadhar,
    'date': date.toIso8601String(),
    'time': time.toIso8601String(),
    'type': type.apiValue,
    'viaCode': viaCode,
    if (ip != null) 'ip': ip,
  };
}

/// Single schedule session configuration from `/api/schedule-data` or `/attendance/schedule`
class AttendanceScheduleItem {
  final int? id;
  final String sessionKey;
  final String sessionName;
  final String iconName;
  final String startTime;
  final String endTime;
  final String? lateTime;
  final bool isForAllStudents;
  final bool isActive;

  const AttendanceScheduleItem({
    this.id,
    required this.sessionKey,
    required this.sessionName,
    this.iconName = 'moon',
    required this.startTime,
    required this.endTime,
    this.lateTime,
    this.isForAllStudents = true,
    this.isActive = true,
  });

  AttendanceType get attendanceType => AttendanceTypeX.fromApi(sessionKey);

  factory AttendanceScheduleItem.fromJson(Map<String, dynamic> json) {
    final rawStart = (json['start_time'] ?? json['start'] ?? '00:00').toString();
    final rawEnd = (json['end_time'] ?? json['end'] ?? '00:00').toString();
    final rawLate = json['late_time']?.toString();

    return AttendanceScheduleItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      sessionKey: (json['session_key'] ?? json['key'] ?? 'aarti').toString().toLowerCase(),
      sessionName: (json['session_name'] ?? json['name'] ?? 'Session').toString(),
      iconName: (json['icon_name'] ?? 'moon').toString(),
      startTime: rawStart.length >= 5 ? rawStart.substring(0, 5) : rawStart,
      endTime: rawEnd.length >= 5 ? rawEnd.substring(0, 5) : rawEnd,
      lateTime: rawLate != null && rawLate.isNotEmpty && rawLate != 'null'
          ? (rawLate.length >= 5 ? rawLate.substring(0, 5) : rawLate)
          : null,
      isForAllStudents: json['is_for_all_students'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'session_key': sessionKey,
    'session_name': sessionName,
    'icon_name': iconName,
    'start_time': startTime,
    'end_time': endTime,
    if (lateTime != null) 'late_time': lateTime,
    'is_for_all_students': isForAllStudents,
    'is_active': isActive,
  };
}

/// Status payload returned by `GET /api/attendance/my-status`
class StudentAttendanceStatus {
  final bool alreadyMarked;
  final bool attendanceActive;
  final String? activeSessionType;
  final String sessionName;
  final String startTime;
  final String endTime;
  final List<AttendanceScheduleItem> allSchedules;

  const StudentAttendanceStatus({
    required this.alreadyMarked,
    required this.attendanceActive,
    this.activeSessionType,
    required this.sessionName,
    required this.startTime,
    required this.endTime,
    required this.allSchedules,
  });

  AttendanceType? get activeType =>
      activeSessionType != null ? AttendanceTypeX.fromApi(activeSessionType!) : null;

  factory StudentAttendanceStatus.fromJson(Map<String, dynamic> json) {
    List schedulesList = [];
    if (json['all_schedules'] is List) {
      schedulesList = json['all_schedules'] as List;
    } else if (json['schedules'] is Map) {
      final map = json['schedules'] as Map;
      schedulesList = map.entries.map((e) {
        final val = e.value is Map ? e.value as Map : {};
        return {
          'session_key': e.key,
          'session_name': val['name'] ?? e.key.toString().toUpperCase(),
          'start_time': val['start'] ?? '00:00',
          'end_time': val['end'] ?? '00:00',
        };
      }).toList();
    }

    final parsedSchedules = schedulesList
        .map((e) => AttendanceScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return StudentAttendanceStatus(
      alreadyMarked: json['already_marked'] == true,
      attendanceActive: json['attendance_active'] == true,
      activeSessionType: json['active_session_type']?.toString(),
      sessionName: (json['session_name'] ?? 'Attendance').toString(),
      startTime: (json['start_time'] ?? '00:00').toString(),
      endTime: (json['end_time'] ?? '00:00').toString(),
      allSchedules: parsedSchedules,
    );
  }
}

/// Response returned by `GET /api/attendance/qr-token?type={type}`.
/// Dynamic signed JWT token valid for 30s (+ 5s server grace window).
class QrTokenResponse {
  final String token;
  final String type;
  final String date;
  final int expiresIn;
  final DateTime expiresAt;

  const QrTokenResponse({
    required this.token,
    required this.type,
    required this.date,
    required this.expiresIn,
    required this.expiresAt,
  });

  factory QrTokenResponse.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expiresAt'];
    final parsedExpiresAt = expiresAtRaw is String
        ? (DateTime.tryParse(expiresAtRaw)?.toUtc() ??
            DateTime.now().toUtc().add(const Duration(seconds: 30)))
        : DateTime.now().toUtc().add(const Duration(seconds: 30));

    return QrTokenResponse(
      token: json['token']?.toString() ?? '',
      type: json['type']?.toString() ?? 'dinner',
      date: json['date']?.toString() ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 30,
      expiresAt: parsedExpiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'type': type,
    'date': date,
    'expiresIn': expiresIn,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

/// Sabha session assembly model returned by `/api/attendance/sabhas`.
class SabhaSession {
  final String id;
  final DateTime date;
  final String description;
  final bool current;
  final DateTime startTime;
  final DateTime endTime;

  const SabhaSession({
    required this.id,
    required this.date,
    String? description,
    String? title,
    this.current = false,
    required this.startTime,
    required this.endTime,
  }) : description = description ?? title ?? 'Sabha';

  /// Alias for backward compatibility with `SabhaResponse.title`
  String get title => description;

  factory SabhaSession.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toUtc();
      if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    return SabhaSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      date: parseDate(json['date']),
      description: (json['description'] ?? json['title'] ?? 'Sabha').toString(),
      current: json['current'] == true,
      startTime: parseDate(json['startTime']),
      endTime: parseDate(json['endTime']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'description': description,
    'current': current,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
  };
}

// Backward-compatible typedefs for existing code
typedef AttendanceMarkResponse = AttendanceRecord;
typedef AttendanceLogEntry = AttendanceRecord;
typedef SabhaResponse = SabhaSession;
