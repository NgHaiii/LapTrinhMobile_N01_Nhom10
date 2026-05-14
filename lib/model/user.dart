class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String role; // 'customer', 'provider', 'admin'
  final String profilePic;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.profilePic = '',
  });

  // Chuyển dữ liệu từ Firestore (Map) sang Object Dart
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: data['role'] ?? 'customer',
      profilePic: data['profilePic'] ?? '',
    );
  }

  // Chuyển từ Object Dart sang Map để lưu lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
      'profilePic': profilePic,
    };
  }
}