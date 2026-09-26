import 'package:flutter_test/flutter_test.dart';
import 'package:fandom_verse/models/notification_docs.dart';
import 'package:fandom_verse/models/user_profile.dart';

void main() {
  test('NotificationType recognizes content and community variants', () {
    expect(
      NotificationType.fromString('contentPublished').value,
      'contentPublished',
    );
    expect(NotificationType.fromString('fandomContent').value, 'fandomContent');
    expect(
      NotificationType.fromString('communityAnnouncement').value,
      'communityAnnouncement',
    );
    expect(NotificationType.fromString('unknown').value, 'system');
  });

  test('UserProfile exposes notification preferences with safe defaults', () {
    const profile = UserProfile(
      uid: 'u1',
      name: 'Fan',
      email: 'fan@example.com',
      selectedFandoms: ['anime', 'marvel'],
    );

    expect(profile.notificationPreferences['pushEnabled'], isTrue);
    expect(profile.notificationPreferences['contentEnabled'], isTrue);
    expect(profile.notificationPreferences['communityEnabled'], isTrue);
    expect(profile.selectedFandoms, contains('anime'));
  });
}
