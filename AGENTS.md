# Attentive iOS SDK — Agent Integration Guide

This file is for AI coding agents (Claude Code, Cursor, Copilot, Codex, etc.) integrating the **Attentive iOS SDK** into a host iOS app. It is an alternative to reading the full `README.md` — it tells you exactly what to inspect in the client's codebase and what to write.

If you are an agent and the user has asked you to "set up Attentive", "integrate the Attentive SDK", or similar, follow this guide top-to-bottom. Do not add features beyond the base case unless explicitly asked.

---

## Scope

This guide covers:
1. **Base integration** (always): dependency wiring (SPM or CocoaPods), `ATTNSDK.initialize` in the host `AppDelegate`, and `ATTNEventTracker.setup`.
2. **Push setup** (conditional, after asking the user): see Step 5.

Do **not**, in this pass:
- Add `identify` / `clearUser` / `updateUser` calls (the user will wire those at their own login/logout sites)
- Add event recording (`ATTNPurchaseEvent`, `ATTNAddToCartEvent`, etc.)
- Add Creative rendering (`sdk.trigger(...)`)
- Add marketing subscription (`optInMarketingSubscription` / `optOutMarketingSubscription`) calls

If the user asks for more after the base case is working, refer them to `README.md` in the SDK repo.

---

## Inputs you must collect from the user before writing code

