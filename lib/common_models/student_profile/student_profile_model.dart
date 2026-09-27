import '../../common_enums/admission_status.dart';

/// Shared student profile model — used by the student's own Profile screen
/// and by the operator directory/admin edit screens alike.
class StudentProfileModel {
  final String aadhar;
  final String firstName;
  final String middleName;
  final String lastName;
  final String phone;
  final String whatsappNumber;
  final String email;
  final String room;
  final AdmissionStatus status;
  final String subStatus;
  final String bloodGroup;
  final String dob;

  final String address;
  final String pinCode;

  final String fatherFirstName;
  final String fatherPhone;
  final String fatherProfession;
  final String motherFirstName;
  final String motherPhone;

  final bool playsCricket;
  final bool playsBadminton;
  final bool goesToGym;

  final String vehicleNumber;

  final String category;
  final String groupName;
  final String bankCode;
  final bool bankCodeChecked;
  final String notes;

  const StudentProfileModel({
    required this.aadhar,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.phone,
    this.whatsappNumber = '',
    required this.email,
    required this.room,
    this.status = AdmissionStatus.active,
    this.subStatus = '',
    this.bloodGroup = '',
    this.dob = '',
    this.address = '',
    this.pinCode = '',
    this.fatherFirstName = '',
    this.fatherPhone = '',
    this.fatherProfession = '',
    this.motherFirstName = '',
    this.motherPhone = '',
    this.playsCricket = false,
    this.playsBadminton = false,
    this.goesToGym = false,
    this.vehicleNumber = '',
    this.category = '',
    this.groupName = '',
    this.bankCode = '',
    this.bankCodeChecked = false,
    this.notes = '',
  });

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((e) => e.trim().isNotEmpty).join(' ');

