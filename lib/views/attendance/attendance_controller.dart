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
  final studentStatus = Rxn<StudentAttendanceStatus>();
  final schedulesList = <AttendanceScheduleItem>[].obs;
  final markingType = Rxn<AttendanceType>();
  final isMarking = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
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

  Future<void> load() => guard(() async {
    try {
      // Check local cached attendance for today
      try {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final markedDate = await SessionStore.instance.lastAttendanceDate;
        if (markedDate == today) {
          alreadyMarked.value = true;
        }
      } catch (_) {}

      // 1. Fetch student status (mark status, active session, and DB schedules if authenticated)
      final sStatus = await _repository.getStudentStatus();
      studentStatus.value = sStatus;
      alreadyMarked.value = sStatus.alreadyMarked || alreadyMarked.value;
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

      if (alreadyMarked.value && sStatus.activeType != null) {
        todayStatus[sStatus.activeType!] = DateTime.now();
      }
    } catch (_) {}
  });

  /// Mark attendance directly or after a scan
  Future<AttendanceRecord?> mark(
    AttendanceType type, {
    required bool viaCode,
    String? qrToken,
    int? rssi,
  }) async {
    markingType.value = type;
    try {
      final result = await _repository.mark(
        MarkAttendanceRequest(
          type: type,
          viaCode: viaCode,
          qrToken: qrToken,
          rssi: rssi ?? -50,
        ),
      );
      todayStatus[type] = result.time;
      todayStatus.refresh();
      await load();
      return result;
    } finally {
      markingType.value = null;
    }
  }

  Future<AttendanceRecord?> markWithBle(AttendanceType type) async {
    if (markingType.value != null || isMarking.value) return null; // Already marking
    markingType.value = type;
    isMarking.value = true;

    try {
      // 1. Request Bluetooth & Location Permissions gracefully across Android versions
      if (Platform.isAndroid) {
        try {
          await [
            Permission.location,
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ].request();
        } catch (_) {}
      }

      // 2. Ensure Bluetooth Adapter is Turned On
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        // Try to turn on on Android if supported
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

      final normalizedTargetUuid = esp32ServiceUuid.replaceAll('-', '').toLowerCase();
      int detectedRssi = -50;
      bool deviceFound = false;
      StreamSubscription<List<ScanResult>>? scanSubscription;

      // 3. Listen to BLE Advertisement Packets in proximity
      final completer = Completer<void>();

      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          final advData = r.advertisementData;
          final advName = (r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : advData.advName)
              .toLowerCase();

          // Match by Target Service UUID (4fafc201-1fb5-459e-8fcc-c5c9c331914b)
          bool uuidMatches = advData.serviceUuids.any(
            (u) => u.toString().replaceAll('-', '').toLowerCase() == normalizedTargetUuid,
          );

          // Match by Service Data keys
          bool serviceDataMatches = advData.serviceData.keys.any(
            (u) => u.toString().replaceAll('-', '').toLowerCase() == normalizedTargetUuid,
          );

          // Match by Device Advertising Name
          bool nameMatches = advName.contains('hostel') ||
              advName.contains('esp32') ||
              advName.contains('floor') ||
              advName.contains('attendance') ||
              advName.contains('hams') ||
              advName.contains('beacon');

          if (uuidMatches || serviceDataMatches || nameMatches) {
            deviceFound = true;
            detectedRssi = r.rssi;
            FlutterBluePlus.stopScan();
            if (!completer.isCompleted) {
              completer.complete();
            }
            break;
          }
        }
      });

      // 4. Start high-priority BLE scan (timeout 8 seconds)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Wait until beacon is detected or scan times out
      await Future.any([
        completer.future,
        FlutterBluePlus.isScanning.where((val) => val == false).first,
      ]);

      await scanSubscription.cancel();

      if (!deviceFound) {
        throw Exception(
          'Could not find the attendance beacon. Make sure you are close to an active ESP-32 device and try again.',
        );
      }

      // 5. Send proximity verification with RSSI to backend (no Bluetooth pairing/connection needed)
      final result = await _repository.mark(
        MarkAttendanceRequest(
          type: type,
          viaCode: false,
          rssi: detectedRssi,
        ),
      );

      // 6. Save attendance success locally and update state
      try {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await SessionStore.instance.saveLastAttendanceDate(today);
      } catch (_) {}

      alreadyMarked.value = true;
      todayStatus[type] = result.time;
      todayStatus.refresh();
      await load();
      return result;
    } finally {
      markingType.value = null;
      isMarking.value = false;
    }
  }

  void onAttendanceMarked(AttendanceRecord record) {
    todayStatus[record.type] = record.time;
    todayStatus.refresh();
    alreadyMarked.value = true;
  }
}
