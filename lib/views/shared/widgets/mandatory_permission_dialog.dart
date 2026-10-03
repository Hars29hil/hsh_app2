import 'package:get/get.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../constants/app_colors.dart';
import 'app_button.dart';

/// Non-dismissible mandatory permission dialog.
/// Enforces Phone, Bluetooth, and Location permissions along with hardware toggles.
class MandatoryPermissionDialog extends StatefulWidget {
  final VoidCallback? onAllGranted;

  const MandatoryPermissionDialog({
    super.key,
    this.onAllGranted,
  });

  /// Static helper to check all permissions and prompt the user if any are missing.
  /// Returns `true` only when all mandatory permissions and hardware adapters are satisfied.
  static Future<bool> ensureAllPermissions([BuildContext? context]) async {
    if (!Platform.isAndroid) return true;

    final isAllOk = await checkAllGranted();
    if (isAllOk) return true;

    // Show non-dismissible modal via Get.dialog
    final result = await Get.dialog<bool>(
      const PopScope(
        canPop: false,
        child: MandatoryPermissionDialog(),
      ),
      barrierDismissible: false,
      useSafeArea: true,
    );

    return result ?? false;
  }

  /// Fast boolean check without showing UI
  static Future<bool> checkAllGranted() async {
    if (!Platform.isAndroid) return true;

    try {
      final hasPhone = await Permission.phone.isGranted;

      bool hasBle = false;
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;
      if (scanStatus.isGranted && connectStatus.isGranted) {
        hasBle = true;
      } else {
        final legacyBle = await Permission.bluetooth.isGranted;
        if (legacyBle) hasBle = true;
      }

      final hasLoc = await Permission.location.isGranted ||
          await Permission.locationWhenInUse.isGranted;

      bool isBleOn = false;
      try {
        if (await FlutterBluePlus.isSupported) {
          final state = await FlutterBluePlus.adapterState.first.timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => BluetoothAdapterState.unknown,
          );
          isBleOn = state == BluetoothAdapterState.on;
        } else {
          isBleOn = true; // Fallback for emulator without BLE support
        }
      } catch (_) {
        isBleOn = true;
      }

      final isGpsOn = await Permission.location.serviceStatus.isEnabled;

      return hasPhone && hasBle && hasLoc && isBleOn && isGpsOn;
    } catch (_) {
      return false;
    }
  }

  @override
  State<MandatoryPermissionDialog> createState() =>
      _MandatoryPermissionDialogState();
}

