import 'package:flutter/material.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';

/// Harmonized visual tokens, icons, labels, and time-of-day helpers
/// for the 5 Attendance Event types, strictly tied to AppColors and AppTheme.
class AttendanceEventStyle {
  final AttendanceType type;
  final String label;
  final String emoji;
  final IconData icon;
  final Color primaryColor;
  final Color softBackgroundColor;
  final String timingHint;

  const AttendanceEventStyle({
    required this.type,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.primaryColor,
    required this.softBackgroundColor,
    required this.timingHint,
  });

  static AttendanceEventStyle of(AttendanceType type) {
    switch (type) {
      case AttendanceType.aarti:
        return AttendanceEventStyle(
          type: AttendanceType.aarti,
          label: 'Aarti Attendance',
          emoji: '🪔',
          icon: Icons.local_fire_department_rounded,
          primaryColor: AppColors.warningOrange,
          softBackgroundColor: AppColors.warningOrange.withValues(alpha: 0.12),
          timingHint: '07:00 – 19:30',
        );
      case AttendanceType.morning:
        return AttendanceEventStyle(
          type: AttendanceType.morning,
          label: 'Morning Attendance',
          emoji: '🌅',
          icon: Icons.local_fire_department_rounded,
          primaryColor: AppColors.warningOrange,
          softBackgroundColor: AppColors.warningOrange.withValues(alpha: 0.12),
          timingHint: '06:00 – 07:00',
        );
      case AttendanceType.lunch:
        return AttendanceEventStyle(
          type: AttendanceType.lunch,
          label: 'Lunch',
          emoji: '🍛',
          icon: Icons.lunch_dining_rounded,
          primaryColor: AppColors.secondary,
          softBackgroundColor: AppColors.secondary.withValues(alpha: 0.12),
          timingHint: 'Midday session (11:00 AM – 04:00 PM)',
        );
      case AttendanceType.dinner:
        return const AttendanceEventStyle(
          type: AttendanceType.dinner,
          label: 'Dinner',
          emoji: '🍽️',
          icon: Icons.dinner_dining_rounded,
          primaryColor: AppColors.primary,
          softBackgroundColor: AppColors.primarySoft,
          timingHint: 'Evening session (04:00 PM – 09:00 PM)',
        );
      case AttendanceType.night:
        return const AttendanceEventStyle(
          type: AttendanceType.night,
          label: 'Night Attendance',
          emoji: '🌙',
          icon: Icons.bedtime_rounded,
          primaryColor: AppColors.headerBlue,
          softBackgroundColor: AppColors.surfaceMuted,
          timingHint: '22:30 – 23:05',
        );
      case AttendanceType.sabha:
        return AttendanceEventStyle(
          type: AttendanceType.sabha,
          label: 'Sabha',
          emoji: '🙏',
          icon: Icons.groups_rounded,
          primaryColor: AppColors.cancelledRed,
          softBackgroundColor: AppColors.cancelledRed.withValues(alpha: 0.12),
          timingHint: 'Scheduled assembly session',
        );
    }
  }

  /// Intelligently resolves the most probable attendance event
  /// based on current local device time.
  static AttendanceType defaultEventForNow([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final hour = dt.hour;
    final minute = dt.minute;
    final totalMinutes = hour * 60 + minute;

    // 05:00 to 07:30 -> Morning Attendance
    if (totalMinutes >= 5 * 60 && totalMinutes < 7 * 60 + 30) {
      return AttendanceType.morning;
    }
    // 07:30 to 11:00 -> Aarti
    if (totalMinutes >= 7 * 60 + 30 && totalMinutes < 11 * 60) {
      return AttendanceType.aarti;
    }
    // 11:00 to 16:00 -> Lunch
    if (totalMinutes >= 11 * 60 && totalMinutes < 16 * 60) {
      return AttendanceType.lunch;
    }
    // 16:00 to 21:00 -> Dinner
    if (totalMinutes >= 16 * 60 && totalMinutes < 21 * 60) {
      return AttendanceType.dinner;
    }
    // 21:00 to 05:00 -> Night
    return AttendanceType.night;
  }
}
