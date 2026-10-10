import 'dart:convert';

class UserModel {
  final String id;
  final String name;
  final String loginCode;
  final String mobile;
  final String designation;
  final String profileImg;
  final String isAdmin;
  final List<String> permissions;

  UserModel({
    required this.id,
    required this.name,
    required this.loginCode,
    required this.mobile,
    required this.designation,
    required this.profileImg,
    required this.isAdmin,
    required this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedPermissions = [];
    if (json['permission'] != null) {
      if (json['permission'] is String) {
        try {
          final decoded = jsonDecode(json['permission'] as String);
          if (decoded is List) {
            parsedPermissions = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      } else if (json['permission'] is List) {
        parsedPermissions = (json['permission'] as List).map((e) => e.toString()).toList();
      }
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      loginCode: json['login_code']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      profileImg: json['profile_img']?.toString() ?? '',
      isAdmin: json['is_admin']?.toString() ?? '0',
      permissions: parsedPermissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'login_code': loginCode,
      'mobile': mobile,
      'designation': designation,
      'profile_img': profileImg,
      'is_admin': isAdmin,
      'permission': jsonEncode(permissions),
    };
  }
}
