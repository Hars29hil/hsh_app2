import 'package:flutter/material.dart';

/// Fixed vocabulary per spec §7.3 — exactly these five, no more, no less.
enum AttendanceType { aarti, morning, lunch, dinner, night, sabha }

extension AttendanceTypeX on AttendanceType {
  static AttendanceType fromApi(String value) {
    final v = value.toLowerCase().trim();
    if (v == 'weekly_assembly' ||
        v == 'weekly assembly' ||
        v == 'assembly' ||
        v == 'sabha') {
      return AttendanceType.sabha;
    }
    return AttendanceType.values.firstWhere(
      (e) => e.name.toLowerCase() == v,
      orElse: () => AttendanceType.aarti,
    );
  }

  String get apiValue => name;

  String get label {
    switch (this) {
      case AttendanceType.aarti:
        return 'Aarti Attendance';
      case AttendanceType.morning:
        return 'Morning Attendance';
      case AttendanceType.lunch:
        return 'Lunch';
      case AttendanceType.dinner:
        return 'Dinner';
      case AttendanceType.night:
        return 'Night Attendance';
      case AttendanceType.sabha:
        return 'Sabha';
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceType.aarti:
      case AttendanceType.morning:
        return Icons.local_fire_department_outlined;
      case AttendanceType.lunch:
        return Icons.lunch_dining_outlined;
      case AttendanceType.dinner:
        return Icons.dinner_dining_outlined;
      case AttendanceType.night:
        return Icons.bedtime_outlined;
      case AttendanceType.sabha:
        return Icons.groups_outlined;
    }
  }
}
