import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/common_enums/admission_status.dart';
import 'package:hsh_app2/common_models/student_profile/student_profile_model.dart';
import 'package:hsh_app2/network/api_client.dart';
import 'package:hsh_app2/network/repository/student_profile/student_profile_repository.dart';

void main() {
  setUp(() {
    Get.put(ApiClient.create());
  });

  tearDown(() {
    Get.reset();
  });

  test('StudentProfileModel correctly parses external AVD student JSON', () {
    final json = {
      "firstName": "Harshil",
      "middleName": "Vijaybhai ",
      "lastName": "Patel ",
      "phone": "9725714912",
      "fatherPhone": "9723414912",
      "motherPhone": "9586472972",
      "whatsAppNumber": "9725714912",
      "email": "harshil2937patel@gmail.com",
      "dob": "2007-03-29",
      "groupName": "Pavitra",
      "room": "913",
      "bankCode": "0987",
      "aadhar": "810200748347",
      "status": "renewed-admission"
    };

    final profile = StudentProfileModel.fromJson(json);

    expect(profile.firstName, 'Harshil');
    expect(profile.middleName, 'Vijaybhai');
    expect(profile.lastName, 'Patel');
    expect(profile.fullName, 'Harshil Vijaybhai Patel');
    expect(profile.phone, '9725714912');
    expect(profile.whatsappNumber, '9725714912');
    expect(profile.email, 'harshil2937patel@gmail.com');
    expect(profile.dob, '2007-03-29');
    expect(profile.room, '913');
    expect(profile.groupName, 'Pavitra');
    expect(profile.bankCode, '0987');
    expect(profile.aadhar, '810200748347');
    expect(profile.fatherPhone, '9723414912');
    expect(profile.motherPhone, '9586472972');
    expect(profile.status, AdmissionStatus.active);
  });

  test('matchStudent correctly identifies target student by phone, aadhar, or bank code', () {
    final repo = StudentProfileRepository();
    final sampleList = [
      {
        "firstName": "Other",
        "lastName": "Student",
        "phone": "9999999999",
        "whatsAppNumber": "9999999999",
        "email": "other@example.com",
        "bankCode": "1234",
        "aadhar": "111122223333",
        "status": "active"
      },
      {
        "firstName": "Harshil",
        "middleName": "Vijaybhai ",
        "lastName": "Patel ",
        "phone": "9725714912",
        "fatherPhone": "9723414912",
        "motherPhone": "9586472972",
        "whatsAppNumber": "9725714912",
        "email": "harshil2937patel@gmail.com",
        "dob": "2007-03-29",
        "groupName": "Pavitra",
        "room": "913",
        "bankCode": "0987",
        "aadhar": "810200748347",
        "status": "renewed-admission"
      }
    ];

    // Match by phone
    final byPhone = repo.matchStudent(sampleList, phone: '9725714912');
    expect(byPhone, isNotNull);
    expect(byPhone!['firstName'], 'Harshil');

    // Match by aadhar
    final byAadhar = repo.matchStudent(sampleList, aadhar: '810200748347');
    expect(byAadhar, isNotNull);
    expect(byAadhar!['firstName'], 'Harshil');

    // Match by bank code
    final byCode = repo.matchStudent(sampleList, studentCode: '0987');
    expect(byCode, isNotNull);
    expect(byCode!['firstName'], 'Harshil');

    // Match by normalized bank code
    final byNormCode = repo.matchStudent(sampleList, studentCode: '987');
    expect(byNormCode, isNotNull);
    expect(byNormCode!['firstName'], 'Harshil');

    // Match by email
    final byEmail = repo.matchStudent(sampleList, email: 'harshil2937patel@gmail.com');
    expect(byEmail, isNotNull);
    expect(byEmail!['firstName'], 'Harshil');
  });

  test('fetchProfile successfully fetches live details from external AVD API for student 9725714912', () async {
    final repo = StudentProfileRepository();
    final profile = await repo.fetchProfile(phone: '9725714912');

    expect(profile.firstName, 'Harshil');
    expect(profile.phone, '9725714912');
    expect(profile.whatsappNumber, '9725714912');
    expect(profile.email, 'harshil2937patel@gmail.com');
    expect(profile.dob, '2007-03-29');
    expect(profile.room, '913');
    expect(profile.groupName, 'Pavitra');
    expect(profile.bankCode, '0987');
    expect(profile.aadhar, '810200748347');
    expect(profile.fatherPhone, '9723414912');
    expect(profile.motherPhone, '9586472972');
    expect(profile.status, AdmissionStatus.active);
  });
}
