class LoginRequest {
  final String studentId;
  final String? email;
  final String? password;

  const LoginRequest({
    String? studentId,
    String? email,
    this.password,
  })  : studentId = studentId ?? email ?? '',
        email = email ?? studentId;

  Map<String, dynamic> toJson() => {
        'username': studentId,
        'bank_code': studentId,
        'student_id': studentId,
        'email': email ?? studentId,
        'password': password ?? '',
      };
}

class RegisterRequest {
  final String name;
  final String email;
  final String password;

  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'password': password,
      };
}
