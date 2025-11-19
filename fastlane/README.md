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

### ios lint

```sh
[bundle exec] fastlane ios lint
```

Run SwiftLint

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit tests

### ios ui_test

```sh
[bundle exec] fastlane ios ui_test
```

Run UI tests

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

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload a new build to TestFlight

### ios quality

```sh
[bundle exec] fastlane ios quality
```

Run all quality checks (lint + test + build)

### ios ci

```sh
[bundle exec] fastlane ios ci
```

Run complete CI validation

### ios test_all

```sh
[bundle exec] fastlane ios test_all
```

Run tests only (unit + UI)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
