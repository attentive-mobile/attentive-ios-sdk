//
//  ATTNSnapshotTestCase.swift
//  attentive-ios-sdk Tests
//

import XCTest
import SnapshotTesting
@testable import ATTNSDKFramework

/// Base class for snapshot tests. Provides shared configuration for device sizes
/// and a consistent `__Snapshots__` reference image directory.
class ATTNSnapshotTestCase: XCTestCase {

    /// Common device viewport sizes for snapshot testing.
    enum DeviceSize: String, CaseIterable {
        case iPhoneSE = "iPhone SE"
        case iPhone16 = "iPhone 16"
        case iPhone16ProMax = "iPhone 16 Pro Max"
        case iPadMini = "iPad mini"

        var config: ViewImageConfig {
            switch self {
            case .iPhoneSE: .iPhoneSe(.portrait)
            case .iPhone16: Self.iPhone16Portrait
            case .iPhone16ProMax: Self.iPhone16ProMaxPortrait
            case .iPadMini: .iPadMini(.portrait)
            }
        }

        // iPhone 16: 393x852 pt, 59pt top safe area, 34pt bottom safe area
        private static let iPhone16Portrait = ViewImageConfig(
            safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
            size: CGSize(width: 393, height: 852),
            traits: UITraitCollection(
                traitsFrom: [
                    .init(forceTouchCapability: .unavailable),
                    .init(layoutDirection: .leftToRight),
                    .init(preferredContentSizeCategory: .medium),
                    .init(userInterfaceIdiom: .phone),
                    .init(horizontalSizeClass: .compact),
                    .init(verticalSizeClass: .regular),
                ]
            )
        )

        // iPhone 16 Pro Max: 440x956 pt, 62pt top safe area, 34pt bottom safe area
        private static let iPhone16ProMaxPortrait = ViewImageConfig(
            safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
            size: CGSize(width: 440, height: 956),
            traits: UITraitCollection(
                traitsFrom: [
                    .init(forceTouchCapability: .unavailable),
                    .init(layoutDirection: .leftToRight),
                    .init(preferredContentSizeCategory: .medium),
                    .init(userInterfaceIdiom: .phone),
                    .init(horizontalSizeClass: .compact),
                    .init(verticalSizeClass: .regular),
                ]
            )
        )
    }

    private static let isCI = ProcessInfo.processInfo.environment["CI"] != nil

    /// Set `true` in a subclass or test to record new reference snapshots.
    /// Ignored on CI — recording is never allowed in CI to prevent silent passes.
    var isRecordingSnapshots: Bool {
        false
    }

    private var recordMode: SnapshotTestingConfiguration.Record {
        guard !Self.isCI else { return .never }
        return isRecordingSnapshots ? .all : .missing
    }

    /// Asserts a snapshot of the given view controller for each provided device size.
    /// Reference images are stored alongside the test file in a `__Snapshots__` directory.
    func assertSnapshot(
        of viewController: UIViewController,
        deviceSizes: [DeviceSize] = [.iPhone16],
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        for device in deviceSizes {
            SnapshotTesting.assertSnapshot(
                of: viewController,
                as: .image(on: device.config),
                named: device.rawValue,
                record: recordMode,
                file: file,
                testName: testName,
                line: line
            )
        }
    }
}
