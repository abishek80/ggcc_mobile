import 'user_model.dart';

class LoginResponseModel {
  final bool isError;
  final String message;
  final String? token;
  final String? tokenType;
  final String? expiresAt;
  final UserModel? user;

  LoginResponseModel({
    required this.isError,
    required this.message,
    this.token,
    this.tokenType,
    this.expiresAt,
    this.user,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      isError: json['isError'] == true || json['status'] == false || json['error'] == true,
      message: json['message']?.toString() ?? (json['isError'] == true ? 'Login failed' : 'Success'),
      token: json['token']?.toString(),
      tokenType: json['token_type']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}
