import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  fan,
  seller,
  admin;

  static UserRole fromString(String? raw) {
    switch (raw) {
      case 'seller':
        return UserRole.seller;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.fan;
    }
  }

  String get value => name;
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.role = UserRole.fan,
    this.avatarUrl,
    this.bio,
    this.shopName,
    this.selectedFandoms = const [],
    this.notificationPreferences = const {
      'pushEnabled': true,
      'contentEnabled': true,
      'fandomEnabled': true,
      'communityEnabled': true,
      'announcementEnabled': true,
    },
    this.followerCount = 0,
    this.followingCount = 0,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final String? bio;

  /// Set when the user has upgraded to a seller (Fiverr-style self-serve).
  final String? shopName;
  final List<String> selectedFandoms;
  final Map<String, bool> notificationPreferences;
  final int followerCount;
  final int followingCount;
  final DateTime? createdAt;

  bool get isFan => role == UserRole.fan;
  bool get isSeller => role == UserRole.seller || role == UserRole.admin;
  bool get isAdmin => role == UserRole.admin;

  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.seller:
        return 'Seller';
      case UserRole.fan:
        return 'Fan';
    }
  }

  UserProfile copyWith({
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    String? bio,
    String? shopName,
    List<String>? selectedFandoms,
    Map<String, bool>? notificationPreferences,
    int? followerCount,
    int? followingCount,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      shopName: shopName ?? this.shopName,
      selectedFandoms: selectedFandoms ?? this.selectedFandoms,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.value,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'shopName': shopName,
      'selectedFandoms': selectedFandoms,
      'notificationPreferences': notificationPreferences,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    final prefs = (data['notificationPreferences'] as Map?) ?? const {};
    return UserProfile(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      role: UserRole.fromString(data['role'] as String?),
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String?,
      shopName: data['shopName'] as String?,
      selectedFandoms: List<String>.from(
        (data['selectedFandoms'] as List?) ?? const [],
      ),
      notificationPreferences: {
        'pushEnabled': (prefs['pushEnabled'] as bool?) ?? true,
        'contentEnabled': (prefs['contentEnabled'] as bool?) ?? true,
        'fandomEnabled': (prefs['fandomEnabled'] as bool?) ?? true,
        'communityEnabled': (prefs['communityEnabled'] as bool?) ?? true,
        'announcementEnabled': (prefs['announcementEnabled'] as bool?) ?? true,
      },
      followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
