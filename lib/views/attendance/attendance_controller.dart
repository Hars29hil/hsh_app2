import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';
import '../../network/responses/attendance/attendance_models.dart';
import '../../storage/session_store.dart';

class AttendanceController extends GetxController with LoadStateMixin {
  final AttendanceRepository _repository = Get.find();

  static const String esp32ServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  // Attendance state matching reference logic
  final alreadyMarked = false.obs;
  final attendanceActive = false.obs;
  final startTime = ''.obs;
  final endTime = ''.obs;
  final rawSchedules = <String, dynamic>{}.obs;

  final todayStatus = <AttendanceType, DateTime?>{}.obs;
  final todaySessionStatus = <String, DateTime?>{}.obs;
  final studentStatus = Rxn<StudentAttendanceStatus>();
  final schedulesList = <AttendanceScheduleItem>[].obs;
  final markingType = Rxn<AttendanceType>();
  final isMarking = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  bool isSessionMarked(String sessionKey, AttendanceType type) {
    final key = sessionKey.toLowerCase().trim();
    return todaySessionStatus[key] != null;
  }

  DateTime? getSessionMarkedTime(String sessionKey, AttendanceType type) {
    final key = sessionKey.toLowerCase().trim();
    return todaySessionStatus[key] ?? todayStatus[type];
  }

