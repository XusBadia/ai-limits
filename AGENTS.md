# Repository guide

## Commands

- Generate Apple project: `xcodegen generate`
- Core tests: `swift test --package-path packages/core`
- Collector tests: `swift test --package-path packages/collectors`
- Sync tests: `swift test --package-path packages/sync`
- Web test: `npm --workspace apps/web test`
- Web lint: `npm --workspace apps/web run lint`

Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` when the active developer directory points at Command Line Tools.

## Invariants

- Never persist or sync provider credentials, cookies, authorization headers, prompts or raw provider responses.
- Every provider parser needs sanitized fixtures and unit tests.
- SwiftUI consumes `AILimitsCore` view data only; it must not parse provider payloads.
- Display snapshot age whenever data may be stale.
- Keep provider failures isolated and retain the last successful snapshot.

