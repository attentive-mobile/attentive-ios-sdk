//
//  ATTNLogBufferTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Umair Sharif on 5/14/26.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNLogBufferTests: XCTestCase {

    private var buffer: ATTNLogBuffer!

    override func setUp() {
        super.setUp()
        buffer = ATTNLogBuffer(capacity: 8)
        buffer.isCapturing = true
        // isCapturing setter is async; flush the queue so capture is live before each test
        flushBufferQueue()
    }

    override func tearDown() {
        buffer = nil
        super.tearDown()
    }

    // MARK: - Capture gating

    func testAppend_whenNotCapturing_dropsEntries() {
        let buffer = ATTNLogBuffer(capacity: 4)
        // isCapturing defaults to false
        buffer.append(level: .debug, category: "test", message: "ignored")
        buffer.append(level: .info, category: "test", message: "ignored too")

        XCTAssertEqual(buffer.snapshot().count, 0)
    }

    func testAppend_whenCapturing_retainsEntries() {
        buffer.append(level: .debug, category: "net", message: "one")
        buffer.append(level: .info, category: "evt", message: "two")

        let snapshot = buffer.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot[0].message, "one")
        XCTAssertEqual(snapshot[0].logLevel, .debug)
        XCTAssertEqual(snapshot[1].category, "evt")
    }

    func testSnapshot_withSinceDate_filtersEarlierEntries() {
        buffer.append(level: .debug, category: "c", message: "old")
        flushBufferQueue()
        let cutoff = Date()
        // ensure subsequent entries have date strictly >= cutoff
        Thread.sleep(forTimeInterval: 0.01)
        buffer.append(level: .debug, category: "c", message: "new")

        let filtered = buffer.snapshot(since: cutoff)
        XCTAssertEqual(filtered.map(\.message), ["new"])
    }

    // MARK: - Eviction boundary

    func testEviction_triggersAtCapacityPlusSlack_andRetainsCapacity() {
        // capacity = 8, evictionSlack = max(1, 8/4) = 2
        // Filling up to 9 entries should leave us at 9 (under threshold of 10).
        for i in 0..<9 {
            buffer.append(level: .debug, category: "c", message: "msg-\(i)")
        }
        XCTAssertEqual(buffer.snapshot().count, 9, "should not evict before capacity + slack")

        // The 10th append crosses the threshold (count == capacity + slack) and removes
        // evictionSlack (2) entries from the front.
        buffer.append(level: .debug, category: "c", message: "msg-9")

        let snapshot = buffer.snapshot()
        XCTAssertEqual(snapshot.count, 8, "should evict slack entries down to capacity")
        XCTAssertEqual(snapshot.first?.message, "msg-2", "should drop oldest entries first")
        XCTAssertEqual(snapshot.last?.message, "msg-9")
    }

    func testEviction_smallCapacity_usesMinimumSlackOfOne() {
        // capacity = 1 -> evictionSlack = max(1, 1/4) = max(1, 0) = 1
        let small = ATTNLogBuffer(capacity: 1)
        small.isCapturing = true
        flushBufferQueue(on: small)

        small.append(level: .debug, category: "c", message: "a")
        small.append(level: .debug, category: "c", message: "b") // count == 2 == capacity + slack -> evict 1

        let snapshot = small.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot.first?.message, "b")
    }

    // MARK: - Subscriber lifecycle

    func testStream_subscriberReceivesAppendedEntries() async {
        let stream = buffer.stream()
        // Allow the queue.async that registers the continuation to run before we append.
        flushBufferQueue()

        buffer.append(level: .info, category: "evt", message: "first")
        buffer.append(level: .info, category: "evt", message: "second")

        var iterator = stream.makeAsyncIterator()
        let a = await iterator.next()
        let b = await iterator.next()

        XCTAssertEqual(a?.message, "first")
        XCTAssertEqual(b?.message, "second")
    }

    func testStream_multipleSubscribers_eachReceiveEveryEntry() async {
        let s1 = buffer.stream()
        let s2 = buffer.stream()
        flushBufferQueue()

        buffer.append(level: .info, category: "c", message: "x")

        var i1 = s1.makeAsyncIterator()
        var i2 = s2.makeAsyncIterator()
        let v1 = await i1.next()
        let v2 = await i2.next()

        XCTAssertEqual(v1?.message, "x")
        XCTAssertEqual(v2?.message, "x")
    }

    func testStream_cancellingTask_removesSubscriber() async {
        let received = expectation(description: "received entry before cancel")
        let task = Task { [buffer] in
            // capture buffer locally so we don't reach across actor boundaries
            for await entry in buffer!.stream() {
                if entry.message == "ping" { received.fulfill() }
            }
        }

        // Give the Task a moment to subscribe.
        try? await Task.sleep(nanoseconds: 50_000_000)
        flushBufferQueue()

        XCTAssertEqual(subscriberCount(), 1, "subscriber should be registered after stream() runs")

        buffer.append(level: .info, category: "c", message: "ping")
        await fulfillment(of: [received], timeout: 1.0)

        task.cancel()

        // onTermination is queued onto the buffer's serial queue; wait for it to drain.
        try? await Task.sleep(nanoseconds: 50_000_000)
        flushBufferQueue()

        XCTAssertEqual(subscriberCount(), 0, "subscriber should be removed after task cancellation")
    }

    func testStream_appendsRacingWithCancellation_doNotCrash() async {
        // Repeatedly subscribe/cancel while a producer hammers append(). This exercises
        // the onTermination cleanup running concurrently with appends. The serial queue
        // serializes both, so this should never crash or deadlock.
        let producer = Task.detached { [buffer] in
            for i in 0..<500 {
                buffer!.append(level: .debug, category: "race", message: "m-\(i)")
            }
        }

        for _ in 0..<20 {
            let t = Task { [buffer] in
                for await _ in buffer!.stream() { /* consume */ }
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
            t.cancel()
        }

        await producer.value
        // Allow any queued onTermination handlers to drain.
        try? await Task.sleep(nanoseconds: 100_000_000)
        flushBufferQueue()

        XCTAssertEqual(subscriberCount(), 0, "all subscribers should be cleaned up after cancellation")
    }

    // MARK: - Helpers

    private func subscriberCount(on target: ATTNLogBuffer? = nil) -> Int {
        // Read through the same serial queue used by append/onTermination so we observe
        // a fully-drained state. We use Mirror to avoid widening internal API.
        let target = target ?? buffer!
        flushBufferQueue(on: target)
        let mirror = Mirror(reflecting: target)
        let subscribers = mirror.children.first { $0.label == "subscribers" }?.value
        return (subscribers as? [UUID: Any])?.count ?? -1
    }

    /// Submits and awaits a sync block on the buffer's serial queue, ensuring all
    /// previously-enqueued async work (appends, isCapturing toggles, subscriber
    /// add/remove) has completed.
    private func flushBufferQueue(on target: ATTNLogBuffer? = nil) {
        let target = target ?? buffer!
        let mirror = Mirror(reflecting: target)
        guard let queue = mirror.children.first(where: { $0.label == "queue" })?.value as? DispatchQueue else {
            XCTFail("expected ATTNLogBuffer to expose a `queue` property via Mirror")
            return
        }
        queue.sync { }
    }
}
