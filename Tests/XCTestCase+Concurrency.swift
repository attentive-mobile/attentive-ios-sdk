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
    /// Two things here are load-bearing for CI stability; both exist because a
    /// test that hammers one lock is a lock *convoy* — its wall-clock time is
    /// `handoffs × thread-wakeup-latency`, and on a busy CI VM wakeup latency
    /// for low-priority threads is tens of milliseconds, not microseconds:
    ///
    /// 1. The work runs at `.userInteractive` QoS — the same priority the
    ///    XCTest main thread gets when a test calls `concurrentPerform`
    ///    directly. Dispatching via plain `DispatchQueue.global()` ran the
    ///    workers at `.default` QoS, and on loaded CI VMs each lock handoff
    ///    then paid a full scheduling delay: the identical workload measured
    ///    0.002s driven from the test thread vs 13.5s driven at default QoS
    ///    in the same CI run.
    /// 2. The timeout is a *deadlock detector*, not a performance assertion —
    ///    a real deadlock never completes, so a generous bound detects it just
    ///    as well while leaving headroom for scheduler noise the test doesn't
    ///    control. Don't tighten it to "what the test usually takes".
    ///
    /// Parallelism stays bounded via `DispatchQueue.concurrentPerform` (worker
    /// threads capped near core count). Don't replace this with per-block
    /// `queue.async`: when every block parks on the same contended lock, GCD
    /// keeps spawning workers (~64/queue) and the resulting context-switch
    /// thrash is even worse.
    func runConcurrently(
        iterations: Int,
        timeout: TimeInterval = 60,
        queueLabels: [String] = ["concurrent"],
        file: StaticString = #file,
        line: UInt = #line,
        _ block: @escaping (Int, _ queueIndex: Int) -> Void
    ) {
        let roleCount = queueLabels.count
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.concurrentPerform(iterations: iterations * roleCount) { k in
                block(k / roleCount, k % roleCount)
            }
            group.leave()
        }
        XCTAssertEqual(group.wait(timeout: .now() + timeout), .success, file: file, line: line)
    }
}
