import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../network/responses/attendance/attendance_models.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_refresh_indicator.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/radar_animation.dart';
import 'attendance_controller.dart';
import 'attendance_event_style.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  final AttendanceController controller = Get.find<AttendanceController>();
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _performBleScan(AttendanceType type) async {
    try {
      final record = await controller.markWithBle(type);
      if (record != null) {
        Get.snackbar(
          'Success!',
          'Your attendance for ${type.label} has been recorded.',
          backgroundColor: AppColors.successGreen,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(AppDimens.gapMd),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Could Not Mark Attendance',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(AppDimens.gapMd),
        duration: const Duration(seconds: 5),
      );
    }
  }

  bool _isTimingActiveNow(String startTime, String endTime) {
    try {
      final now = DateTime.now();
      final curMins = now.hour * 60 + now.minute;
      final startParts = startTime.split(':').map((e) => int.parse(e.trim())).toList();
      final endParts = endTime.split(':').map((e) => int.parse(e.trim())).toList();
      final startMins = startParts[0] * 60 + startParts[1];
      final endMins = endParts[0] * 60 + endParts[1];

      if (startMins <= endMins) {
        return curMins >= startMins && curMins <= endMins;
      } else {
        // Overnight session (e.g. 22:30 to 05:00)
        return curMins >= startMins || curMins <= endMins;
      }
    } catch (_) {
      return false;
    }
  }

  AttendanceScheduleItem? _findNextUpcomingSession(List<AttendanceScheduleItem> list) {
    if (list.isEmpty) return null;
    final now = DateTime.now();
    final curMins = now.hour * 60 + now.minute;
    AttendanceScheduleItem? best;
    int minDiff = 24 * 60 + 1;

    for (final s in list) {
      try {
        final startParts = s.startTime.split(':').map((e) => int.parse(e.trim())).toList();
        final endParts = s.endTime.split(':').map((e) => int.parse(e.trim())).toList();
        final startMins = startParts[0] * 60 + startParts[1];
        final endMins = endParts[0] * 60 + endParts[1];
        if (startMins == 0 && endMins == 0) continue;

        int diff = startMins - curMins;
        if (diff <= 0) {
          diff += 24 * 60; // Next day
        }
        if (diff < minDiff) {
          minDiff = diff;
          best = s;
        }
      } catch (_) {}
    }
    return best ?? list.first;
  }

  IconData _resolveIcon(String? iconName, IconData defaultIcon) {
    switch (iconName?.toLowerCase()) {
      case 'bell':
      case 'fire':
      case 'flame':
        return Icons.local_fire_department_rounded;
      case 'sun':
      case 'morning':
        return Icons.wb_sunny_rounded;
      case 'moon':
      case 'night':
        return Icons.bedtime_rounded;
      case 'lunch':
      case 'food':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      case 'groups':
      case 'users':
      case 'sabha':
        return Icons.groups_rounded;
      case 'book':
      case 'study':
        return Icons.menu_book_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      default:
        return defaultIcon;
    }
  }

  Widget _buildSuccessBanner(String sessionName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.successGreen.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successGreen.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.successGreen,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Attendance Marked!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.successGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have successfully marked attendance for $sessionName.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.successGreen.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionScheduleTile({
    required AttendanceType type,
    required String name,
    required String timing,
    required bool isMarked,
    required DateTime? markedTime,
    required bool isActiveNow,
    String? iconName,
    String? lateTime,
  }) {
    final style = AttendanceEventStyle.of(type);
    final primaryColor = style.primaryColor;
    final iconData = _resolveIcon(iconName, style.icon);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActiveNow
            ? primaryColor.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActiveNow
              ? primaryColor.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.6),
          width: isActiveNow ? 1.5 : 1.0,
        ),
        boxShadow: isActiveNow
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.softBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconData,
              color: primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActiveNow) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      timing,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (lateTime != null && lateTime.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• Late after $lateTime',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warningOrange,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMarked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.successGreen),
                  const SizedBox(width: 4),
                  Text(
                    markedTime != null
                        ? DateFormat('hh:mm a').format(markedTime.toLocal())
                        : 'Done',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
            )
          else if (isActiveNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Open Now',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Upcoming',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) {
            final statusData = controller.studentStatus.value;
            final isMarking = controller.markingType.value != null;

            // Resolve list of session schedules from API or fallback defaults
            final schedules = controller.schedulesList.isNotEmpty
                ? controller.schedulesList.toList()
                : const [
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

            // Resolve currently active or next upcoming session
            final liveItem = schedules.firstWhereOrNull(
              (s) => _isTimingActiveNow(s.startTime, s.endTime),
            );

            final AttendanceScheduleItem targetItem = liveItem ??
                _findNextUpcomingSession(schedules) ??
                schedules.first;

            final activeType = targetItem.attendanceType;
            final isAttendanceOpen = liveItem != null && (statusData?.attendanceActive ?? true);
            final isActiveMarked = controller.todayStatus[activeType] != null ||
                (statusData?.alreadyMarked == true && statusData?.activeType == activeType);

            final activeSessionName = targetItem.sessionName;
            final activeTiming = '${targetItem.startTime} – ${targetItem.endTime}';

            return AppRefreshIndicator(
              onRefresh: controller.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverGradientHeader(
                    overline: DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
                    title: 'Attendance',
                    subtitle: 'Daily routine & verification',
                    expandedHeight: 160.0,
                    actions: [
                      HeaderIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh',
                        onPressed: controller.load,
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.screenPadding),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Attendance Action Card
                                AppCard(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    children: [
                                      if (isActiveMarked)
                                        _buildSuccessBanner(activeSessionName)
                                      else if (!isAttendanceOpen)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          child: Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.warningOrange.withValues(alpha: 0.15),
                                                ),
                                                child: const Icon(
                                                  Icons.schedule_rounded,
                                                  size: 38,
                                                  color: AppColors.warningOrange,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              const Text(
                                                'Attendance is Closed',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Next session ($activeSessionName) window is $activeTiming.',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textMuted,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else ...[
                                        RadarAnimation(
                                          isScanning: isMarking,
                                          color: AppColors.primary,
                                          child: ShaderMask(
                                            shaderCallback: (bounds) =>
                                                const LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.primaryLight,
                                                  ],
                                                ).createShader(bounds),
                                            child: const Icon(
                                              Icons.bluetooth_searching,
                                              size: 48,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          isMarking
                                              ? 'Scanning Beacon...'
                                              : 'Mark $activeSessionName',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Session window: $activeTiming',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Make sure you are on your floor. Bluetooth will automatically connect to the floor device.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: AppButton(
                                            label: 'Mark Attendance Now',
                                            onPressed: isMarking
                                                ? null
                                                : () => _performBleScan(activeType),
                                            isLoading: isMarking,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Today's Full Schedule Section
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Today\'s Sessions',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // List of All Sessions
                                ...schedules.map((item) {
                                  final type = item.attendanceType;
                                  final markedTime = controller.todayStatus[type];
                                  final isMarked = markedTime != null;
                                  final isWindowOpen = _isTimingActiveNow(item.startTime, item.endTime);
                                  final isActiveNow = !isMarked && isWindowOpen && isAttendanceOpen;
                                  final timingStr = '${item.startTime} – ${item.endTime}';

                                  return _buildSessionScheduleTile(
                                    type: type,
                                    name: item.sessionName,
                                    timing: timingStr,
                                    isMarked: isMarked,
                                    markedTime: markedTime,
                                    isActiveNow: isActiveNow,
                                    iconName: item.iconName,
                                    lateTime: item.lateTime,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
