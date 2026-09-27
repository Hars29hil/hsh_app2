import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';
import '../../network/responses/attendance/attendance_models.dart';

class AttendanceController extends GetxController with LoadStateMixin {
  final AttendanceRepository _repository = Get.find();

  static const String esp32ServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  final todayStatus = <AttendanceType, DateTime?>{}.obs;
  final studentStatus = Rxn<StudentAttendanceStatus>();
  final schedulesList = <AttendanceScheduleItem>[].obs;
  final markingType = Rxn<AttendanceType>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    try {
      // 1. Fetch student status (mark status, active session, and DB schedules if authenticated)
      final sStatus = await _repository.getStudentStatus();
      studentStatus.value = sStatus;

      // 2. Fetch all live attendance schedules from https://attendentsnews.hpys.in/api/attendance/schedule
      final liveSchedules = await _repository.fetchAttendanceSchedules(
        existingSchedules: sStatus.allSchedules,
      );

      if (liveSchedules.isNotEmpty) {
        schedulesList.assignAll(liveSchedules);
      } else if (sStatus.allSchedules.isNotEmpty) {
        schedulesList.assignAll(sStatus.allSchedules);
      }

      if (sStatus.alreadyMarked && sStatus.activeType != null) {
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

  /// Mark attendance using BLE beacon proximity detection
  /// No connection or pairing required — verifies proximity via advertising packets.
  Future<AttendanceRecord?> markWithBle(AttendanceType type) async {
    if (markingType.value != null) return null; // Already marking
    markingType.value = type;

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
          'Could not detect floor beacon. Please move closer to the ESP-32 device on your floor.',
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

      todayStatus[type] = result.time;
      todayStatus.refresh();
      await load();
      return result;
    } finally {
      markingType.value = null;
    }
  }

  void onAttendanceMarked(AttendanceRecord record) {
    todayStatus[record.type] = record.time;
    todayStatus.refresh();
  }
}
