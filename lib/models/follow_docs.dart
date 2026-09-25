import 'package:cloud_firestore/cloud_firestore.dart';

/// One edge document in the follow graph — used for followers/{uid},
/// following/{uid} and followRequests/{uid} subcollection docs.
class FollowDoc {
  const FollowDoc({
    required this.uid,
    this.displayName = '',
    this.avatarUrl,
    this.bio,
    this.at,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final DateTime? at;

  factory FollowDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final raw = data['at'];
    return FollowDoc(
      uid: (data['uid'] as String?) ?? doc.id,
      displayName: (data['displayName'] as String?) ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String?,
      at: raw is Timestamp ? raw.toDate() : null,
    );
  }
}
