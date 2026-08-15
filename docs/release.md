# Release checklist

## Automated gates

- `npm test` passes all Swift package and rendered-web tests.
- `npm run lint:web` passes.
- `npm audit --audit-level=moderate` reports zero vulnerabilities.
- `xcodebuild` compiles the iOS app, WidgetKit extension and macOS collector.
- XCUITest validates dashboard navigation and the disconnected empty state.

## TestFlight prerequisites

- Register `me.badia.ailimits`, `me.badia.ailimits.collector` and `me.badia.ailimits.widgets` in the Apple Developer account.
- Register app group `group.me.badia.ailimits` and iCloud container `iCloud.me.badia.ailimits`.
- Enable CloudKit in the production container and deploy its schema.
- Create the iOS app record in App Store Connect.
- Install an Apple Distribution certificate and App Store provisioning profiles, or sign in to Xcode with an account permitted to create them.
- Complete App Privacy answers: no tracking; no analytics; usage snapshots remain in the user's private iCloud database.

## Manual checks

- Run the collector while Codex and Claude are signed in.
- Confirm refresh, last-good snapshot behavior and credential redaction.
- Confirm iPhone-to-Mac iCloud sync on the same Apple Account.
- Add, resize and refresh the small and medium widgets.
- Test Light Mode, Dark Mode, Dynamic Type and VoiceOver.