1. **Attentive domain** — a short string identifying their Attentive account (e.g. `myshop`). Ask:

   > "Do you know your Attentive domain? It's the short identifier for your account (e.g. `myshop`)."

   - If the user says **yes**, immediately follow up with: "What is it?" Wait for their answer and use that exact string in the config. Do not proceed until they've given you the domain.
   - If the user says **no** (or doesn't know), insert `"YOUR_ATTENTIVE_DOMAIN"` as a placeholder and tell them to replace it before shipping.

Do not invent a domain. Always initialize the SDK in `.debug` mode for first-time integration; tell the user to switch to `.production` for release builds.

---

## Step 0 — Confirm the host builds clean

Before touching anything, confirm the host produces a clean baseline build. This prevents you from mis-attributing pre-existing host issues to the SDK integration later.

1. Look for a project-specific bootstrap script or setup command in the repo's `README`, `Makefile`, `Justfile`, `bin/`, or `scripts/` directory (e.g. `bin/setup`, `make bootstrap`, `bundle install && pod install`). If one exists, run it.
2. Build the host with its standard command — e.g. `xcodebuild -workspace <…>.xcworkspace -scheme <…> -destination 'generic/platform=iOS Simulator' build`, or whatever the project documents.
3. If the baseline build fails, **stop** and tell the user:

   > "I tried to build the host before integrating Attentive and the build failed with `<error>`. This looks unrelated to the SDK — can you fix the host first (or confirm it's expected and you want me to proceed anyway)? I don't want to attribute pre-existing failures to the integration."

   Do not attempt to debug pre-existing host issues as part of this integration.

Only proceed to Step 1 once you have a clean baseline build (or the user has explicitly told you to continue anyway).

---

## Step 1 — Inspect the client codebase

Before editing anything, determine:

1. **Dependency manager**: detect, then confirm with the user before writing. Look for:
   - **CocoaPods** — `Podfile` at the project root.
   - **Swift Package Manager** — `Package.swift`, or `Package.resolved` under `*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` or `*.xcworkspace/xcshareddata/swiftpm/`.

   Then ask the user a one-line confirmation, with the detected default pre-selected:

   - If only `Podfile` exists: "I see a `Podfile` — I'll add Attentive via CocoaPods. Sound good, or would you rather use Swift Package Manager (or manual XCFramework)?"
   - If only SPM artifacts exist: "I don't see a `Podfile`, so I'll add Attentive via Swift Package Manager. Sound good, or would you rather use CocoaPods (or manual XCFramework)?"
   - If both exist: "This project has both a `Podfile` and SPM packages. Which would you like me to use for Attentive — CocoaPods, SPM, or manual XCFramework?"
   - If neither exists: "I don't see CocoaPods or SPM set up. I'd recommend Swift Package Manager — that okay, or would you rather use CocoaPods or a manual XCFramework drop-in?"

   Wait for the user's answer (or a "yes/sounds good" confirming the default) before moving on. Do not proceed to Step 2 until you know which manager you're using. Manual XCFramework is supported but discouraged unless explicitly requested — see Step 2b.
2. **Workspace vs project**: If a `.xcworkspace` exists alongside a `.xcodeproj`, the user opens the workspace. CocoaPods always produces a workspace; SPM projects may use either.
3. **App entry point language**: Swift or Objective-C? Look for `AppDelegate.swift` vs `AppDelegate.m` / `AppDelegate.h`. Match the host's language for any code you add.
4. **App lifecycle style**:
   - **UIKit AppDelegate** (most common): `@UIApplicationMain` / `@main` on `AppDelegate`, with `application(_:didFinishLaunchingWithOptions:)`.
   - **UIKit + SceneDelegate**: `AppDelegate` plus a `SceneDelegate.swift`. SDK init still goes in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` — push and lifecycle hooks for Attentive are still on the `AppDelegate`, not the scene delegate.
   - **SwiftUI `App`** (`@main struct MyApp: App`): the project may not have an `AppDelegate`. In that case, you'll need to add one via `@UIApplicationDelegateAdaptor` — see Step 3.
5. **Deployment target**: Note the value from the app target's `IPHONEOS_DEPLOYMENT_TARGET`. The SDK requires **iOS 14.0+**. The `Inbox` module additionally requires iOS 15.0+ (you are not wiring Inbox in this pass, so 14.0 is sufficient). If the host's deployment target is below 14.0, **stop and ask the user** before raising it — bumping the deployment target is their decision.
6. **Existing `UNUserNotificationCenterDelegate`**: search for `UNUserNotificationCenterDelegate` in the project. If one exists already, you'll add Attentive's hooks to its callbacks rather than installing a new delegate.

---

## Step 2 — Add the dependency

### 2a. Look up the latest SDK version

Do **not** hardcode a version from this guide — fetch the latest release from GitHub at integration time so the user gets the current SDK. Run one of the following and capture the `tag_name`, stripping the leading `v`:

```bash
curl -fsSL https://api.github.com/repos/attentive-mobile/attentive-ios-sdk/releases/latest \
  | grep -m1 '"tag_name"' \
  | sed -E 's/.*"v?([^"]+)".*/\1/'
```

If `jq` is available: `curl -fsSL …/releases/latest | jq -r .tag_name | sed 's/^v//'`. If you have a web-fetch tool instead of shell access, fetch `https://github.com/attentive-mobile/attentive-ios-sdk/releases/latest` (it redirects to `/releases/tag/<version>`) and read the version out of the URL or page title.

If the lookup fails (no network, rate-limited, etc.), tell the user and ask them for the version they want to use — do not guess.

Use the resolved version (e.g. `2.0.15`) in place of `<VERSION>` below.

> **Note on version drift:** the version Xcode's resolver actually pins can differ from what you looked up (a stale package cache or an existing `Package.resolved` will hold an older version, even with a `from:` constraint). After installing — Step 2c — you must read back the *resolved* version and report **that** to the user, not the latest-tag lookup result. Step 2c spells out where to read it.

### 2b. Add the dependency

#### Swift Package Manager (recommended)

For most iOS app hosts, SPM is managed through Xcode's GUI — package references live inside `project.pbxproj`, not in an editable app-level `Package.swift` — so the package add is a **user-driven step you cannot perform yourself**. Treat this as the primary path; the `Package.swift` variant below is only for the smaller case where the host *is* an SPM package.

The package coordinates:

- **URL:** `https://github.com/attentive-mobile/attentive-ios-sdk`
- **Version rule:** `Up to Next Major Version` from `<VERSION>` (semver-compatible — recommended), or `Exact` `<VERSION>` if the host prefers strict pinning.
- **Product to link:** `ATTNSDKFramework`

##### Primary path — Xcode GUI handoff

Tell the user:

> "Open the project in Xcode → File → Add Package Dependencies… → paste `https://github.com/attentive-mobile/attentive-ios-sdk` → choose `Up to Next Major Version` from `<VERSION>` → add `ATTNSDKFramework` to your app target. Let me know once it resolves and I'll wire up the init."

Wait for the user to confirm the package resolved before continuing. You cannot add an SPM package by editing files for an Xcode-managed app target.

##### Variant — host *is* an SPM package

Only use this path if you found a top-level `Package.swift` in the repo (i.e. the host is itself a Swift package, not an Xcode app project). Add to its dependencies:

```swift
.package(url: "https://github.com/attentive-mobile/attentive-ios-sdk", from: "<VERSION>")
```

…and to the relevant target's `dependencies`:

```swift
.product(name: "ATTNSDKFramework", package: "attentive-ios-sdk")
```

#### CocoaPods

Edit the **app target's** `Podfile` and add:

```ruby
pod 'ATTNSDKFramework', '<VERSION>'
```

Then run (from the directory containing the `Podfile`):

```bash
bundle exec pod install   # if the project uses Bundler (presence of Gemfile)
# or
pod install
```

After install, the user must open the `.xcworkspace` (not the `.xcodeproj`).

> **Note:** Use `ATTNSDKFramework` — that is the supported pod name. The older `attentive-ios-sdk` pod is **deprecated** and CocoaPods will warn the user if they use it; it points at the same source but exists only for legacy consumers who haven't migrated yet. Do not add it for new integrations.

#### XCFramework (manual)

Only fall back to manual XCFramework integration if the user explicitly requests it or both SPM and CocoaPods are unavailable. The README has the full instructions; warn the user that incorrect embedding can cause App Store submission failures.

### 2c. Verify the dependency resolves, and read back the resolved version

Before writing any code that imports `ATTNSDKFramework`, make sure the project builds:

- **SPM**: ask the user to let Xcode finish "Resolving Package Graph", or run a build (`xcodebuild -workspace … -scheme … build` or just have them hit ⌘B). If SPM resolution fails, surface the error and stop.
- **CocoaPods**: confirm `pod install` reported success and the workspace builds.

Do not move on to Step 3 until the dependency resolves; otherwise the `import ATTNSDKFramework` you add next will fail.

**Then read back the version that was actually pinned** (it can differ from the latest-tag lookup in Step 2a — a stale Xcode package cache or an existing `Package.resolved` will hold an older version even with a `from:` constraint):

- **SPM**: read `<…>.xcodeproj/project.workspaceData/xcshareddata/swiftpm/Package.resolved` or `<…>.xcworkspace/xcshareddata/swiftpm/Package.resolved` and find the entry for `attentive-ios-sdk` — the `state.version` field is the truth.

  ```bash
  jq -r '.pins[] | select(.identity == "attentive-ios-sdk") | .state.version' \
    "$(find . -name Package.resolved -path '*/swiftpm/*' | head -n1)"
  ```

- **CocoaPods**: read `Podfile.lock` for the `ATTNSDKFramework` entry under `PODS:`:

  ```bash
  grep -E '^\s*-?\s*ATTNSDKFramework' Podfile.lock | head -n1
  ```

Report the **resolved** version to the user (e.g. "Attentive SDK 2.0.14 is now installed."), not the latest-tag value. If it differs from what you looked up, tell them explicitly so they aren't surprised that the runtime log shows a different version than what they asked for.

---

## Step 3 — Initialize the SDK in `AppDelegate`

The SDK must be initialized as early as possible after process start so app-open events and push registration work correctly. Initialization always happens in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, regardless of whether the app uses UIKit + SceneDelegate or SwiftUI's `App` lifecycle.

### If the host has no `AppDelegate` (pure SwiftUI `App`)

**Stop.** Adding an `AppDelegate` has app-wide implications (it changes the lifecycle entry point and affects push, deep linking, and background handling). Tell the user:

> "The Attentive SDK initializes inside `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, but this app uses SwiftUI's `App` lifecycle without an `AppDelegate`. Adding one means introducing a `UIApplicationDelegateAdaptor` and a delegate class. Do you want me to add one, or would you rather add it yourself first?"

Wait for the user to confirm before creating the delegate.

If they confirm, create a minimal `AppDelegate.swift`:

```swift
import UIKit
import ATTNSDKFramework

class AppDelegate: NSObject, UIApplicationDelegate {
    var attentiveSdk: ATTNSDK?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ATTNSDK.initialize(domain: "YOUR_ATTENTIVE_DOMAIN", mode: .debug) { result in
            switch result {
            case .success(let sdk):
                self.attentiveSdk = sdk
                ATTNEventTracker.setup(with: sdk)
            case .failure(let error):
                // TODO(attentive): route to the host's logger if one exists.
                print("Attentive SDK failed to initialize: \(error)")
            }
        }
        return true
    }
}
```

…and wire it into the SwiftUI `App`:

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### If the host already has an `AppDelegate`

Add the import and the init block to the existing `AppDelegate`. Match the file's language (Swift or Objective-C). Place the init **after** `super`-equivalent setup if any, and **before** anything that depends on Attentive.

**Swift:**

```swift
import ATTNSDKFramework

// inside AppDelegate
var attentiveSdk: ATTNSDK?

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    ATTNSDK.initialize(domain: "YOUR_ATTENTIVE_DOMAIN", mode: .debug) { result in
        switch result {
        case .success(let sdk):
            self.attentiveSdk = sdk
            ATTNEventTracker.setup(with: sdk)
        case .failure(let error):
            // TODO(attentive): route to the host's logger if one exists.
            print("Attentive SDK failed to initialize: \(error)")
        }
    }
    return true
}
```

**Objective-C:**

```objective-c
#import "ATTNSDKFramework-Swift.h"

// inside AppDelegate.h
@property (nonatomic, strong, nullable) ATTNSDK *attentiveSdk;

// inside AppDelegate.m didFinishLaunchingWithOptions:
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"YOUR_ATTENTIVE_DOMAIN" mode:@"debug"];
self.attentiveSdk = sdk;
[ATTNEventTracker setupWithSdk:sdk];
```

(For Objective-C consumers, the synchronous `initWithDomain:mode:` form is the standard pattern — the async `initialize:completion:` is Swift-only.)

If the existing `AppDelegate` already stores other SDK instances on properties, follow the same pattern — use a property, not a local variable, so the SDK survives past `didFinishLaunchingWithOptions`.

---

## Step 4 — Verify the base build

1. Build the app (⌘B, or `xcodebuild -workspace <…>.xcworkspace -scheme <…> -destination 'generic/platform=iOS Simulator' build`).
2. If the build fails, fix it before moving on. Common issues:
   - **`No such module 'ATTNSDKFramework'`** — SPM/CocoaPods didn't resolve. Re-run `pod install` or have Xcode resolve packages.
   - **CocoaPods + Xcode opens the wrong file** — make sure you're working in `<…>.xcworkspace`, not `<…>.xcodeproj`.
3. Once the build succeeds, proceed to Step 4.5.

---

## Step 4.5 — Confirm the SDK initializes at runtime

A green build does **not** mean the SDK came up. The failure branch only `print()`s, so a misconfiguration (bad domain, missing entitlement on later steps, etc.) is silent unless someone reads the console. Verify the init actually fires before handing off.

1. Boot a simulator and install the app — either via Xcode (⌘R, then immediately stop the app) or with `xcodebuild` + `xcrun simctl install`.
2. In another shell, start streaming the system log:

   ```bash
   xcrun simctl spawn booted log stream --level debug --predicate 'eventMessage CONTAINS "ATTNSDK"'
   ```

3. Launch the app. Within a few seconds you should see two lines:

   ```
   Initializing ATTNSDK v<version>, Mode: debug, Domain: <…>, PushEnabled: <…>
   ATTNSDK initialization successful - Visitor ID: <…>
   ```

4. If you instead see `Attentive SDK failed to initialize: <error>`, surface the error to the user and stop. Do not proceed.
5. Once you've confirmed `ATTNSDK initialization successful`, terminate the app and stop the log stream. Then proceed to Step 5.

This is the cheapest runtime check you can run without asking the user — do it before declaring the integration done.

> **Carve-out from the "do not run" rule below:** Step 4.5 (and the equivalent runtime check at the end of Step 6) is the one place you *may* briefly launch the app yourself — to confirm SDK init, then terminate. Don't run it for demo, interactive testing, or any reason beyond reading the init log.

---

## Step 5 — Ask about push

Push notifications are **enabled by default** in the SDK. Before doing anything else, ask the user a single question:

> "Do you plan to send push notifications to your users via Attentive? (yes/no)"

### If the user answers **no**

Pass `pushEnabled: false` so the SDK skips push registration and app-launch / direct-open events. Update the init call:

**Swift:**

```swift
ATTNSDK.initialize(domain: "YOUR_ATTENTIVE_DOMAIN", mode: .debug, pushEnabled: false) { result in
    // …same handling as before
}
```

**Objective-C:**

```objective-c
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"YOUR_ATTENTIVE_DOMAIN" mode:@"debug" pushEnabled:NO];
```

Stop here. Do not modify entitlements, do not add a notification service extension, do not call `registerForPushNotifications`. The base integration is complete — skip to Step 6.

### If the user answers **yes**

Walk through the following sub-steps in order. Ask before each step that requires user input.

#### 5a. APNs entitlement — detect, do not auto-add

Check whether the app target has the **Push Notifications** capability:

- Look for an `.entitlements` file in the app target (typically `<AppName>/<AppName>.entitlements` or referenced by `CODE_SIGN_ENTITLEMENTS` in the `.pbxproj`).
- The file should contain an `aps-environment` key (`development` for debug, `production` for release).

If the entitlement is **missing**, tell the user:

> "Push notifications need the **Push Notifications** capability enabled on the app target. Open the project in Xcode → select the app target → Signing & Capabilities → `+ Capability` → Push Notifications. This also requires that your bundle identifier is registered for push in Apple's Developer portal. Let me know once it's added and I'll continue."

Do not edit the entitlements file or `.pbxproj` yourself. Wait for the user to confirm.

#### 5b. `UNUserNotificationCenterDelegate` — detect and wire push hooks

Search the project for `UNUserNotificationCenterDelegate`:

- Grep `.swift` and `.m` files for `UNUserNotificationCenterDelegate`.
- Check whether `UNUserNotificationCenter.current().delegate = self` (or similar) is set anywhere — typically in `AppDelegate.didFinishLaunchingWithOptions`.

**If a delegate is already set up**, add the Attentive forwarding to the existing `userNotificationCenter(_:didReceive:withCompletionHandler:)`. Do not replace the existing handler — add to it.

**If no delegate exists**, install one on `AppDelegate` (the simplest place). Match the host's language.

Add the following four pieces (in addition to the init from Step 3):

##### 1. Set the delegate and request permission

In `application(_:didFinishLaunchingWithOptions:)`, set the delegate immediately. The push permission prompt **must** be requested from inside the `ATTNSDK.initialize` `.success` branch, because the async initializer assigns `self.attentiveSdk` from the completion handler — calling `attentiveSdk?.registerForPushNotifications(...)` outside that branch hits a still-`nil` reference and silently no-ops.

Update the init you wrote in Step 3 to also request push registration on success:

```swift
UNUserNotificationCenter.current().delegate = self

ATTNSDK.initialize(domain: "YOUR_ATTENTIVE_DOMAIN", mode: .debug) { result in
    switch result {
    case .success(let sdk):
        self.attentiveSdk = sdk
        ATTNEventTracker.setup(with: sdk)
        sdk.registerForPushNotifications { granted, error in
            if let error = error {
                // Permission flow errored — usually safe to log and continue.
            }
            // `granted` reflects whether the user accepted the prompt.
        }
    case .failure(let error):
        // TODO(attentive): route to the host's logger if one exists.
        print("Attentive SDK failed to initialize: \(error)")
    }
}
```

For Objective-C hosts using the synchronous `initWithDomain:mode:`, the registration call can stay outside the init because the SDK is assigned synchronously:

```objective-c
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"YOUR_ATTENTIVE_DOMAIN" mode:@"debug"];
self.attentiveSdk = sdk;
[ATTNEventTracker setupWithSdk:sdk];
[UNUserNotificationCenter currentNotificationCenter].delegate = self;
[sdk registerForPushNotifications];
```

`registerForPushNotifications` shows the system permission prompt (if not yet shown) and, on grant, calls APNs to begin remote-notification registration. Do not also call `UIApplication.shared.registerForRemoteNotifications()` — the SDK handles that.

##### 2. Handle APNs token registration

Add or extend the two AppDelegate callbacks:

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
        guard let self = self else { return }
        let authStatus = settings.authorizationStatus
        self.attentiveSdk?.registerDeviceToken(deviceToken, authorizationStatus: authStatus) { _, _, _, _ in
            DispatchQueue.main.async {
                self.attentiveSdk?.handleRegularOpen(authorizationStatus: authStatus)
            }
        }
    }
}

