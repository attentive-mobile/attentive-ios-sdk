# CLAUDE.md

## Project Overview

Attentive iOS SDK — provides identity, event tracking, creatives, push notifications, and inbox for iOS apps. Supports Swift and Objective-C consumers.

## Internal API Documentation

Internal Attentive API documentation and instructions live in the private [`attentive-mobile/claude-plugins`](https://github.com/attentive-mobile/claude-plugins) repo as the `mobile-sdk-internal` plugin. To load this context into Claude Code:

```
/plugin marketplace add attentive-mobile/claude-plugins
/plugin install mobile-sdk-internal@attentive-marketplace
```

If you've previously added the marketplace but don't see `mobile-sdk-internal`, refresh the local cache first:

```
/plugin marketplace update attentive-marketplace
```

This keeps internal details out of the public SDK repo while letting Claude Code pull them in at runtime.

## Build & Test

```bash
# Install dependencies
bundle install
bundle exec pod install --project-directory=Example

# Build framework (device + simulator)
bundle exec fastlane ios build_framework

# Run tests
bundle exec fastlane ios unit_test

# Lint
bundle exec fastlane ios lint

# Validate podspec
bundle exec fastlane ios validate_podspec

# Validate SPM
bundle exec fastlane ios validate_spm

# Build example apps
bundle exec fastlane ios build_examples

# Assemble XCFramework
bundle exec fastlane ios assemble_xcframework
```

## Project Structure

- `Sources/Public/` — Public API (SDK init, events, user identity)
- `Sources/API/` — Internal networking and API layer
- `Sources/Inbox/` — Inbox feature (SwiftUI, iOS 15+)
- `Sources/Models/` — Data models
- `Sources/Helpers/` — Utilities, extensions, protocols
- `Sources/URLProviders/` — URL construction
- `Objc/` — Objective-C bridging headers/constants
- `Tests/TestCases/` — Unit tests (XCTest)
- `Tests/Doubles/` — Mocks and spies
- `Example/` — Example app (CocoaPods integration)
- `Bonni/` — Demo app with push notifications
- `fastlane/` — Build automation lanes

## Key Conventions

- **ATTN prefix** on all public types: `ATTNSDK`, `ATTNItem`, `ATTNPurchaseEvent`, etc.
- **Protocol-driven**: Dependencies use protocols (`ATTNAPIProtocol`, `ATTNWebViewProviding`)
- **Dependency injection** for testability — constructor injection with spy/mock test doubles
- **Swift-first** with `@objc` annotations for Objective-C compatibility
- iOS deployment target: **14.0** (set in `.ios-deployment-target`); Inbox module requires iOS 15+
- Swift version: **5.0+**
- Version source of truth: `.version` file

## Coding Standards

- Use **Swift 5** with `@objc` annotations on all public types for Objective-C compatibility
- Follow Apple's [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- All public classes must be `NSObject` subclasses (for ObjC bridging)
- Use `async/await` for new async code where possible
- Use `ATTNLogger` for all SDK logging — never `print()`
- String constants and keys belong in `ATTNConstants`
- URL construction goes through `URLProvider` types, not inline

### SwiftUI (Inbox module only)

- Inbox targets iOS 15+ — use `@available(iOS 15.0, *)` annotations
- Keep views small; extract subviews when exceeding ~100 lines
- Use `@StateObject` / `@ObservedObject` (not `@Observable` — requires iOS 17)

## Architecture

- **Protocol-driven DI**: Every major dependency has a protocol (`ATTNAPIProtocol`, `ATTNWebViewProviding`, `ATTNCreativeUrlProviding`). Inject via constructor, never reach for singletons in new code.
- **Public API surface** lives in `Sources/Public/`. Internal implementation details stay out of this directory.
- **Event model pattern**: Each event type (`ATTNPurchaseEvent`, `ATTNAddToCartEvent`, etc.) conforms to `ATTNEvent` protocol. Required fields are `let` properties set via `init`; optional fields are `var`.
- **Deeplink support**: Events with deeplinks conform to `ATTNDeeplinkHandling` protocol.

## Testing

- **Framework**: XCTest (not Swift Testing)
- **Test doubles**: Use **spies** (`ATTNAPISpy`) to verify interactions, **mocks** (`NSURLSessionMock`) to stub dependencies. Place in `Tests/Doubles/Spies/` and `Tests/Doubles/Mocks/` respectively.
- **Pattern**: Constructor-inject protocol-typed dependencies, then pass spies/mocks in tests
- **Isolation**: Clean up `UserDefaults` and shared state in `setUp`/`tearDown`
- **New public API** should have corresponding unit tests
- **Access internal types** via `@testable import ATTNSDKFramework`

## Do Not

- **Force unwrap** (`!`) without clear justification — prefer `guard let` / `if let`
- **Use deprecated APIs** — check availability before using UIKit/SwiftUI APIs
- **Add dependencies** without team discussion — the SDK must stay lightweight
- **Expose internal types** in the public API surface
- **Skip `@objc`** on new public types — Objective-C consumers depend on it
- **Hardcode URLs** — use the `URLProvider` pattern
- **Use `print()`** — use `ATTNLogger` instead

## Distribution

Three distribution channels, all validated in CI:
1. **Swift Package Manager** (recommended) — `Package.swift`
2. **CocoaPods** — `ATTNSDKFramework.podspec`
3. **XCFramework** — Binary attached to GitHub releases

## CI/CD

- **CircleCI** (`.circleci/config.yml`) with three workflows:
  - `lint-validate-build-test` — main CI pipeline
  - `release-sdk` — release automation (API-triggered)
  - `deploy-testflight` — TestFlight builds
- **SwiftLint** for code style (`.swiftlint.yml`)

## Release Process

Releases are managed via `bundle exec fastlane ios create_release`. This bumps the version, builds the XCFramework, creates a GitHub release with assets, and pushes to CocoaPods.
