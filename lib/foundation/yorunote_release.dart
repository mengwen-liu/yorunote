final _windowsTag = RegExp(r'^v(\d+\.\d+\.\d+)$');
final _androidTag = RegExp(r'^v(\d+\.\d+\.\d+)(?:-android)?$');
final _versionPattern = RegExp(r'^\d+\.\d+\.\d+$');

/// Checks published Yorunote releases for an asset built for this platform.
bool hasNewerYorunoteRelease(
  Object? releases, {
  required String installedVersion,
  required bool android,
}) {
  if (releases is! List || !_versionPattern.hasMatch(installedVersion)) {
    return false;
  }
  final tagPattern = android ? _androidTag : _windowsTag;
  final suffix = android ? 'android-arm64.apk' : 'windows-x64.zip';
  for (final release in releases) {
    if (release is! Map ||
        release['draft'] != false ||
        release['prerelease'] != false) {
      continue;
    }
    final tag = release['tag_name'];
    final assets = release['assets'];
    if (tag is! String || assets is! List) {
      continue;
    }
    final version = tagPattern.firstMatch(tag)?.group(1);
    if (version == null || !_isNewer(version, installedVersion)) {
      continue;
    }
    final filename = 'Yorunote-$version-$suffix';
    if (assets.any((asset) => asset is Map && asset['name'] == filename)) {
      return true;
    }
  }
  return false;
}

bool _isNewer(String candidate, String installed) {
  final next = candidate.split('.');
  final current = installed.split('.');
  for (var i = 0; i < 3; i++) {
    final a = int.tryParse(next[i]);
    final b = int.tryParse(current[i]);
    if (a == null || b == null) return false;
    if (a != b) return a > b;
  }
  return false;
}
