# Fastlane Setup and Usage Guide

This document describes how to use Fastlane for building, testing, and deploying the Attentive iOS SDK.

## Table of Contents

- [Why Fastlane?](#why-fastlane)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Available Lanes](#available-lanes)
- [Local Development](#local-development)
- [CI/CD Integration](#cicd-integration)
- [TestFlight Distribution](#testflight-distribution)
- [Troubleshooting](#troubleshooting)

---

## Why Fastlane?

Fastlane provides a consistent, maintainable automation layer for iOS development:

- **Consistency**: Same commands work locally and in CI
- **Maintainability**: Complex build logic lives in Ruby, not YAML
- **Portability**: Easy to switch CI providers
- **Rich Features**: 200+ built-in actions for iOS automation
- **Better Errors**: Clear error messages and automatic retry logic

---

## Prerequisites

- **macOS** with Xcode 15.3 or later
- **Ruby** 2.7 or later (comes with macOS)
- **Bundler**: `gem install bundler`
- **Xcode Command Line Tools**: `xcode-select --install`

---

## Installation

### 1. Install Dependencies

```bash
# Install Bundler if not already installed
gem install bundler

# Install Fastlane and other dependencies
bundle install
```

This will install Fastlane and all required gems into `vendor/bundle`.

### 2. Verify Installation

```bash
bundle exec fastlane --version
```

You should see the Fastlane version number.

### 3. View Available Lanes

```bash
bundle exec fastlane lanes
```

---

## Available Lanes

### Setup and Dependencies

#### `fastlane ios setup`
Resolves Swift Package Manager dependencies.

```bash
bundle exec fastlane ios setup
```

### Code Quality

#### `fastlane ios lint`
Runs SwiftLint to check code style and quality.

```bash
bundle exec fastlane ios lint
```

**Output:**
- HTML report: `fastlane/reports/swiftlint.html`

### Testing

#### `fastlane ios test`
Runs unit tests with code coverage.

```bash
bundle exec fastlane ios test
```

**Output:**
- Test results: `fastlane/test_output/`
- Coverage JSON: `fastlane/reports/coverage.json`
- Coverage text: `fastlane/reports/coverage.txt`

#### `fastlane ios ui_test`
Runs UI tests for the CreativeUITest scheme.

```bash
bundle exec fastlane ios ui_test
```

**Output:**
- UI test results: `fastlane/test_output/`

#### `fastlane ios snapshot_test`
Runs snapshot tests for visual regression detection.

```bash
bundle exec fastlane ios snapshot_test
```

**Note:** Requires SnapshotTests scheme to be configured.

#### `fastlane ios record_snapshots`
Records new snapshot baseline images.

```bash
bundle exec fastlane ios record_snapshots
```

**Important:** Commit the updated `__Snapshots__` directory after recording.

#### `fastlane ios test_all`
Runs both unit tests and UI tests.

```bash
bundle exec fastlane ios test_all
```

### Building

#### `fastlane ios build_framework`
Builds the framework for both iOS device and simulator.

```bash
bundle exec fastlane ios build_framework
```

#### `fastlane ios build_examples`
Builds all example apps:
- Example - Local
- ExampleSwift - SPM
- Bonni/AttentiveExample

```bash
bundle exec fastlane ios build_examples
```

### Validation

#### `fastlane ios validate_podspec`
Validates the CocoaPods podspec.

```bash
bundle exec fastlane ios validate_podspec
```

#### `fastlane ios validate_spm`
Validates Swift Package Manager configuration.

```bash
bundle exec fastlane ios validate_spm
```

### Distribution

#### `fastlane ios beta`
Builds and uploads the app to TestFlight.

```bash
bundle exec fastlane ios beta
```

**Prerequisites:**
- App Store Connect API key configured
- Fastlane Match set up for code signing
- Environment variables configured (see [TestFlight Distribution](#testflight-distribution))

### Convenience Lanes

#### `fastlane ios quality`
Runs lint, test, and build_framework in sequence.

```bash
bundle exec fastlane ios quality
```

#### `fastlane ios ci`
Runs complete CI validation:
- Setup dependencies
- Lint
- Unit tests
- Build framework
- Validate podspec
- Validate SPM
- Build examples

```bash
bundle exec fastlane ios ci
```

---

## Local Development

### Quick Start

```bash
# 1. Install dependencies
bundle install

# 2. Setup project
bundle exec fastlane ios setup

# 3. Run quality checks before committing
bundle exec fastlane ios quality
```

### Running Individual Commands

```bash
# Lint only
bundle exec fastlane ios lint

# Test only
bundle exec fastlane ios test

# Build only
bundle exec fastlane ios build_framework
```

### Environment Configuration

Create a `.env` file for local configuration (gitignored):

```bash
cp .env.default .env
# Edit .env with your credentials
```

**Example `.env`:**
```bash
APP_IDENTIFIER=com.attentive.sdk.example
MATCH_GIT_URL=git@github.com:your-org/certificates.git
MATCH_PASSWORD=your_match_password
APPLE_ID=your.email@example.com
```

**Important:** Never commit the `.env` file - it contains secrets!

---

## CI/CD Integration

### CircleCI Configuration

The project is configured to use Fastlane for all CI operations. See `.circleci/config.yml`.

All CircleCI jobs call Fastlane lanes:
```yaml
- run:
    name: Run Unit Tests via Fastlane
    command: bundle exec fastlane ios test
```

### Required Environment Variables

Configure these in CircleCI project settings:

#### Code Signing (Fastlane Match)
- `MATCH_GIT_URL` - Git repository for certificates
- `MATCH_PASSWORD` - Certificate encryption password
- `MATCH_GIT_BASIC_AUTHORIZATION` - Git credentials (base64)

#### App Store Connect
- `APP_STORE_CONNECT_API_KEY_ID` - API Key ID
- `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID (UUID)
- `APP_STORE_CONNECT_API_KEY_CONTENT` - API Key content (base64 encoded .p8)

#### App Configuration
- `APP_IDENTIFIER` - App bundle identifier
- `APPLE_ID` - Apple ID email

### Caching

CircleCI caches:
- **Bundler gems**: `vendor/bundle` (keyed by `Gemfile.lock`)
- **Swift PM**: `~/.swiftpm` (keyed by `Package.resolved`)
- **CocoaPods**: `~/Library/Caches/CocoaPods` (keyed by podspec)

---

## TestFlight Distribution

### Prerequisites

1. **App Store Connect API Key**
   - Go to App Store Connect → Users and Access → Keys
   - Create new API key with "App Manager" role
   - Download `.p8` file

2. **Fastlane Match Setup**
   ```bash
   # Initialize Match
   bundle exec fastlane match init

   # Generate certificates
   bundle exec fastlane match appstore
   ```

3. **Environment Variables**

   Encode your API key for CircleCI:
   ```bash
   cat AuthKey_ABC123XYZ.p8 | base64
   ```

   Add to CircleCI:
   - `APP_STORE_CONNECT_API_KEY_CONTENT` = base64 output above
   - `APP_STORE_CONNECT_API_KEY_ID` = ABC123XYZ
   - `APP_STORE_CONNECT_ISSUER_ID` = UUID from App Store Connect

### Deploying to TestFlight

#### From CI (Recommended)

1. Merge code to `main` branch
2. Wait for CI checks to pass
3. Approve the `hold-testflight` job in CircleCI
4. Fastlane will build and upload to TestFlight

#### Manual Deployment

```bash
# Setup API key locally
mkdir -p ~/.appstoreconnect/private_keys
cp AuthKey_ABC123XYZ.p8 ~/.appstoreconnect/private_keys/

# Deploy
bundle exec fastlane ios beta
```

### Build Numbering

- CI builds use CircleCI build number: `CIRCLE_BUILD_NUM`
- Local builds use "1" by default
- Version number managed in Xcode project settings

---

## Troubleshooting

### Bundler Issues

**Error: `Bundler version mismatch`**

```bash
gem install bundler -v $(tail -1 Gemfile.lock | tr -d ' ')
bundle install
```

**Error: `fastlane: command not found`**

Always use `bundle exec`:
```bash
bundle exec fastlane ios test
```

### Fastlane Issues

**Error: `Scheme 'XYZ' not found`**

Make sure schemes are shared in Xcode:
1. Xcode → Product → Scheme → Manage Schemes
2. Check "Shared" for required schemes
3. Commit `.xcodeproj/xcshareddata/xcschemes/` directory

**Error: `Could not find action 'swiftlint'`**

SwiftLint is installed automatically by the lane. If it fails:
```bash
brew install swiftlint
```

### Code Signing Issues

**Error: `No matching provisioning profile found`**

```bash
# Re-sync certificates
bundle exec fastlane match appstore --force_for_new_devices
```

**Error: `Could not decrypt repository`**

Verify `MATCH_PASSWORD` is correct:
```bash
export MATCH_PASSWORD=your_password
bundle exec fastlane match appstore --readonly
```

### Simulator Issues

**Error: `Simulator failed to boot`**

```bash
# Reset simulators
xcrun simctl erase all

# Boot simulator manually
xcrun simctl boot "iPhone 15 Pro"
```

### Test Failures

**Snapshot tests failing unexpectedly**

1. Check artifacts in CircleCI for failure diffs
2. Download `__Snapshots__/__Failures__` to compare
3. If changes are intentional, record new snapshots:
   ```bash
   bundle exec fastlane ios record_snapshots
   git add __Snapshots__
   git commit -m "Update snapshots"
   ```

### Getting Help

**View lane documentation:**
```bash
bundle exec fastlane lanes
```

**View action documentation:**
```bash
bundle exec fastlane action scan
bundle exec fastlane action gym
```

**Verbose output:**
```bash
bundle exec fastlane ios test --verbose
```

---

## Tips and Best Practices

### 1. Always Use Bundle Exec

```bash
# Good
bundle exec fastlane ios test

# Bad (might use wrong version)
fastlane ios test
```

### 2. Run Quality Checks Before Committing

```bash
bundle exec fastlane ios quality
```

### 3. Keep Fastlane Updated

```bash
bundle update fastlane
bundle install
```

### 4. Test Locally Before Pushing

The same commands that run in CI work locally. Test them first!

### 5. Check Fastlane Output

Fastlane provides detailed output. Read it to understand what's happening.

### 6. Use .env for Local Secrets

Never commit credentials to git. Use `.env` files (gitignored).

---

## Additional Resources

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Fastlane Actions Reference](https://docs.fastlane.tools/actions/)
- [CircleCI iOS Documentation](https://circleci.com/docs/testing-ios/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)

---

## Getting Help

For issues or questions:

1. Check this README
2. Check `fastlane lanes` output
3. Check Fastlane documentation
4. Ask in team Slack channel

---

**Last Updated:** 2025-11-18
**Fastlane Version:** 2.217+
