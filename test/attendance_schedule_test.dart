import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/network/repository/attendance/attendance_repository.dart';
import 'package:hsh_app2/network/api_client.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.put(ApiClient.create());
  });

  tearDown(() {
    Get.reset();
  });

  test('fetchAttendanceSchedules returns actual active sessions from live schedule-data API', () async {
    final repo = AttendanceRepository();
    final schedules = await repo.fetchAttendanceSchedules();

    // Verify active sessions returned from https://attendentsnews.hpys.in/api/schedule-data
    expect(schedules.length >= 3, isTrue);
    final keys = schedules.map((s) => s.sessionKey).toList();
    expect(keys.contains('aarti'), isTrue);
    expect(keys.contains('weekly_assembly'), isTrue);
    expect(keys.contains('night'), isTrue);

    final aarti = schedules.firstWhere((s) => s.sessionKey == 'aarti');
    final weeklyAssembly = schedules.firstWhere((s) => s.sessionKey == 'weekly_assembly');
    final night = schedules.firstWhere((s) => s.sessionKey == 'night');

    expect(aarti.sessionName, 'Aarti');
    expect(weeklyAssembly.sessionName, 'Weekly Assembly');
    expect(night.sessionName, 'Night');

    // Live API timings from https://attendentsnews.hpys.in/api/schedule-data
    expect(aarti.startTime, '18:45');
    expect(aarti.endTime, '19:20');
    expect(aarti.lateTime, '19:10');

    expect(weeklyAssembly.startTime, '20:50');
    expect(weeklyAssembly.endTime, '21:20');
    expect(weeklyAssembly.lateTime, '21:16');

    expect(night.startTime, '22:30');
    expect(night.endTime, '23:00');
  });
}
