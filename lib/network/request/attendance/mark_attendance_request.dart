import 'package:intl/intl.dart';
import '../../../common_enums/attendance_type.dart';

/// Student self-attendance request.
/// For dynamic rotating QR scans, [qrToken] is required.
/// The backend automatically resolves the student's Aadhar from the Bearer JWT token.
class MarkAttendanceRequest {
  final AttendanceType type;
  final bool viaCode;
  final String? qrToken;
  final int? rssi; // Added for BLE proximity attendance

  const MarkAttendanceRequest({
    required this.type,
    this.viaCode = true,
    this.qrToken,
    this.rssi,
  });

  Map<String, dynamic> toJson() => {
    'type': type.apiValue,
    'session_type': type.apiValue,
    if (qrToken != null && qrToken!.isNotEmpty) 'qrToken': qrToken,
    if (rssi != null) 'rssi': rssi,
    'viaCode': viaCode,
  };
}

/// Used for the operator's / admin's "attendance on behalf of" manual flow.
/// Accepts either [studentId] or [studentAadhar].
class MarkAttendanceOnBehalfRequest {
  final String? studentAadhar;
  final int? studentId;
  final AttendanceType type;
  final DateTime date;
  final bool viaCode;

  const MarkAttendanceOnBehalfRequest({
    this.studentAadhar,
    this.studentId,
    required this.type,
    required this.date,
    this.viaCode = false,
  });

  Map<String, dynamic> toJson() {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return {
      'type': type.apiValue,
      'session_type': type.apiValue,
      if (studentId != null) 'studentId': studentId,
      if (studentAadhar != null && studentAadhar!.isNotEmpty)
        'aadhar': studentAadhar,
      'date': dateStr,
      'viaCode': viaCode,
    };
  }
}