func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    attentiveSdk?.failedToRegisterForPush(error)
}
```

If these callbacks already exist (e.g. for another push provider), **do not delete the existing logic** — append the Attentive calls. Two providers can coexist; both want the device token.

##### 3. Handle incoming push taps

Add the `UNUserNotificationCenterDelegate` extension if missing, and route notification taps to the SDK:

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authStatus = settings.authorizationStatus
            DispatchQueue.main.async {
                switch UIApplication.shared.applicationState {
                case .active:
                    self?.attentiveSdk?.handleForegroundPush(response: response, authorizationStatus: authStatus)
                case .background, .inactive:
                    self?.attentiveSdk?.handlePushOpen(response: response, authorizationStatus: authStatus)
                @unknown default:
                    self?.attentiveSdk?.handlePushOpen(response: response, authorizationStatus: authStatus)
                }
            }
        }
        completionHandler()
    }
}
```

If the host already implements `userNotificationCenter(_:didReceive:withCompletionHandler:)`, **add** the `attentiveSdk?.handleForegroundPush` / `handlePushOpen` calls inside the existing handler, gated on whether the payload is from Attentive (look for `attentiveCallbackData` in `response.notification.request.content.userInfo` if the host needs to disambiguate). The SDK is safe to call on any payload — it no-ops on non-Attentive notifications — but if the host's existing logic eats the response, surface that to the user.