  String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('already_marked') ||
        msg.contains('already marked') ||
        msg.contains('student_already_marked')) {
      return 'Your attendance is already marked for today. Come back tomorrow!';
    }
    if (msg.contains('device_already_used')) {
      return 'This device has already been used to mark attendance today.';
    }
    if (msg.contains('no_active_session') ||
        msg.contains('no active') ||
        msg.contains('attendance is closed') ||
        msg.contains('session has ended')) {
      return 'Attendance is not open right now. Please check the schedule and try again during the allowed time.';
    }
    if (msg.contains('session has not started')) {
      return 'Attendance has not started yet. Please wait for the scheduled time.';
    }
    if (msg.contains('bluetooth') ||
        msg.contains('ble') ||
        msg.contains('gatt')) {
      return 'Could not connect to the attendance beacon. Make sure Bluetooth is turned on and you are close to the ESP-32.';
    }
    if (msg.contains('permission')) {
      return 'Bluetooth and Location permissions are needed. Please allow them in your phone settings.';
    }
    if (msg.contains('turn on bluetooth') || msg.contains('adapter')) {
      return 'Please turn on Bluetooth to mark your attendance.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Connection timed out. Please move closer to the floor device and try again.';
    }
    if (msg.contains('could not find') || msg.contains('esp32')) {
      return 'Could not find the attendance beacon. Make sure you are close to an active ESP-32 device and try again.';
    }
    if (msg.contains('floor')) {
      return 'Please go near your hostel ESP-32 beacon and try again.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection refused')) {
      return 'Could not connect to the server. Please check your internet connection.';
    }

    String cleaned = e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '');
    if (cleaned.contains('(') ||
        cleaned.contains('/') ||
        cleaned.contains('.') && cleaned.length > 80) {
      return 'Something went wrong. Please try again or contact your floor leader for help.';
    }
    return cleaned;
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
    try {
      // 1. Fetch student status (mark status, active session, and DB schedules if authenticated)
      final sStatus = await _repository.getStudentStatus();
      studentStatus.value = sStatus;
      attendanceActive.value = sStatus.attendanceActive;
      startTime.value = sStatus.startTime;
      endTime.value = sStatus.endTime;
      rawSchedules.assignAll(sStatus.rawSchedules);

      // 2. Fetch all live attendance schedules from https://attendentsnews.hpys.in/api/schedule-data
      final liveSchedules = await _repository.fetchAttendanceSchedules(
        existingSchedules: sStatus.allSchedules,
      );

      if (liveSchedules.isNotEmpty) {
        schedulesList.assignAll(liveSchedules);
      } else if (sStatus.allSchedules.isNotEmpty) {
        schedulesList.assignAll(sStatus.allSchedules);
      }

      // 3. Load locally cached attendance timestamp per session for today
      for (final s in schedulesList) {
        final key = s.sessionKey.toLowerCase().trim();
        final localMarkedTime = await SessionStore.instance.getMarkedSessionTime(key);
        if (localMarkedTime != null) {
          todaySessionStatus[key] = localMarkedTime;
          todayStatus[s.attendanceType] = localMarkedTime;
        }
      }

      // 4. Fetch today's actual attendance records from backend history
      try {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final logs = await _repository.history(
          from: DateTime.parse(todayStr),
          to: DateTime.now(),
        );
        for (final log in logs) {
          final sKey = log.sessionKey.toLowerCase().trim();
          todaySessionStatus[sKey] = log.time;
          todayStatus[log.type] = log.time;
        }
      } catch (_) {}

      // 5. If server status indicates an active session is marked, record it for that session specifically
      if (sStatus.alreadyMarked && sStatus.activeSessionType != null) {
        final activeKey = sStatus.activeSessionType!.toLowerCase().trim();
        if (todaySessionStatus[activeKey] == null) {
          todaySessionStatus[activeKey] = DateTime.now();
        }
      }

      todaySessionStatus.refresh();
      todayStatus.refresh();
    } catch (_) {}
  }, showLoading: showLoading);

  /// Mark attendance directly or after a scan
  Future<AttendanceRecord?> mark(
    AttendanceType type, {
    String? sessionKey,
    required bool viaCode,
    String? qrToken,
    int? rssi,
  }) async {
    markingType.value = type;
    try {
      final effectiveKey = sessionKey ?? type.apiValue;
      final result = await _repository.mark(
        MarkAttendanceRequest(
          type: type,
          sessionKey: effectiveKey,
          viaCode: viaCode,
          qrToken: qrToken,
          rssi: rssi ?? -50,
        ),
      );
      final key = effectiveKey.toLowerCase().trim();
      todaySessionStatus[key] = result.time;
      todaySessionStatus.refresh();
      todayStatus[type] = result.time;
      todayStatus.refresh();

      try {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await SessionStore.instance.saveLastAttendanceDate(today);
        await SessionStore.instance.saveMarkedSessionDate(key, today);
        await SessionStore.instance.saveMarkedSessionTime(key, result.time);
      } catch (_) {}

      await load(showLoading: false);
      return result;
    } finally {
      markingType.value = null;
    }
  }

  Future<AttendanceRecord?> markWithBle(
    AttendanceType type, {
    String? sessionKey,
  }) async {
    if (markingType.value != null || isMarking.value) return null; // Already marking
    markingType.value = type;
    isMarking.value = true;

    try {
      // 1. Request Bluetooth & Location Permissions on Android
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        if (statuses[Permission.bluetoothScan]?.isPermanentlyDenied == true ||
            statuses[Permission.bluetoothConnect]?.isPermanentlyDenied == true) {
          throw Exception(
            'Bluetooth permissions are needed to detect the floor ESP-32. Please allow them in your phone settings.',
          );
        }

        // Android strictly requires Location Service (GPS toggle) to be ON to discover BLE beacons
        final isLocationEnabled = await Permission.location.serviceStatus.isEnabled;
        if (!isLocationEnabled) {
          throw Exception(
            'Please turn on Device Location (GPS) in your phone settings. Android requires Location to scan for Bluetooth beacons.',
          );
        }
      }

      // 2. Ensure Bluetooth Adapter is Turned On
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            adapterState = await FlutterBluePlus.adapterState.first;
          } catch (_) {}
        }
        if (adapterState != BluetoothAdapterState.on) {
          throw Exception('Please turn on Bluetooth to mark your attendance.');
        }
      }

      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      final targetGuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
      final normalizedTargetUuid = "4fafc2011fb5459e8fccc5c9c331914b";
      int detectedRssi = -50;
      bool deviceFound = false;

      // 3. Listen to BLE Advertisement Packets in proximity
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final advData = r.advertisementData;
          final advName = (r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : advData.advName)
              .trim()
              .toLowerCase();

          bool uuidMatches = advData.serviceUuids.contains(targetGuid) ||
              advData.serviceUuids.any((u) =>
                  u.toString().replaceAll('-', '').toLowerCase() == normalizedTargetUuid);

          bool serviceDataMatches = advData.serviceData.containsKey(targetGuid) ||
              advData.serviceData.keys.any((u) =>
                  u.toString().replaceAll('-', '').toLowerCase() == normalizedTargetUuid);

          bool nameMatches = advName.contains('hostel') ||
              advName.contains('esp32') ||
              advName.contains('floor') ||
              advName.contains('attendance') ||
              advName.contains('hams') ||
              advName.contains('beacon') ||
              advName.contains('hsh') ||
              advName.contains('avd');

          if (uuidMatches || serviceDataMatches || nameMatches) {
            deviceFound = true;
            detectedRssi = r.rssi;
            FlutterBluePlus.stopScan();
            break;
          }
        }
      });

      // 4. Start high-priority BLE scan (timeout 10 seconds for reliable discovery)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      await scanSubscription.cancel();

      // Double check in lastScanResults in case last packet came at stop
      if (!deviceFound) {
        for (final r in FlutterBluePlus.lastScanResults) {
          final advData = r.advertisementData;
          final advName = (r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : advData.advName)
              .trim()
              .toLowerCase();

          bool uuidMatches = advData.serviceUuids.contains(targetGuid) ||
              advData.serviceUuids.any((u) =>
                  u.toString().replaceAll('-', '').toLowerCase() == normalizedTargetUuid);

          bool serviceDataMatches = advData.serviceData.containsKey(targetGuid) ||
              advData.serviceData.keys.any((u) =>
                  u.toString().replaceAll('-', '').toLowerCase() == normalizedTargetUuid);

          bool nameMatches = advName.contains('hostel') ||
              advName.contains('esp32') ||
              advName.contains('floor') ||
              advName.contains('attendance') ||
              advName.contains('hams') ||
              advName.contains('beacon') ||
              advName.contains('hsh') ||
              advName.contains('avd');

          if (uuidMatches || serviceDataMatches || nameMatches) {
            deviceFound = true;
            detectedRssi = r.rssi;
            break;
          }
        }
      }

      if (!deviceFound) {
        throw Exception(
          'Could not find the attendance beacon. Make sure you are in range of an active floor ESP-32 device and try again.',
        );
      }

      final effectiveKey = sessionKey ?? type.apiValue;
      // 5. Send proximity verification with RSSI to backend (no Bluetooth pairing/connection needed)
      final result = await _repository.mark(
        MarkAttendanceRequest(
          type: type,
          sessionKey: effectiveKey,
          viaCode: false,
          rssi: detectedRssi,
        ),
      );

      final key = effectiveKey.toLowerCase().trim();
      // 6. Save attendance success locally and update state
      try {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await SessionStore.instance.saveLastAttendanceDate(today);
        await SessionStore.instance.saveMarkedSessionDate(key, today);
        await SessionStore.instance.saveMarkedSessionTime(key, result.time);
      } catch (_) {}

      todaySessionStatus[key] = result.time;
      todaySessionStatus.refresh();
      todayStatus[type] = result.time;
      todayStatus.refresh();

      // Silent background refresh (no full screen reload / spinner)
      await load(showLoading: false);
      return result;
    } finally {
      markingType.value = null;
      isMarking.value = false;
    }
  }

  void onAttendanceMarked(AttendanceRecord record) {
    final key = record.sessionKey.toLowerCase().trim();
    todaySessionStatus[key] = record.time;
    todaySessionStatus.refresh();
    todayStatus[record.type] = record.time;
    todayStatus.refresh();
  }
}
