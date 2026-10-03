import 'package:get/get.dart';
import 'api_client.dart';
import 'network_controller.dart';
import 'repository/attendance/attendance_repository.dart';
import 'repository/authentication/auth_repository.dart';
import 'repository/floors/floor_strings_repository.dart';
import 'repository/complaints/complaints_repository.dart';
import 'repository/fees/fees_repository.dart';
import 'repository/laundry/laundry_repository.dart';
import 'repository/leave/leave_repository.dart';
import 'repository/operator/operator_repository.dart';
import 'repository/student_profile/student_profile_repository.dart';

/// Repositories are shared across many feature screens (e.g. AttendanceRepository
/// is used by the student Attendance tab and the Operator's
/// attendance-on-behalf-of screen), so they're registered once, permanently,
/// instead of per-feature binding.
class GlobalBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(NetworkController(), permanent: true);
    Get.put(ApiClient.create(), permanent: true);
    Get.put(AuthRepository(), permanent: true);
    Get.put(StudentProfileRepository(), permanent: true);
    Get.put(FloorStringsRepository(), permanent: true);
    Get.put(AttendanceRepository(), permanent: true);
    Get.put(LeaveRepository(), permanent: true);
    Get.put(FeesRepository(), permanent: true);
    Get.put(LaundryRepository(), permanent: true);
    Get.put(ComplaintsRepository(), permanent: true);
    Get.put(OperatorRepository(), permanent: true);
  }
}
