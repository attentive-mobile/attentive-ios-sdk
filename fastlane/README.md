fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios setup

```sh
[bundle exec] fastlane ios setup
```

Setup dependencies and environment

### ios sync_version

```sh
[bundle exec] fastlane ios sync_version
```

Sync version across all files. Usage: fastlane sync_version version:2.0.11

### ios get_version

```sh
[bundle exec] fastlane ios get_version
```

Get current version from .version file

### ios bump_version

```sh
[bundle exec] fastlane ios bump_version
```

Bump version. Usage: fastlane bump_version type:patch (patch/minor/major)

### ios sync_ios_target

```sh
[bundle exec] fastlane ios sync_ios_target
```

Sync iOS deployment target across all files. Usage: fastlane sync_ios_target target:15.0

### ios get_ios_target

```sh
[bundle exec] fastlane ios get_ios_target
```

Get current iOS deployment target

### ios lint

```sh
[bundle exec] fastlane ios lint
```

Run SwiftLint

### ios build_framework

```sh
[bundle exec] fastlane ios build_framework
```

Build framework for device and simulator

### ios build_examples

```sh
[bundle exec] fastlane ios build_examples
```

Build example apps

### ios build_bonni_release

```sh
[bundle exec] fastlane ios build_bonni_release
```

Build Bonni for release

### ios build_xcframework

```sh
[bundle exec] fastlane ios build_xcframework
```

Build XCFramework

### ios unit_test

```sh
[bundle exec] fastlane ios unit_test
```

Run unit tests

### ios validate_podspec

```sh
[bundle exec] fastlane ios validate_podspec
```

Validate CocoaPods podspec

### ios validate_spm

```sh
[bundle exec] fastlane ios validate_spm
```

Validate Swift Package Manager

### ios deploy_testflight

```sh
[bundle exec] fastlane ios deploy_testflight
```

Upload a new build to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