class _MandatoryPermissionDialogState extends State<MandatoryPermissionDialog>
    with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _isRequesting = false;

  bool _hasPhone = false;
  bool _hasBluetooth = false;
  bool _hasLocation = false;
  bool _isBluetoothOn = false;
  bool _isLocationOn = false;
  bool _isPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _evaluateStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluateStatus();
    }
  }

  Future<void> _evaluateStatus() async {
    if (!mounted) return;
    setState(() => _isChecking = true);

    try {
      // 1. Phone permission
      final phoneStatus = await Permission.phone.status;
      _hasPhone = phoneStatus.isGranted;

      // 2. Bluetooth permissions
      final bleScanStatus = await Permission.bluetoothScan.status;
      final bleConnectStatus = await Permission.bluetoothConnect.status;
      final legacyBleStatus = await Permission.bluetooth.status;

      _hasBluetooth = (bleScanStatus.isGranted && bleConnectStatus.isGranted) ||
          legacyBleStatus.isGranted;

      // 3. Location permission
      final locStatus = await Permission.location.status;
      final locWhenInUse = await Permission.locationWhenInUse.status;
      _hasLocation = locStatus.isGranted || locWhenInUse.isGranted;

      // Check for permanently denied states
      _isPermanentlyDenied = phoneStatus.isPermanentlyDenied ||
          bleScanStatus.isPermanentlyDenied ||
          bleConnectStatus.isPermanentlyDenied ||
          locStatus.isPermanentlyDenied;

      // 4. Hardware toggles
      try {
        if (await FlutterBluePlus.isSupported) {
          final bleState = await FlutterBluePlus.adapterState.first.timeout(
            const Duration(milliseconds: 1200),
            onTimeout: () => BluetoothAdapterState.unknown,
          );
          _isBluetoothOn = bleState == BluetoothAdapterState.on;
        } else {
          _isBluetoothOn = true;
        }
      } catch (_) {
        _isBluetoothOn = true;
      }

      _isLocationOn = await Permission.location.serviceStatus.isEnabled;

      // Check if all conditions are met
      if (_hasPhone &&
          _hasBluetooth &&
          _hasLocation &&
          _isBluetoothOn &&
          _isLocationOn) {
        if (mounted) {
          widget.onAllGranted?.call();
          Navigator.of(context, rootNavigator: true).pop(true);
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    try {
      // Request permissions sequentially/grouped
      await [
        Permission.phone,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // If Bluetooth adapter is off, prompt to turn on
      if (!_isBluetoothOn && Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 400));
      await _evaluateStatus();
    } catch (_) {}

    if (mounted) {
      setState(() => _isRequesting = false);
    }
  }

  Future<void> _turnOnBluetooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
      await Future.delayed(const Duration(milliseconds: 600));
      await _evaluateStatus();
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shield Icon with gradient background
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Mandatory Tag
              const Center(
                child: Text(
                  'Permissions Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cancelledRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.cancelledRed.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'MANDATORY FOR ATTENDANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cancelledRed,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To verify your student SIM card and detect your floor beacon, Hari Saurabh requires the following permissions. These cannot be skipped.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Permission Items
              _buildPermissionItem(
                icon: Icons.phone_android_rounded,
                title: 'Phone & SIM Card',
                subtitle: 'Verifies student phone number for hostel security',
                isGranted: _hasPhone,
              ),
              const SizedBox(height: 10),
              _buildPermissionItem(
                icon: Icons.bluetooth_searching_rounded,
                title: 'Bluetooth & Beacon Scan',
                subtitle: !_hasBluetooth
                    ? 'Required to communicate with attendance beacon'
                    : (!_isBluetoothOn
                        ? 'Bluetooth is turned OFF'
                        : 'Bluetooth is active and ready'),
                isGranted: _hasBluetooth && _isBluetoothOn,
                isWarning: _hasBluetooth && !_isBluetoothOn,
              ),
              const SizedBox(height: 10),
              _buildPermissionItem(
                icon: Icons.location_on_rounded,
                title: 'Location Services (GPS)',
                subtitle: !_hasLocation
                    ? 'Mandated by Android OS for BLE discovery'
                    : (!_isLocationOn
                        ? 'Location Service (GPS) is turned OFF'
                        : 'Location scanning is enabled'),
                isGranted: _hasLocation && _isLocationOn,
                isWarning: _hasLocation && !_isLocationOn,
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (_isChecking)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (_isPermanentlyDenied) ...[
                AppButton(
                  label: 'Open App Settings',
                  onPressed: _openSettings,
                  variant: AppButtonVariant.primary,
                ),
                const SizedBox(height: 8),
                const Text(
                  'One or more permissions were denied. Please enable Phone, Bluetooth, and Location in your device settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ] else if (_hasBluetooth && !_isBluetoothOn) ...[
                AppButton(
                  label: 'Turn On Bluetooth',
                  onPressed: _turnOnBluetooth,
                  variant: AppButtonVariant.primary,
                ),
              ] else if (_hasLocation && !_isLocationOn) ...[
                AppButton(
                  label: 'Enable Location (GPS)',
                  onPressed: _openSettings,
                  variant: AppButtonVariant.primary,
                ),
              ] else ...[
                AppButton(
                  label: 'Allow All Permissions',
                  isLoading: _isRequesting,
                  onPressed: _isRequesting ? null : _requestPermissions,
                  variant: AppButtonVariant.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    bool isWarning = false,
  }) {
    final statusColor = isGranted
        ? AppColors.successGreen
        : (isWarning ? AppColors.warningOrange : AppColors.errorRed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: statusColor,
                    fontWeight: isGranted ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isGranted
                ? Icons.check_circle_rounded
                : (isWarning ? Icons.warning_rounded : Icons.cancel_rounded),
            color: statusColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}
