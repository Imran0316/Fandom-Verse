import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'catalog_docs.dart';

class CommunityDoc {
  const CommunityDoc({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.description = '',
    this.iconName = 'grid',
    this.colorName = 'rose',
    this.memberCount = 1,
    this.postCount = 0,
    this.profileImageUrl,
    this.coverImageUrl,
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerUid;
  final String description;
  final String iconName;
  final String colorName;
  final int memberCount;
  final int postCount;
  final String? profileImageUrl;
  final String? coverImageUrl;
  final DateTime? createdAt;

  IconData get icon => CatalogIcons.fromName(iconName);
  Color get color => CatalogIcons.colorFromName(colorName);

  factory CommunityDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    return CommunityDoc(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      ownerUid: (data['ownerUid'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      iconName: (data['iconName'] as String?) ?? 'grid',
      colorName: (data['colorName'] as String?) ?? 'rose',
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 1,
      postCount: (data['postCount'] as num?)?.toInt() ?? 0,
      profileImageUrl: data['profileImageUrl'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerUid': ownerUid,
        'description': description,
        'iconName': iconName,
        'colorName': colorName,
        'memberCount': memberCount,
        'postCount': postCount,
        'profileImageUrl': profileImageUrl,
        'coverImageUrl': coverImageUrl,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}

enum CommunityRole {
  owner,
  moderator,
  member;

  static CommunityRole fromString(String? raw) {
    switch (raw) {
      case 'owner':
        return CommunityRole.owner;
      case 'moderator':
        return CommunityRole.moderator;
      default:
        return CommunityRole.member;
    }
  }

  String get value => name;
}

class CommunityMemberDoc {
  const CommunityMemberDoc({
    required this.uid,
    required this.role,
    this.displayName = '',
    this.avatarUrl,
    this.joinedAt,
  });

  final String uid;
  final CommunityRole role;
  final String displayName;
  final String? avatarUrl;
  final DateTime? joinedAt;

  factory CommunityMemberDoc.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    final joined = data['joinedAt'];
    return CommunityMemberDoc(
      uid: doc.id,
      role: CommunityRole.fromString(data['role'] as String?),
      displayName: (data['displayName'] as String?) ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      joinedAt: joined is Timestamp ? joined.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role.value,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'joinedAt': joinedAt != null
            ? Timestamp.fromDate(joinedAt!)
            : FieldValue.serverTimestamp(),
      };
}
