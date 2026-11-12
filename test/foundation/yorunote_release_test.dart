import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/yorunote_release.dart';

Map<String, Object> _release(
  String tag,
  String filename, {
  bool draft = false,
  bool prerelease = false,
}) => {
  'draft': draft,
  'prerelease': prerelease,
  'tag_name': tag,
  'assets': [
    {'name': filename},
  ],
};

bool _hasUpdate(Object? releases, {required bool android}) =>
    hasNewerYorunoteRelease(
      releases,
      installedVersion: '0.1.0',
      android: android,
    );

void main() {
  test('Android accepts platform-specific and unified stable tags', () {
    const apk = 'Yorunote-0.1.1-android-arm64.apk';
    for (final tag in ['v0.1.1-android', 'v0.1.1']) {
      expect(_hasUpdate([_release(tag, apk)], android: true), isTrue);
    }
  });

  test('Android ignores preview, draft, older and other-platform assets', () {
    const apk = 'Yorunote-0.1.1-android-arm64.apk';
    final releases = [
      _release('v0.1.1-android', apk, draft: true),
      _release('v0.1.1-android', apk, prerelease: true),
      _release('v0.1.1-android', '$apk.sha256'),
      _release('v0.1.1-android', 'Yorunote-0.1.1-android-arm64-candidate.apk'),
      _release('v0.1.1', 'Yorunote-0.1.1-windows-x64.zip'),
      _release('v0.1.0-android', 'Yorunote-0.1.0-android-arm64.apk'),
      _release('v0.0.9-android', 'Yorunote-0.0.9-android-arm64.apk'),
    ];
    expect(_hasUpdate(releases, android: true), isFalse);
    expect(_hasUpdate({'message': 'invalid'}, android: true), isFalse);
  });

  test('Windows continues to accept only a matching stable Windows ZIP', () {
    const zip = 'Yorunote-0.1.1-windows-x64.zip';
    expect(_hasUpdate([_release('v0.1.1', zip)], android: false), isTrue);
    expect(
      _hasUpdate([_release('v0.1.1-android', zip)], android: false),
      isFalse,
    );
  });
}
