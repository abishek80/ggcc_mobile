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

  /// True only for the employee who manages a branch's attendance.
  /// Gates the "Branch Attendance" feature.
  final bool isBranchIncharge;

  UserModel({
    required this.id,
    required this.name,
    required this.loginCode,
    required this.mobile,
    required this.designation,
    required this.profileImg,
    required this.isAdmin,
    required this.permissions,
    this.isBranchIncharge = false,
  });

  /// Strict boolean parse: only `true` / 1 / "1" / "true" count as true.
  static bool parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == '1' || v == 'true';
    }
    return false;
  }

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
      isBranchIncharge: parseBool(json['is_branch_incharge']),
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
      'is_branch_incharge': isBranchIncharge,
    };
  }
}
