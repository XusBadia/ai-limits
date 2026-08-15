# AI Limits

AI Limits puts Codex, Claude and other AI subscription limits in one private dashboard on iPhone, Mac and the web.

The Mac collector reads the sessions already present on the computer. It converts provider-specific responses into a small, versioned snapshot. Only normalized usage metrics are shared with the iPhone; credentials, cookies, prompts and raw logs stay on the Mac.

## Monorepo

- `apps/apple` — native SwiftUI apps for iOS, macOS and WidgetKit.
- `apps/web` — public product website.
- `packages/core` — cross-platform snapshot domain model.
- `packages/collectors` — macOS provider collectors.
- `packages/sync` — atomic cache and CloudKit transport abstractions.
- `plans` — architecture and release plans.

## Development

Requirements: Xcode 26, Swift 6, XcodeGen, Node 22+.

```sh
npm install
npm run generate:apple
npm test
```

The Xcode project is generated from `project.yml` and is intentionally not committed.

## Privacy

Provider credentials never enter the shared snapshot. See `docs/privacy-and-security.md` for the data contract and threat model.

