class StudentBasicDetails {
  final String name;
  final String room;
  final String phone;
  final String bankCode;
  final String email;
  final String groupName;

  const StudentBasicDetails({
    required this.name,
    required this.room,
    required this.phone,
    required this.bankCode,
    this.email = '',
    this.groupName = '',
  });

  factory StudentBasicDetails.fromAvdJson(Map<String, dynamic> json) {
    final fName = (json['firstName']?.toString() ?? '').trim();
    final mName = (json['middleName']?.toString() ?? '').trim();
    final lName = (json['lastName']?.toString() ?? '').trim();
    final fullName = [fName, mName, lName].where((s) => s.isNotEmpty).join(' ');

    return StudentBasicDetails(
      name: fullName.isNotEmpty ? fullName : 'Student',
      room: (json['room']?.toString() ?? '').trim(),
      phone: (json['phone']?.toString() ?? '').trim(),
      bankCode: (json['bankCode']?.toString() ?? '').trim(),
      email: (json['email']?.toString() ?? '').trim(),
      groupName: (json['groupName']?.toString() ?? '').trim(),
    );
  }

  factory StudentBasicDetails.fallback({
    String? name,
    String? room,
    String? phone,
    String? bankCode,
  }) {
    return StudentBasicDetails(
      name: name ?? 'Student',
      room: room ?? '',
      phone: phone ?? '',
      bankCode: bankCode ?? '',
    );
  }
}