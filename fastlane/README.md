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

### ios lint

```sh
[bundle exec] fastlane ios lint
```

Run SwiftLint

### ios unit_test

```sh
[bundle exec] fastlane ios unit_test
```

Run unit tests

### ios build_xcframework

```sh
[bundle exec] fastlane ios build_xcframework
```



----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
