//
//  XCTestCase+Concurrency.swift
//  attentive-ios-sdk Tests
//

import XCTest

extension XCTestCase {
    /// Dispatches `iterations` parallel blocks across one or more concurrent queues
    /// and asserts they all complete within `timeout`. The block index is passed in
    /// so callers can vary their work per iteration.
    func runConcurrently(
        iterations: Int,
        timeout: TimeInterval = 5,
        queueLabels: [String] = ["concurrent"],
        file: StaticString = #file,
        line: UInt = #line,
        _ block: @escaping (Int, _ queueIndex: Int) -> Void
    ) {
        let queues = queueLabels.map { DispatchQueue(label: $0, attributes: .concurrent) }
        let group = DispatchGroup()
        for i in 0..<iterations {
            for (queueIndex, queue) in queues.enumerated() {
                group.enter()
                queue.async {
                    block(i, queueIndex)
                    group.leave()
                }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + timeout), .success, file: file, line: line)
    }
}