For target deployment iOS 13 and earlier, replace `.banner` with `.alert` in `willPresent`.

#### 5c. Notification Service Extension (optional — image attachments)

Push notifications from Attentive can include an image (`attentive_image_url` in the payload). Without a Notification Service Extension, iOS will not download and display the image. Ask:

> "Do you want to support rich push notifications with images? This requires adding a Notification Service Extension to the project (a small extra target). Yes/no?"

**If yes**, tell the user:

> "Add a Notification Service Extension target via Xcode → File → New → Target → Notification Service Extension. Name it whatever you like (the SDK doesn't care). Once it's added, let me know and I'll fill in the `NotificationService.swift` file."

Wait for the user to add the target (you cannot add Xcode targets via file edits alone). Once they confirm, replace the generated `NotificationService.swift` with the image-download implementation. Reference `Bonni/ATTNNotificationService/NotificationService.swift` in the SDK repo for the canonical implementation — it downloads the image at `attentiveCallbackData.attentive_image_url`, attaches it, and falls through to the original content on failure.

**If no**, skip — text-only push notifications still work without an extension.

#### 5d. Deep linking — describe options, do not auto-wire

Attentive push payloads can include a deep link (`attentive_open_action_url`). The SDK does **not** open URLs itself — it broadcasts them. Ask:

