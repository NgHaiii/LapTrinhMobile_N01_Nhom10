enum UserRole {
  customer,
  provider,
  admin;

  static UserRole fromValue(String? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'provider' => UserRole.provider,
      _ => UserRole.customer,
    };
  }
}

enum ProviderStatus {
  none,
  pending,
  approved,
  rejected;

  static ProviderStatus fromValue(String? value) {
    return ProviderStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ProviderStatus.none,
    );
  }
}

class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    this.role = UserRole.customer,
    this.providerStatus = ProviderStatus.none,
    this.profilePic = '',
  });

  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final ProviderStatus providerStatus;
  final String profilePic;

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      role: UserRole.fromValue(data['role'] as String?),
      providerStatus: ProviderStatus.fromValue(
        data['providerStatus'] as String?,
      ),
      profilePic: data['profilePic'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'providerStatus': providerStatus.name,
      'profilePic': profilePic,
    };
  }
}
