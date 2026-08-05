//
//  XCTestCase+Concurrency.swift
//  attentive-ios-sdk Tests
//

import XCTest

extension XCTestCase {
    /// Runs `iterations` blocks per role in parallel and asserts they all
    /// complete within `timeout`. Each block receives its iteration index and a
    /// role index (0..<queueLabels.count) so callers can interleave different
    /// operations — e.g. one role merging while another clears.
    ///
    /// Parallelism is bounded via `DispatchQueue.concurrentPerform` (worker
    /// threads capped near core count). Don't replace this with per-block
    /// `queue.async`: when every block parks on the same contended lock, GCD
    /// keeps spawning workers (~64/queue) and the resulting context-switch
    /// thrash made these tests take seconds-to-timeout on small shared CI VMs
    /// while passing in milliseconds locally. The timeout guard stays so a real
    /// deadlock fails the test cleanly instead of hanging the CI job.
    func runConcurrently(
        iterations: Int,
        timeout: TimeInterval = 5,
        queueLabels: [String] = ["concurrent"],
        file: StaticString = #file,
        line: UInt = #line,
        _ block: @escaping (Int, _ queueIndex: Int) -> Void
    ) {
        let roleCount = queueLabels.count
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterations * roleCount) { k in
                block(k / roleCount, k % roleCount)
            }
            group.leave()
        }
        XCTAssertEqual(group.wait(timeout: .now() + timeout), .success, file: file, line: line)
    }
}
