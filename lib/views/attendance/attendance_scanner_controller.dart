import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/api_exception.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';
import '../../network/responses/attendance/attendance_models.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import 'attendance_controller.dart';
import 'attendance_event_style.dart';

class AttendanceScannerController extends GetxController {
  final AttendanceRepository _repository = Get.find();

  late final MobileScannerController scannerController;

  final selectedType = AttendanceType.dinner.obs;
  final isTorchOn = false.obs;
  final isVerifying = false.obs;
  final statusMessage = ''.obs;
  final lastScannedToken = ''.obs;
  final successRecord = Rxn<AttendanceRecord>();

  bool _isProcessing = false;

  @override
  void onInit() {
    super.onInit();
    // Pre-select if passed as route argument, else default intelligently based on current device time
    if (Get.arguments is AttendanceType) {
      selectedType.value = Get.arguments as AttendanceType;
    } else {
      selectedType.value = AttendanceEventStyle.defaultEventForNow();
    }

    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }

  void toggleTorch() async {
    await scannerController.toggleTorch();
    isTorchOn.value = !isTorchOn.value;
  }

  void switchCamera() async {
    await scannerController.switchCamera();
  }

  void setEventType(AttendanceType type) {
    selectedType.value = type;
  }

  void onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing || isVerifying.value) return;
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final token = rawValue.trim();
    if (token == lastScannedToken.value && !isVerifying.value) {
      return;
    }

    _processScannedToken(token);
  }

  Future<void> _processScannedToken(String qrToken) async {
    _isProcessing = true;
    isVerifying.value = true;
    lastScannedToken.value = qrToken;

    // Haptic feedback on capture
    HapticFeedback.mediumImpact();

    try {
      final record = await _repository.mark(
        MarkAttendanceRequest(
          type: selectedType.value,
          viaCode: true,
          qrToken: qrToken,
        ),
      );

      HapticFeedback.heavyImpact();
      successRecord.value = record;

      // Update student dashboard if registered
      if (Get.isRegistered<AttendanceController>()) {
        Get.find<AttendanceController>().onAttendanceMarked(record);
        Get.find<AttendanceController>().load(showLoading: false);
      }
    } on ApiException catch (e) {
      developer.log('API Exception on scan: ${e.message}', name: 'AttendanceScanner');
      _handleScanError(e.message, qrToken);
    } catch (e) {
      developer.log('Generic error on scan: $e', name: 'AttendanceScanner');
      _handleScanError('Failed to verify attendance. Please try again.', qrToken);
    } finally {
      isVerifying.value = false;
    }
  }

  void _handleScanError(String message, String qrToken) {
    final lowerMsg = message.toLowerCase();

    // 1. Token Expired Handling
    if (lowerMsg.contains('expired')) {
      statusMessage.value = 'QR Code has expired. Please scan the current code on screen.';
      Get.rawSnackbar(
        messageText: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: Colors.white, size: AppDimens.iconSm),
            const SizedBox(width: AppDimens.gapSm),
            Expanded(
              child: Text(
                'QR Code expired! Please scan the latest code.',
                style: AppTextStyles.bodySm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cancelledRed,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(AppDimens.gapLg),
        borderRadius: AppDimens.radiusMd,
      );
      // Auto-resume scanner after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        _isProcessing = false;
      });
      return;
    }

    // 2. Type Mismatch Handling (e.g., scanned Lunch during Dinner)
    for (final t in AttendanceType.values) {
      if (lowerMsg.contains('is for "${t.apiValue}"') ||
          lowerMsg.contains('for "${t.label.toLowerCase()}"') ||
          lowerMsg.contains('is for ${t.apiValue}')) {
        _promptTypeMismatch(detectedType: t, originalToken: qrToken);
        return;
      }
    }

    // 3. Other errors (duplicate, unauthorized, network)
    statusMessage.value = message;
    Get.rawSnackbar(
      message: message,
      backgroundColor: AppColors.cancelledRed,
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(AppDimens.gapLg),
      borderRadius: AppDimens.radiusMd,
    );

    Future.delayed(const Duration(seconds: 3), () {
      _isProcessing = false;
    });
  }

  void _promptTypeMismatch({
    required AttendanceType detectedType,
    required String originalToken,
  }) {
    final detectedStyle = AttendanceEventStyle.of(detectedType);
    final selectedStyle = AttendanceEventStyle.of(selectedType.value);

    Get.defaultDialog(
      title: 'Event Mismatch',
      titleStyle: AppTextStyles.title,
      middleText:
          'This QR code is for ${detectedStyle.emoji} ${detectedStyle.label}, but you currently have ${selectedStyle.emoji} ${selectedStyle.label} selected.\n\nWould you like to switch to ${detectedStyle.label} and mark attendance?',
      middleTextStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      radius: AppDimens.radiusXl,
      textConfirm: 'Switch & Mark ${detectedStyle.label}',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: detectedStyle.primaryColor,
      onConfirm: () {
        Get.back();
        selectedType.value = detectedType;
        _isProcessing = false;
        _processScannedToken(originalToken);
      },
      onCancel: () {
        _isProcessing = false;
      },
    );
  }

  void resumeScanning() {
    successRecord.value = null;
    statusMessage.value = '';
    _isProcessing = false;
  }
}
