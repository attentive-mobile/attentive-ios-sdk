# CircleCI Configuration for Attentive iOS SDK

This directory contains the CircleCI configuration for automated building, testing, and deployment of the Attentive iOS SDK.

## Quick Start

### Viewing Build Status

- Visit the [CircleCI Dashboard](https://app.circleci.com/pipelines/github/attentive-mobile/attentive-ios-sdk) to see build status
- Add the CircleCI badge to your PR for quick status checks

### Running Builds Locally

You can test the CircleCI configuration locally using the CircleCI CLI:

```bash
# Install CircleCI CLI
brew install circleci

# Validate configuration
circleci config validate

# Run a specific job locally
circleci local execute --job lint
circleci local execute --job unit-tests
```

**Note**: Some jobs (like those requiring macOS executors) cannot run locally on non-macOS machines.

## Configuration Structure

```
.circleci/
├── config.yml          # Main CircleCI configuration
└── README.md          # This file
```

### config.yml Structure

- **Executors**: Defines the macOS execution environment with Xcode 15.3
- **Commands**: Reusable command definitions (install tools, boot simulators)
- **Jobs**: Individual CI tasks (lint, test, build)
- **Workflows**: Orchestrates job execution and dependencies

## Jobs Overview

### 1. checkout-and-setup
**Purpose**: Checks out code and resolves dependencies
**Runtime**: ~2-3 minutes
**Caches**: Swift Package Manager dependencies

### 2. lint
**Purpose**: Runs SwiftLint for code quality checks
**Runtime**: ~1 minute
**Artifacts**: HTML lint report

### 3. unit-tests
**Purpose**: Runs unit tests with code coverage
**Runtime**: ~5-8 minutes
**Artifacts**: Test results, coverage reports

### 4. ui-tests
**Purpose**: Runs UI tests for the Creative UI
**Runtime**: ~10-15 minutes
**When**: Only on `main` and `release/*` branches
**Artifacts**: UI test results, crash reports (on failure)

### 5. build-framework
**Purpose**: Builds the framework for iOS device and simulator
**Runtime**: ~5-7 minutes

### 6. build-examples
**Purpose**: Builds all example apps (Example, ExampleSwift, Bonni)
**Runtime**: ~8-10 minutes

### 7. validate-podspec
**Purpose**: Validates the CocoaPods podspec
**Runtime**: ~3-5 minutes

### 8. validate-spm
**Purpose**: Validates Swift Package Manager configuration
**Runtime**: ~2-3 minutes

## Workflows

### build-test (Main Workflow)
Runs on every push and PR:
1. Checkout and setup
2. Parallel execution of: lint, unit-tests, build-framework, validate-podspec, validate-spm
3. UI tests (main/release branches only)
4. Build examples (after framework builds)

### nightly
Scheduled to run daily at midnight UTC:
- Full test suite including UI tests
- All validations
- Comprehensive build checks

## Caching Strategy

The configuration uses multiple cache layers:

1. **Swift Package Manager** - Cached by `Package.resolved` checksum
2. **CocoaPods** - Cached by podspec checksum
3. **DerivedData** - Incremental build artifacts

Caches are automatically invalidated when dependencies change.

## Environment Variables

Set these in CircleCI project settings (if needed):

| Variable | Description | Required |
|----------|-------------|----------|
| `CODECOV_TOKEN` | For code coverage uploads | No |
| `SLACK_WEBHOOK` | For Slack notifications | No |
| `COCOAPODS_TRUNK_TOKEN` | For pod releases | Production only |

## Triggering Builds

### Automatic Triggers
- Push to any branch
- Pull request opened/updated
- Nightly schedule (midnight UTC)

### Manual Triggers
- Use "Rerun workflow" in CircleCI dashboard
- Push an empty commit: `git commit --allow-empty -m "Trigger CI" && git push`

## Working with the Configuration

### Adding a New Job

```yaml
jobs:
  my-new-job:
    executor: macos-xcode
    steps:
      - attach_workspace:
          at: .
      - run:
          name: My Task
          command: echo "Hello World"
```

Then add it to a workflow:

```yaml
workflows:
  build-test:
    jobs:
      - checkout-and-setup
      - my-new-job:
          requires:
            - checkout-and-setup
```

### Modifying Resource Classes

If builds are slow, you can use larger resource classes:

```yaml
executors:
  macos-xcode:
    macos:
      xcode: "15.3.0"
    resource_class: macos.m1.large.gen1  # Upgraded from medium
```

**Available Options**:
- `macos.m1.medium.gen1` - 6 vCPU, 14GB RAM (default)
- `macos.m1.large.gen1` - 8 vCPU, 14GB RAM (faster)

### Debugging Failed Builds

1. **Check the build logs** in CircleCI dashboard
2. **Download artifacts** for detailed reports
3. **SSH into the build** (if enabled):
   ```bash
   # CircleCI provides SSH access for debugging
   # Click "Rerun job with SSH" in the dashboard
   ```
4. **Run locally** with CircleCI CLI (for supported jobs)

## Test Results and Artifacts

### Test Results
- Viewable in the "Tests" tab of each build
- JUnit XML format for easy parsing
- Automatic failure detection

### Artifacts
- **Lint Results**: HTML report of SwiftLint findings
- **Test Results**: XCResult bundles with full test data
- **Coverage Reports**: JSON and text coverage data
- **Crash Reports**: Simulator diagnostics (on test failures)

Access artifacts via:
1. CircleCI dashboard → Build → Artifacts tab
2. Direct URL (retained for 30 days)

## Performance Optimization Tips

### 1. Use Workspaces
Already implemented - code is checked out once and shared across jobs.

### 2. Leverage Caching
Ensure `Package.resolved` is committed to maximize cache hits.

### 3. Parallelize Where Possible
Consider splitting unit tests if they grow:
```yaml
unit-tests:
  parallelism: 2  # Splits tests across 2 containers
```

### 4. Skip Unnecessary Jobs on PRs
UI tests already skip on non-main branches. Consider similar filters for expensive jobs.

### 5. Use Conditional Execution
```yaml
- run:
    name: Optional Step
    command: echo "Running..."
    when: on_success  # or on_fail, always
```

## Troubleshooting

### Common Issues

#### "No such file or directory" errors
- Ensure `attach_workspace` is used in jobs after `checkout-and-setup`
- Check file paths are relative to workspace root

#### Simulator boot failures
- The `boot-simulator` command handles this with `|| true`
- Simulator boot errors are usually transient

#### Test timeouts
- Increase `no_output_timeout` for slow tests
- Consider breaking up large test suites

#### Cache not working
- Verify cache keys match between `restore_cache` and `save_cache`
- Check that dependency lock files are committed

### Getting Help

1. Check the [CircleCI Documentation](https://circleci.com/docs/)
2. Review build logs in detail
3. Ask in #eng-mobile-ci Slack channel
4. Contact DevOps team for infrastructure issues

## Migration from GitHub Actions

If you're migrating from GitHub Actions:

| GitHub Actions | CircleCI Equivalent |
|----------------|---------------------|
| `runs-on: macos-14` | `executor: macos-xcode` |
| `actions/checkout@v4` | `checkout` step |
| `actions/cache@v3` | `restore_cache`/`save_cache` |
| `actions/upload-artifact@v4` | `store_artifacts` |
| Job dependencies | `requires:` in workflow |

## Best Practices

1. **Keep jobs focused** - Each job should do one thing well
2. **Use descriptive names** - Make it clear what each job does
3. **Cache aggressively** - But invalidate when dependencies change
4. **Fail fast** - Use `when: on_fail` for cleanup tasks
5. **Store artifacts** - Especially for failed builds
6. **Monitor costs** - Use appropriate resource classes

## Additional Resources

- [Full Implementation Plan](../CIRCLECI_PLAN.md)
- [CircleCI iOS Documentation](https://circleci.com/docs/testing-ios/)
- [Xcode on CircleCI](https://circleci.com/docs/using-macos/)
- [CircleCI CLI](https://circleci.com/docs/local-cli/)

---

**Last Updated**: 2025-11-06
**Maintained By**: Mobile Platform Team
