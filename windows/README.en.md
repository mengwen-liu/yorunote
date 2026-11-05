# Yorunote Windows x64 preview

[繁體中文](README.md)

This is a Windows desktop candidate of Yorunote, a maintained Venera fork, built in Release mode. It is not an Android APK or a stable release. BUILD_INFO.json identifies the source commit; SHA256SUMS.txt lists the bundled file hashes. Consult the delivery's CI evidence for checks that actually ran.

## Run

1. Extract the entire ZIP on a Windows x64 computer.
2. Keep yorunote.exe, every bundled DLL and the data directory together.
3. Run yorunote.exe. Select Traditional Chinese or English in Settings, and import comic sources as needed.

No installer or Windows code-signing certificate is included. If needed, obtain the Microsoft Visual C++ x64 runtime from Microsoft:
https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist

Embedded web login may also require Microsoft Edge WebView2 Runtime:
https://developer.microsoft.com/en-us/microsoft-edge/webview2/

## Data and existing Venera installations

Settings, reading history, SQLite databases and downloaded comics use the Windows application-data directory. Extract-and-run distribution does not mean all user data stays beside the executable.

The Windows product identity is mengwen-liu / Yorunote, separate from the old Venera identity. This package never runs the legacy installer and does not delete, move or migrate existing Venera data.

## Validation limits

Automated acceptance uses generated synthetic comics only, without private accounts, cookies or copyrighted comic fixtures. A CI launch/read/download/restart result does not establish compatibility with your computer or every real source. Embedded web login, all third-party sources, long sessions, display scaling and Windows ARM64 are not fully covered.

## Attribution and licence

Yorunote: https://github.com/mengwen-liu/yorunote
Upstream Venera: https://github.com/venera-app/venera

The reader and source architecture come from upstream; this fork contributes maintenance, branding and fixes. GPL-3.0 and upstream/third-party notices are retained. See LICENSE and the Flutter notices bundled under data/flutter_assets.
