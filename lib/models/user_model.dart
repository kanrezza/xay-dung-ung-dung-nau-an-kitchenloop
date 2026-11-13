import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { blogger, admin }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber; // MỚI: Số điện thoại
  final String address;     // MỚI: Địa chỉ
  final String? avatarUrl;
  final String bio;
  final UserRole role;
  final bool isLocked;
  final List<String> favorites;
  final List<String> followers;
  final DateTime createdAt;
  final String username;


  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber = '', // Mặc định rỗng nếu chưa cập nhật
    this.address = '',     // Mặc định rỗng nếu chưa cập nhật
    this.avatarUrl,
    this.bio = '',
    this.role = UserRole.blogger,
    this.isLocked = false,
    this.favorites = const [],
    this.followers = const [],
    required this.createdAt,
    required this.username,
  });

  // 1. Chuyển đổi từ Firestore (Map) -> Object Dart
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] ?? '',
      name: data['name'] ?? 'Người dùng mới',
      email: data['email'] ?? '',
      
      // Lấy thêm 2 trường mới (có kiểm tra null)
      phoneNumber: data['phoneNumber'] ?? '',
      address: data['address'] ?? '',
      
      avatarUrl: data['avatarUrl'],
      bio: data['bio'] ?? '',
      role: (data['role'] ?? '').toString().trim() == 'admin' ? UserRole.admin : UserRole.blogger,
      isLocked: data['isLocked'] ?? false,
      favorites: List<String>.from(data['favorites'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
      // Hồ sơ tạo ngoài app (script, Console) có thể thiếu createdAt: không để đăng nhập lỗi.
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      username: data['username'] ?? '',
    );
  }

  // 2. Chuyển đổi từ Object Dart -> Map (Lưu lên Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber, // Lưu SĐT
      'address': address,         // Lưu Địa chỉ
      'avatarUrl': avatarUrl,
      'bio': bio,
      'role': role.name,
      'isLocked': isLocked,
      'favorites': favorites,
      'followers': followers,
      'createdAt': Timestamp.fromDate(createdAt),
      'username': username,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? address,
    String? avatarUrl,
    String? bio,
    UserRole? role,
    bool? isLocked,
    List<String>? favorites,
    List<String>? followers,
    DateTime? createdAt,
    String? username,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      isLocked: isLocked ?? this.isLocked,
      favorites: favorites ?? this.favorites,
      followers: followers ?? this.followers,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
    );
  }
}