> "Do you want me to wire up handling for deep links inside Attentive push notifications? You have two options: observe the `.ATTNSDKDeepLinkReceived` notification, or call `attentiveSdk.consumeDeepLink()` when your app is ready to navigate. The first is reactive (handle when received); the second is pull-based (consume on a known navigation entry point). Which fits your app better?"

**If they pick observe**, add to `AppDelegate.didFinishLaunchingWithOptions` (after SDK init):

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleAttentiveDeepLink(_:)),
    name: .ATTNSDKDeepLinkReceived,
    object: nil
)
```

…and add the handler:

```swift
@objc private func handleAttentiveDeepLink(_ notification: Notification) {
    guard let url = notification.userInfo?["attentivePushDeeplinkUrl"] as? URL else { return }
    // TODO(attentive): route this URL into the host's existing deep-link handler.
}
```

Leave a TODO at the routing site — you do not know the host's navigation system, and wiring deep-link routing is a host-specific decision.

**If they pick consume**, add a one-liner at whichever entry point the host nominates (e.g. inside their root view's `onAppear`, or in the home screen's `viewDidAppear`):

```swift
if let url = attentiveSdk?.consumeDeepLink() {
    // TODO(attentive): route this URL into the host's existing deep-link handler.
}
```

**If they say "no" or "skip"**, leave deep linking unhandled. Tell them: "Push notification taps will still register with Attentive for analytics — you just won't navigate the user to the destination URL. Pick this up later via either of the two options when you're ready."

---

## Step 6 — Re-verify and hand off

1. Build the app (⌘B). Resolve any errors before declaring done.
2. Tell the user:
   - Replace `"YOUR_ATTENTIVE_DOMAIN"` with their real domain if a placeholder was used.
   - Switch `.debug` to `.production` for release builds (or wire it to a build configuration check).
   - If push was enabled, the **Push Notifications** capability and a registered APNs key in Apple Developer are still required to actually receive pushes — these are platform prerequisites the SDK does not manage.

3. Then **emit the following block to the user, verbatim**, including every `[text](url)` link exactly as written. Do not rewrite, summarize, paraphrase, drop URLs, or convert links to plain titles. The user's terminal renders Markdown; without the `(url)` part, the links are dead.

   ```
   For everything this guide intentionally skipped, see the [SDK README](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md):

   - [Identify the current user](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#step-2---identify-the-current-user) — call at login or whenever you learn the user's email, phone, `clientUserId`, Shopify ID, Klaviyo ID, or custom identifiers.
   - [Clearing user data](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#clearing-user-data) — call on logout. Resets identifiers and detaches the push token.
   - [Managing user identity](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#managing-user-identity) — `updateUser` / `identify` merge semantics post-login.
   - [Recording events](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#step-3---record-user-events) — `ATTNPurchaseEvent`, `ATTNAddToCartEvent`, `ATTNProductViewEvent`, `ATTNCustomEvent`, plus `ATTNItem` / `ATTNPrice` / `ATTNOrder` / `ATTNCart` metadata models.
   - [Showing Creatives](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#step-6-optional---show-creatives) — in-app messages rendered in a WebView; trigger / handler / dismiss lifecycle.
   - [Push payload reference](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#sample-push-payload-with-deep-link-and-image-support) — the shape of an Attentive APNs payload.
   - [Deep link support](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#deep-link-support) — observing `.ATTNSDKDeepLinkReceived` vs. `consumeDeepLink()`.
   - [Marketing subscriptions](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#manage-subscriptions-for-email-and-phone-numbers) — email / SMS opt-in and opt-out helpers.
   - [Switching domain at runtime](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#switch-to-another-domain) — for apps that switch Attentive accounts.
   - [Skip fatigue on creatives](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md#skip-fatigue-on-creative) — debug helper to bypass creative fatigue rules.
   ```

4. Re-run the Step 4.5 runtime check after wiring push (or after any push-flow change). The same `xcrun simctl spawn booted log stream` invocation will surface push-related init logs in addition to the standard init line.

Do not run the app on a simulator or device beyond the brief launch-and-terminate needed for the Step 4.5 init check (and the equivalent re-check here). No demo runs, no interactive testing — read the log, confirm init, stop.

---

## Things NOT to do

- Do not add `identify(_:)`, `clearUser()`, `updateUser(...)`, `record(event:)`, or `trigger(_:)` calls.
- Do not add the **Push Notifications** capability or edit the `.entitlements` file yourself — only detect and instruct.
- Do not add a Notification Service Extension target via file edits — Xcode targets must be added through Xcode's UI.
- Do not call `UIApplication.shared.registerForRemoteNotifications()` — `attentiveSdk.registerForPushNotifications` already does that on permission grant.
- Do not raise the host's `IPHONEOS_DEPLOYMENT_TARGET`, Swift version, or Xcode version.
- Do not introduce DI frameworks (Swinject, Resolver, etc.) to wire this — direct construction in `AppDelegate` is correct here.
- Do not delete or replace existing push handlers; **append** Attentive's calls alongside the host's existing logic.
- Do not write tests for the integration unless asked.

---

## Reference

Full documentation: https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/README.md
Sample app: `Bonni/` in the SDK repo (push-enabled), `Example/` for the CocoaPods integration sample.

### What this guide intentionally skipped

The base-integration guide does not wire up identify/clearUser, event recording, Creatives, marketing subscriptions, runtime domain changes, or deep-link routing into the host's navigation system. Step 6 already emits the linked README pointers for these to the user — see that step for the canonical block.