  /// Parses student data from backend or external AVD API.
  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      aadhar: json['aadhar']?.toString().trim() ?? '',
      firstName: json['firstName']?.toString().trim() ?? '',
      middleName: json['middleName']?.toString().trim() ?? '',
      lastName: json['lastName']?.toString().trim() ?? '',
      phone: json['phone']?.toString().trim() ??
          json['phone_number']?.toString().trim() ??
          '',
      whatsappNumber: json['whatsAppNumber']?.toString().trim() ??
          json['whatsappNumber']?.toString().trim() ??
          json['whats_app_number']?.toString().trim() ??
          '',
      email: json['email']?.toString().trim() ?? '',
      room: json['room']?.toString().trim() ??
          json['room_number']?.toString().trim() ??
          '',
      status: statusFromApi(json['status']?.toString()),
      subStatus: json['subStatus']?.toString().trim() ?? '',
      bloodGroup: json['bloodGroup']?.toString().trim() ??
          json['blood_group']?.toString().trim() ??
          '',
      dob: json['dob']?.toString().trim() ??
          json['date_of_birth']?.toString().trim() ??
          '',
      address: json['address']?.toString().trim() ?? '',
      pinCode: json['pinCode']?.toString().trim() ??
          json['pin_code']?.toString().trim() ??
          '',
      fatherFirstName: json['fatherFirstName']?.toString().trim() ?? '',
      fatherPhone: json['fatherPhone']?.toString().trim() ??
          json['father_phone']?.toString().trim() ??
          '',
      fatherProfession: json['fatherProfession']?.toString().trim() ?? '',
      motherFirstName: json['motherFirstName']?.toString().trim() ?? '',
      motherPhone: json['motherPhone']?.toString().trim() ??
          json['mother_phone']?.toString().trim() ??
          '',
      playsCricket: json['cricket'] as bool? ?? false,
      playsBadminton: json['badminton'] as bool? ?? false,
      goesToGym: json['gym'] as bool? ?? false,
      vehicleNumber: json['vehicleNumber']?.toString().trim() ??
          json['vehicle_number']?.toString().trim() ??
          '',
      category: json['category']?.toString().trim() ?? '',
      groupName: json['groupName']?.toString().trim() ??
          json['group_name']?.toString().trim() ??
          '',
      bankCode: json['bankCode']?.toString().trim() ??
          json['bank_code']?.toString().trim() ??
          '',
      bankCodeChecked: json['bankCodeChecked'] as bool? ?? false,
      notes: json['notes']?.toString().trim() ?? '',
    );
  }

  static AdmissionStatus statusFromApi(String? value) {
    final lower = value?.toLowerCase().trim();
    switch (lower) {
      case 'staying':
      case 'active':
      case 'renewed-admission':
      case 'new-admission':
        return AdmissionStatus.active;
      case 'left':
      case 'rejected-admission':
        return AdmissionStatus.left;
      case 'pending':
      case 'pendingapproval':
      case 'pending-admission':
        return AdmissionStatus.pendingApproval;
      default:
        return AdmissionStatus.active;
    }
  }

  StudentProfileModel mergeWith(StudentProfileModel other) {
    return StudentProfileModel(
      aadhar: other.aadhar.isNotEmpty ? other.aadhar : aadhar,
      firstName: other.firstName.isNotEmpty ? other.firstName : firstName,
      middleName: other.middleName.isNotEmpty ? other.middleName : middleName,
      lastName: other.lastName.isNotEmpty ? other.lastName : lastName,
      phone: other.phone.isNotEmpty ? other.phone : phone,
      whatsappNumber: other.whatsappNumber.isNotEmpty
          ? other.whatsappNumber
          : whatsappNumber,
      email: other.email.isNotEmpty ? other.email : email,
      room: other.room.isNotEmpty ? other.room : room,
      status: other.status,
      subStatus: other.subStatus.isNotEmpty ? other.subStatus : subStatus,
      bloodGroup: other.bloodGroup.isNotEmpty ? other.bloodGroup : bloodGroup,
      dob: other.dob.isNotEmpty ? other.dob : dob,
      address: other.address.isNotEmpty ? other.address : address,
      pinCode: other.pinCode.isNotEmpty ? other.pinCode : pinCode,
      fatherFirstName: other.fatherFirstName.isNotEmpty
          ? other.fatherFirstName
          : fatherFirstName,
      fatherPhone: other.fatherPhone.isNotEmpty
          ? other.fatherPhone
          : fatherPhone,
      fatherProfession: other.fatherProfession.isNotEmpty
          ? other.fatherProfession
          : fatherProfession,
      motherFirstName: other.motherFirstName.isNotEmpty
          ? other.motherFirstName
          : motherFirstName,
      motherPhone: other.motherPhone.isNotEmpty
          ? other.motherPhone
          : motherPhone,
      playsCricket: other.playsCricket || playsCricket,
      playsBadminton: other.playsBadminton || playsBadminton,
      goesToGym: other.goesToGym || goesToGym,
      vehicleNumber: other.vehicleNumber.isNotEmpty
          ? other.vehicleNumber
          : vehicleNumber,
      category: other.category.isNotEmpty ? other.category : category,
      groupName: other.groupName.isNotEmpty ? other.groupName : groupName,
      bankCode: other.bankCode.isNotEmpty ? other.bankCode : bankCode,
      bankCodeChecked: other.bankCodeChecked || bankCodeChecked,
      notes: other.notes.isNotEmpty ? other.notes : notes,
    );
  }

  /// Fields a student is never allowed to edit on their own profile
  /// (API_HANDOFF.md §5.2). `firstName`/`middleName`/`lastName` are included
  /// too: the backend's update allow-list doesn't mention them, so a name
  /// change would silently be dropped — better to show them as read-only
  /// than let a student believe an edit was saved.
  static const Set<String> studentBlockedFields = {
    'aadhar',
    'email',
    'status',
    'subStatus',
    'room',
    'category',
    'groupName',
    'bankCode',
    'bankCodeChecked',
    'notes',
    'firstName',
    'middleName',
    'lastName',
  };

  static bool isEditableByStudent(String fieldKey) =>
      !studentBlockedFields.contains(fieldKey);

  StudentProfileModel copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? phone,
    String? whatsappNumber,
    String? bloodGroup,
    String? dob,
    String? address,
    String? pinCode,
    String? fatherFirstName,
    String? fatherPhone,
    String? fatherProfession,
    String? motherFirstName,
    String? motherPhone,
    bool? playsCricket,
    bool? playsBadminton,
    bool? goesToGym,
    String? vehicleNumber,
  }) {
    return StudentProfileModel(
      aadhar: aadhar,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email,
      room: room,
      status: status,
      subStatus: subStatus,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      pinCode: pinCode ?? this.pinCode,
      fatherFirstName: fatherFirstName ?? this.fatherFirstName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      fatherProfession: fatherProfession ?? this.fatherProfession,
      motherFirstName: motherFirstName ?? this.motherFirstName,
      motherPhone: motherPhone ?? this.motherPhone,
      playsCricket: playsCricket ?? this.playsCricket,
      playsBadminton: playsBadminton ?? this.playsBadminton,
      goesToGym: goesToGym ?? this.goesToGym,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      category: category,
      groupName: groupName,
      bankCode: bankCode,
      bankCodeChecked: bankCodeChecked,
      notes: notes,
    );
  }

  /// Same allow-list the backend accepts on `PATCH /students/:aadhar`
  /// (API_HANDOFF.md §5.2), keyed by the API's own field names. Lets any
  /// code already holding a full [StudentProfileModel] (e.g. an operator
  /// edit flow) build a safe update payload without hand-picking fields.
  Map<String, dynamic> toUpdateJson() => {
    'whatsAppNumber': whatsappNumber,
    'phone': phone,
    'address': address,
    'pinCode': pinCode,
    'bloodGroup': bloodGroup,
    'fatherFirstName': fatherFirstName,
    'fatherPhone': fatherPhone,
    'fatherProfession': fatherProfession,
    'motherFirstName': motherFirstName,
    'motherPhone': motherPhone,
    'cricket': playsCricket,
    'badminton': playsBadminton,
    'gym': goesToGym,
    'vehicleNumber': vehicleNumber,
  };
}
