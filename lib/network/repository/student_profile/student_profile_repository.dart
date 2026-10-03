import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../common_models/student_profile/student_profile_model.dart';
import '../../../constants/app_config.dart';
import '../../../storage/session_store.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/student_profile/update_profile_request.dart';
import '../../responses/student_profile/student_basic_details.dart';

class StudentProfileRepository {
  final Dio _dio = Get.find<ApiClient>().dio;
  final Dio _externalDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  List<Map<String, dynamic>>? _cachedExternalList;
  DateTime? _lastExternalFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Fetch all students from external API:
  /// GET https://api.avdvvn.org/public/getStudentBasicDetails
  /// Headers: x-hsh-auth-token: aF92Kx7QmN4Lp8Vz
  Future<List<Map<String, dynamic>>> fetchExternalStudentList({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedExternalList != null &&
        _lastExternalFetchTime != null &&
        now.difference(_lastExternalFetchTime!) < _cacheTtl) {
      return _cachedExternalList!;
    }

    try {
      final response = await _externalDio.get(
        AppConfig.studentBasicDetailsUrl,
        options: Options(
          headers: {
            'x-hsh-auth-token': AppConfig.studentBasicDetailsAuthToken,
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final list = (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        _cachedExternalList = list;
        _lastExternalFetchTime = now;
        return list;
      }
    } catch (e) {
      developer.log(
        'StudentProfileRepository: External API fetch error: $e',
        name: 'StudentProfileRepository',
      );
      if (_cachedExternalList != null) {
        return _cachedExternalList!;
      }
    }
    return _cachedExternalList ?? [];
  }

  void setMockExternalList(List<Map<String, dynamic>> list) {
    _cachedExternalList = list;
    _lastExternalFetchTime = DateTime.now();
  }

  Future<StudentBasicDetails> fetchBasicDetails({bool forceRefresh = false}) async {
    // 1. Get logged-in student identifiers from session
    final sessionCode = await SessionStore.instance.cachedStudentCode;
    final sessionPhone = await SessionStore.instance.cachedPhone;
    final sessionName = await SessionStore.instance.name;
    final sessionRoom = await SessionStore.instance.cachedRoom;

    final rawCode = sessionCode?.trim() ?? '';
    final cleanCode = rawCode.replaceFirst(RegExp(r'^0+'), '');
    final cleanPhone = sessionPhone?.trim().replaceAll(RegExp(r'\D'), '') ?? '';
    final phone10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : '';
    final cleanName = sessionName?.trim().toLowerCase() ?? '';
    final cleanRoom = sessionRoom?.trim() ?? '';

    // 2. Fetch from external AVD API
    final list = await fetchExternalStudentList(forceRefresh: forceRefresh);

    if (list.isNotEmpty) {
      // Pass 1: Strict Bank Code / Student ID match
      if (cleanCode.isNotEmpty) {
        for (final item in list) {
          final itemBank = (item['bankCode']?.toString() ?? '').trim();
          final itemNormBank = itemBank.replaceFirst(RegExp(r'^0+'), '');
          if (itemBank == rawCode || itemNormBank == cleanCode || rawCode == itemNormBank) {
            if (itemBank.isNotEmpty) {
              await SessionStore.instance.cacheStudentCode(itemBank);
            }
            return StudentBasicDetails.fromAvdJson(item);
          }
        }
      }

      // Pass 2: Strict Phone match (last 10 digits must match an actual 10-digit number)
      if (phone10.length >= 10) {
        for (final item in list) {
          final itemPhone = (item['phone']?.toString() ?? '').trim().replaceAll(RegExp(r'\D'), '');
          final item10 = itemPhone.length >= 10 ? itemPhone.substring(itemPhone.length - 10) : '';
          final itemWa = (item['whatsAppNumber']?.toString() ?? '').trim().replaceAll(RegExp(r'\D'), '');
          final wa10 = itemWa.length >= 10 ? itemWa.substring(itemWa.length - 10) : '';

          final isPhoneMatch = item10.length >= 10 && item10 == phone10;
          final isWaMatch = wa10.length >= 10 && wa10 == phone10;
          final isEndsMatch = itemPhone.length >= 10 && itemPhone.endsWith(phone10);

          if (isPhoneMatch || isWaMatch || isEndsMatch) {
            final itemBank = (item['bankCode']?.toString() ?? '').trim();
            if (itemBank.isNotEmpty) {
              await SessionStore.instance.cacheStudentCode(itemBank);
            }
            return StudentBasicDetails.fromAvdJson(item);
          }
        }
      }

      // Pass 3: Match by Room & Student Name
      if (cleanRoom.isNotEmpty && cleanName.isNotEmpty) {
        for (final item in list) {
          final itemRoom = (item['room']?.toString() ?? '').trim();
          if (itemRoom == cleanRoom) {
            final fName = (item['firstName']?.toString() ?? '').trim().toLowerCase();
            final lName = (item['lastName']?.toString() ?? '').trim().toLowerCase();
            if ((fName.length >= 3 && cleanName.contains(fName)) || (lName.length >= 3 && cleanName.contains(lName))) {
              final itemBank = (item['bankCode']?.toString() ?? '').trim();
              if (itemBank.isNotEmpty) {
                await SessionStore.instance.cacheStudentCode(itemBank);
              }
              return StudentBasicDetails.fromAvdJson(item);
            }
          }
        }
      }

      // Pass 4: Match by Full Name exact or both parts
      if (cleanName.length >= 4) {
        for (final item in list) {
          final fName = (item['firstName']?.toString() ?? '').trim().toLowerCase();
          final lName = (item['lastName']?.toString() ?? '').trim().toLowerCase();
          final full = '$fName $lName'.trim();
          if (full.length >= 4 && (full == cleanName || (fName.length >= 3 && lName.length >= 3 && cleanName.contains(fName) && cleanName.contains(lName)))) {
            final itemBank = (item['bankCode']?.toString() ?? '').trim();
            if (itemBank.isNotEmpty) {
              await SessionStore.instance.cacheStudentCode(itemBank);
            }
            return StudentBasicDetails.fromAvdJson(item);
          }
        }
      }
    }

    // 3. Fallback to local session store values (NEVER fall back to a random student from the list!)
    return StudentBasicDetails.fallback(
      name: sessionName,
      room: sessionRoom,
      phone: sessionPhone,
      bankCode: sessionCode,
    );
  }

  /// Finds student details by phone number (matching last 10 digits against student or whatsapp phone)
  Future<StudentBasicDetails?> findStudentByPhone(String phone) async {
    final clean = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.length < 10) return null;
    final phone10 = clean.substring(clean.length - 10);

    final list = await fetchExternalStudentList();
    for (final item in list) {
      final itemPhone = (item['phone']?.toString() ?? '').trim().replaceAll(RegExp(r'\D'), '');
      final item10 = itemPhone.length >= 10 ? itemPhone.substring(itemPhone.length - 10) : '';
      final itemWa = (item['whatsAppNumber']?.toString() ?? '').trim().replaceAll(RegExp(r'\D'), '');
      final wa10 = itemWa.length >= 10 ? itemWa.substring(itemWa.length - 10) : '';

      final isPhoneMatch = item10.length >= 10 && item10 == phone10;
      final isWaMatch = wa10.length >= 10 && wa10 == phone10;
      final isEndsMatch = itemPhone.length >= 10 && itemPhone.endsWith(phone10);

      if (isPhoneMatch || isWaMatch || isEndsMatch) {
        return StudentBasicDetails.fromAvdJson(item);
      }
    }
    return null;
  }

  Future<StudentBasicDetails?> findStudentByCode(String code) async {
    final rawCode = code.trim();
    if (rawCode.isEmpty) return null;
    final cleanCode = rawCode.replaceFirst(RegExp(r'^0+'), '');

    final list = await fetchExternalStudentList();
    for (final item in list) {
      final itemBank = (item['bankCode']?.toString() ?? '').trim();
      final itemNormBank = itemBank.replaceFirst(RegExp(r'^0+'), '');
      if (itemBank == rawCode || itemNormBank == cleanCode || rawCode == itemNormBank) {
        return StudentBasicDetails.fromAvdJson(item);
      }
    }
    return null;
  }

  /// Match a student from the external list using multiple identifier heuristics:
  /// Aadhar, Phone, WhatsApp, BankCode / Student ID, Email, or Name.
  Map<String, dynamic>? matchStudent(
    List<Map<String, dynamic>> list, {
    String? aadhar,
    String? phone,
    String? email,
    String? studentCode,
    String? name,
  }) {
    final cleanAadhar = aadhar?.trim() ?? '';
    final cleanPhone =
        phone?.trim().replaceAll(RegExp(r'\D'), '') ?? '';
    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final cleanCode =
        studentCode?.trim().replaceFirst(RegExp(r'^0+'), '') ?? '';
    final rawCode = studentCode?.trim() ?? '';
    final cleanName = name?.trim().toLowerCase() ?? '';

    for (final item in list) {
      final itemAadhar = (item['aadhar']?.toString() ?? '').trim();
      final itemPhone = (item['phone']?.toString() ?? '')
          .trim()
          .replaceAll(RegExp(r'\D'), '');
      final itemWhatsapp = (item['whatsAppNumber']?.toString() ??
              item['whatsappNumber']?.toString() ??
              '')
          .trim()
          .replaceAll(RegExp(r'\D'), '');
      final itemEmail =
          (item['email']?.toString() ?? '').trim().toLowerCase();
      final itemBank = (item['bankCode']?.toString() ?? '').trim();
      final itemNormBank = itemBank.replaceFirst(RegExp(r'^0+'), '');

      // 1. Match by Aadhar or BankCode in aadhar field
      if (cleanAadhar.isNotEmpty &&
          (itemAadhar == cleanAadhar ||
              itemBank == cleanAadhar ||
              (cleanAadhar.length <= 6 && itemNormBank == cleanAadhar))) {
        return item;
      }

      // 2. Match by Phone or WhatsApp number
      if (cleanPhone.isNotEmpty && cleanPhone.length >= 8) {
        if (itemPhone == cleanPhone ||
            itemWhatsapp == cleanPhone ||
            (cleanPhone.length >= 10 && itemPhone.endsWith(cleanPhone)) ||
            (itemPhone.length >= 10 && cleanPhone.endsWith(itemPhone))) {
          return item;
        }
      }

      // 3. Match by Bank Code / Student Code
      if (cleanCode.isNotEmpty) {
        if (itemBank == rawCode ||
            itemNormBank == cleanCode ||
            rawCode == itemNormBank) {
          return item;
        }
      }

      // 4. Match by Email
      if (cleanEmail.isNotEmpty && cleanEmail == itemEmail) {
        return item;
      }
    }

    // 5. Fallback match by Name if provided
    if (cleanName.isNotEmpty) {
      for (final item in list) {
        final fName =
            (item['firstName']?.toString() ?? '').trim().toLowerCase();
        final lName =
            (item['lastName']?.toString() ?? '').trim().toLowerCase();
        final full = '$fName $lName'.trim();
        if (full.isNotEmpty &&
            (full == cleanName ||
                cleanName.contains(full) ||
                full.contains(cleanName))) {
          return item;
        }
      }
    }

    return null;
  }

  /// Fetches the profile using the external AVD API as the authoritative basic
  /// details provider, enriched with any extra attributes saved on the backend
  /// (blood group, vehicle, address, sports preferences, etc.).
  Future<StudentProfileModel> fetchProfile({
    String? aadhar,
    String? phone,
    String? email,
    String? studentCode,
    String? name,
    bool forceRefresh = false,
  }) async {
    final effectiveAadhar = aadhar?.trim() ?? '';

    // Step 1: Fetch live external student list
    final externalList =
        await fetchExternalStudentList(forceRefresh: forceRefresh);
    final extStudent = matchStudent(
      externalList,
      aadhar: effectiveAadhar,
      phone: phone,
      email: email,
      studentCode: studentCode,
      name: name,
    );

    StudentProfileModel? externalModel;
    if (extStudent != null) {
      externalModel = StudentProfileModel.fromJson(extStudent);
    }

    // Step 2: Try fetching from backend /students/:id or /students/me
    StudentProfileModel? backendModel;
    final lookupId = effectiveAadhar.isNotEmpty
        ? effectiveAadhar
        : (externalModel?.aadhar.isNotEmpty == true
            ? externalModel!.aadhar
            : (studentCode ?? 'me'));

    try {
      final response = await _dio.get('/students/$lookupId');
      final data = response.data;
      if (data is Map<String, dynamic> &&
          data['data'] is Map<String, dynamic> &&
          data['data']['student'] is Map<String, dynamic>) {
        final student = data['data']['student'] as Map<String, dynamic>;
        backendModel = StudentProfileModel.fromJson(student);
      }
    } catch (_) {
      // Backend lookup might fail or not be linked yet — external API takes over.
    }

    // Step 3: Combine external and backend models
    StudentProfileModel finalModel;
    if (backendModel != null && externalModel != null) {
      finalModel = backendModel.mergeWith(externalModel);
    } else if (externalModel != null) {
      finalModel = externalModel;
    } else if (backendModel != null) {
      finalModel = backendModel;
    } else {
      throw ApiException(
        'Student profile could not be loaded. Please verify your connection.',
        statusCode: 404,
      );
    }

    // Step 4: Populate locally cached personal attributes if still blank
    String bloodGroup = finalModel.bloodGroup;
    String vehicleNumber = finalModel.vehicleNumber;
    if (bloodGroup.isEmpty) {
      bloodGroup = (await SessionStore.instance.cachedBloodGroup) ?? '';
    }
    if (vehicleNumber.isEmpty) {
      vehicleNumber =
          (await SessionStore.instance.cachedVehicleNumber) ?? '';
    }

    if (bloodGroup.isNotEmpty != finalModel.bloodGroup.isNotEmpty ||
        vehicleNumber.isNotEmpty != finalModel.vehicleNumber.isNotEmpty) {
      finalModel = finalModel.copyWith(
        bloodGroup: bloodGroup.isNotEmpty ? bloodGroup : null,
        vehicleNumber: vehicleNumber.isNotEmpty ? vehicleNumber : null,
      );
    }

    // Step 5: Update session caches with resolved data
    if (finalModel.aadhar.isNotEmpty) {
      await SessionStore.instance.cacheAadhar(finalModel.aadhar);
    }
    if (finalModel.room.isNotEmpty) {
      await SessionStore.instance.cacheRoom(finalModel.room);
    }
    if (finalModel.phone.isNotEmpty) {
      await SessionStore.instance.cachePhone(finalModel.phone);
    }
    if (finalModel.bankCode.isNotEmpty) {
      await SessionStore.instance.cacheStudentCode(finalModel.bankCode);
    }

    return finalModel;
  }

  Future<StudentProfileModel> updateProfile(
    String aadhar,
    UpdateProfileRequest request,
  ) async {
    // Cache local edits
    if (request.bloodGroup.isNotEmpty) {
      await SessionStore.instance.cacheBloodGroup(request.bloodGroup);
    }
    if (request.vehicleNumber.isNotEmpty) {
      await SessionStore.instance.cacheVehicleNumber(request.vehicleNumber);
    }
    if (request.phone.isNotEmpty) {
      await SessionStore.instance.cachePhone(request.phone);
    }

    try {
      await _dio.patch(
        '/students/$aadhar',
        data: request.toJson(),
      );

      // Re-merge with external details
      return await fetchProfile(
        aadhar: aadhar,
        phone: request.phone,
        forceRefresh: false,
      );
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (_) {
      // If backend patch succeeds partially or offline, return locally updated model
      return await fetchProfile(
        aadhar: aadhar,
        phone: request.phone,
        forceRefresh: false,
      );
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? 'Something went wrong. Please try again.';
  }
}
