import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../common_enums/user_role.dart';

/// Single source of truth for the active user's session credentials.
///
/// Backed by [FlutterSecureStorage] so tokens survive app restart, but also
/// caches in memory so synchronous checks (e.g. inside guards or interceptors)
/// can inspect the token without an `await`.
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kRole = 'user_role';
  static const _kAadhar = 'student_aadhar';
  static const _kEmail = 'user_email';
  static const _kName = 'user_name';
  static const _kRoom = 'student_room';
  static const _kFloorId = 'user_floor_id';
  static const _kPhone = 'user_phone';
  static const _kStudentCode = 'user_student_code';
  static const _kBloodGroup = 'student_blood_group';
  static const _kVehicle = 'student_vehicle';
  static const _kLastAttendanceDate = 'last_attendance_date';

  static const _timeout = Duration(seconds: 5);

  String? _cachedToken;
  UserRole? _cachedRole;
  String? _cachedEmail;
  String? _cachedName;
  String? _cachedAadhar;
  String? _cachedRoom;
  int? _cachedFloorId;
  String? _cachedPhone;
  String? _cachedStudentCode;
  String? _cachedBloodGroup;
  String? _cachedVehicle;
  String? _cachedLastAttendanceDate;

  /// Synchronous access to the currently loaded token in memory.
  String? get currentToken => _cachedToken;

  /// Synchronous access to cached floor id in memory.
  int? get currentFloorId => _cachedFloorId;

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key).timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: read($key) failed or timed out: $e',
        name: 'SessionStore',
      );
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value).timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: write($key) failed or timed out: $e',
        name: 'SessionStore',
      );
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key).timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: delete($key) failed or timed out: $e',
        name: 'SessionStore',
      );
    }
  }

  Future<void> saveSession({
    required String token,
    required UserRole role,
    required String email,
    required String name,
    String? phone,
    String? studentCode,
    String? aadhar,
    String? room,
    int? floorId,
  }) async {
    _cachedToken = token;
    _cachedRole = role;
    _cachedEmail = email;
    _cachedName = name;
    _cachedPhone = (phone != null && phone.isNotEmpty) ? phone : null;
    _cachedStudentCode = (studentCode != null && studentCode.isNotEmpty) ? studentCode : null;
    _cachedAadhar = (aadhar != null && aadhar.isNotEmpty) ? aadhar : null;
    _cachedRoom = (room != null && room.isNotEmpty) ? room : null;
    _cachedFloorId = floorId;

    await clearAadhar();
    final writes = <Future<void>>[
      _write(_kToken, token),
      _write(_kRole, role.apiValue),
      _write(_kEmail, email),
      _write(_kName, name),
    ];
    if (phone != null && phone.isNotEmpty) {
      writes.add(_write(_kPhone, phone));
    } else {
      writes.add(_delete(_kPhone));
    }
    if (studentCode != null && studentCode.isNotEmpty) {
      writes.add(_write(_kStudentCode, studentCode));
    } else {
      writes.add(_delete(_kStudentCode));
    }
    if (aadhar != null && aadhar.isNotEmpty) {
      writes.add(_write(_kAadhar, aadhar));
    }
    if (room != null && room.isNotEmpty) {
      writes.add(_write(_kRoom, room));
    } else {
      writes.add(_delete(_kRoom));
    }
    if (floorId != null) {
      writes.add(_write(_kFloorId, floorId.toString()));
    } else {
      writes.add(_delete(_kFloorId));
    }
    await Future.wait(writes);
  }

  Future<void> clearAadhar() async {
    try {
      await _storage.delete(key: _kAadhar).timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: clearAadhar failed: $e',
        name: 'SessionStore',
      );
    }
  }

  Future<String?> get token async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    _cachedToken = await _read(_kToken);
    return _cachedToken;
  }

  Future<UserRole> get role async {
    if (_cachedRole != null) return _cachedRole!;
    final value = await _read(_kRole);
    _cachedRole = UserRoleX.fromApi(value);
    return _cachedRole!;
  }

  Future<String?> get email async {
    if (_cachedEmail != null) return _cachedEmail;
    _cachedEmail = await _read(_kEmail);
    return _cachedEmail;
  }

  Future<String?> get name async {
    if (_cachedName != null) return _cachedName;
    _cachedName = await _read(_kName);
    return _cachedName;
  }

  Future<void> cachePhone(String phone) {
    _cachedPhone = phone;
    return _write(_kPhone, phone);
  }

  Future<String?> get cachedPhone async {
    if (_cachedPhone != null) return _cachedPhone;
    _cachedPhone = await _read(_kPhone);
    return _cachedPhone;
  }

  Future<void> cacheStudentCode(String code) {
    _cachedStudentCode = code;
    return _write(_kStudentCode, code);
  }

  String? get currentStudentCode => _cachedStudentCode;

  Future<String?> get cachedStudentCode async {
    if (_cachedStudentCode != null) return _cachedStudentCode;
    _cachedStudentCode = await _read(_kStudentCode);
    return _cachedStudentCode;
  }

  Future<void> cacheBloodGroup(String bg) {
    _cachedBloodGroup = bg;
    return _write(_kBloodGroup, bg);
  }

  Future<String?> get cachedBloodGroup async {
    if (_cachedBloodGroup != null) return _cachedBloodGroup;
    _cachedBloodGroup = await _read(_kBloodGroup);
    return _cachedBloodGroup;
  }

  Future<void> cacheVehicleNumber(String vehicle) {
    _cachedVehicle = vehicle;
    return _write(_kVehicle, vehicle);
  }

  Future<String?> get cachedVehicleNumber async {
    if (_cachedVehicle != null) return _cachedVehicle;
    _cachedVehicle = await _read(_kVehicle);
    return _cachedVehicle;
  }

  Future<void> cacheAadhar(String aadhar) {
    _cachedAadhar = aadhar;
    return _write(_kAadhar, aadhar);
  }

  Future<String?> get cachedAadhar async {
    if (_cachedAadhar != null) return _cachedAadhar;
    _cachedAadhar = await _read(_kAadhar);
    return _cachedAadhar;
  }

  Future<void> cacheRoom(String room) {
    _cachedRoom = room;
    return _write(_kRoom, room);
  }

  Future<String?> get cachedRoom async {
    if (_cachedRoom != null) return _cachedRoom;
    _cachedRoom = await _read(_kRoom);
    return _cachedRoom;
  }

  Future<void> cacheFloorId(int floorId) {
    _cachedFloorId = floorId;
    return _write(_kFloorId, floorId.toString());
  }

  Future<int?> get cachedFloorId async {
    if (_cachedFloorId != null) return _cachedFloorId;
    final str = await _read(_kFloorId);
    if (str != null && str.isNotEmpty) {
      _cachedFloorId = int.tryParse(str);
    }
    return _cachedFloorId;
  }

  Future<String?> get lastAttendanceDate async {
    if (_cachedLastAttendanceDate != null) return _cachedLastAttendanceDate;
    _cachedLastAttendanceDate = await _read(_kLastAttendanceDate);
    return _cachedLastAttendanceDate;
  }

  Future<void> saveLastAttendanceDate(String date) {
    _cachedLastAttendanceDate = date;
    return _write(_kLastAttendanceDate, date);
  }

  Future<void> saveMarkedSessionDate(String sessionKey, String date) {
    return _write('last_att_${sessionKey.toLowerCase().trim()}', date);
  }

  Future<String?> getMarkedSessionDate(String sessionKey) {
    return _read('last_att_${sessionKey.toLowerCase().trim()}');
  }

  Future<void> saveMarkedSessionTime(String sessionKey, DateTime time) {
    final today = DateFormat('yyyy-MM-dd').format(time);
    return _write(
      'last_att_time_${sessionKey.toLowerCase().trim()}_$today',
      time.toIso8601String(),
    );
  }

  Future<DateTime?> getMarkedSessionTime(String sessionKey) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final str = await _read('last_att_time_${sessionKey.toLowerCase().trim()}_$today');
    if (str != null && str.isNotEmpty) {
      return DateTime.tryParse(str);
    }
    return null;
  }

  Future<bool> get hasSession async => (await token) != null;

  Future<void> clear() async {
    _cachedToken = null;
    _cachedRole = null;
    _cachedEmail = null;
    _cachedName = null;
    _cachedAadhar = null;
    _cachedRoom = null;
    _cachedFloorId = null;
    _cachedPhone = null;
    _cachedStudentCode = null;
    _cachedBloodGroup = null;
    _cachedVehicle = null;
    _cachedLastAttendanceDate = null;

    try {
      await _storage.deleteAll().timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: clear() failed or timed out: $e',
        name: 'SessionStore',
      );
    }
  }
}
