import 'package:get/get.dart';
import '../../abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_models/student_profile/student_profile_model.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/repository/student_profile/student_profile_repository.dart';
import '../../constants/app_routes.dart';
import '../../storage/session_store.dart';

class StudentProfileController extends GetxController
    with AadharResolvingMixin, LoadStateMixin {
  final StudentProfileRepository _repository = Get.find();
  final FeesRepository _feesRepository = Get.find();
  final LaundryRepository _laundryRepository = Get.find();

  final Rxn<StudentProfileModel> profile = Rxn<StudentProfileModel>();

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile({bool forceRefresh = false}) => guard(() async {
    final cachedPhone = await SessionStore.instance.cachedPhone;
    final cachedEmail = await SessionStore.instance.email;
    final cachedName = await SessionStore.instance.name;
    final cachedStudentCode = await SessionStore.instance.cachedStudentCode;
    String? aadhar = await SessionStore.instance.cachedAadhar;

    if (aadhar == null || aadhar.isEmpty) {
      try {
        aadhar = await resolveAadhar(
          fromFeeSummary: _feesRepository.resolveAadhar,
          fromLaundryBalance: () async =>
              (await _laundryRepository.balance()).studentAadhar,
        );
      } catch (_) {
        // Fall back gracefully; fetchProfile will resolve from external API
      }
    }

    try {
      profile.value = await _repository.fetchProfile(
        aadhar: aadhar,
        phone: cachedPhone,
        email: cachedEmail,
        studentCode: cachedStudentCode,
        name: cachedName,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      if (aadhar != null && aadhar.isNotEmpty) {
        await SessionStore.instance.clearAadhar();
      }
      rethrow;
    }
  });

  /// Pull-to-refresh / post-edit reload entry point — same as the initial
  /// load, kept as a distinct name so call sites read intent rather than
  /// implementation. (Not named `refresh()`: GetX's `ListNotifierMixin`
  /// already defines that, for forcing a `GetBuilder` rebuild.)
  Future<void> refreshProfile() => loadProfile(forceRefresh: true);

  Future<void> logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }
}
